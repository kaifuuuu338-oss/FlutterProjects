from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any, Mapping

REQUIRED_DISCLAIMER = "This is a screening tool and not a medical diagnosis."
DOMAINS: tuple[str, ...] = ("GM", "FM", "SE", "COG", "LC")


class OpenAiLlmService:
    def __init__(self) -> None:
        # Support both env names to avoid setup mismatch:
        # OPENAI_API_KEY (preferred) and OPEN_API_KEY (legacy/custom).
        self.api_key = (
            os.getenv("OPENAI_API_KEY", "").strip()
            or os.getenv("OPEN_API_KEY", "").strip()
        )
        self.model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"
        try:
            self.timeout_seconds = max(5, int(os.getenv("OPENAI_TIMEOUT_SECONDS", "20")))
        except ValueError:
            self.timeout_seconds = 20

    @property
    def enabled(self) -> bool:
        return bool(self.api_key)

    def build_guidance(
        self,
        *,
        delayed_count: int,
        delayed_domains: list[str],
        domain_results: dict[str, int],
    ) -> str | None:
        if not self.enabled:
            return None

        system_prompt = (
            "You are an early-childhood developmental screening assistant for ages 0-6 years. "
            "Use only the structured screening input provided by the user payload. "
            "Do not use external data, internet facts, legal advice, or unrelated topics. "
            "Respond only with caregiver-friendly early-childhood health screening guidance. "
            "Never provide a diagnosis. Keep output concise."
        )

        user_payload: dict[str, Any] = {
            "delayedCount": delayed_count,
            "delayedDomains": delayed_domains,
            "domainResults": domain_results,
            "requiredDisclaimer": REQUIRED_DISCLAIMER,
            "format": {
                "line1": "one short guidance paragraph (non-diagnostic)",
                "line2": "2-3 practical follow-up actions",
                "line3": REQUIRED_DISCLAIMER,
            },
        }

        content = self._chat_completion_content(
            system_prompt=system_prompt,
            user_payload=user_payload,
            temperature=0.2,
            max_tokens=220,
        )
        if not content:
            return None

        final_text = content.strip()
        if not final_text:
            return None

        if REQUIRED_DISCLAIMER.lower() not in final_text.lower():
            final_text = f"{final_text}\n{REQUIRED_DISCLAIMER}"

        if len(final_text) > 900:
            final_text = final_text[:900].rstrip()

        return final_text or None

    def personalize_questions(
        self,
        *,
        age_months: int,
        birth_history: list[str],
        health_history: list[str],
        questions_by_domain: Mapping[str, list[dict[str, Any]]],
    ) -> dict[str, list[dict[str, Any]]] | None:
        if not self.enabled:
            return None

        system_prompt = (
            "You are an early-childhood developmental screening assistant for ages 0-6 years. "
            "Rewrite milestone questions to be caregiver-friendly yes/no questions. "
            "Use only the payload. Do not use external data or unrelated topics. "
            "Do not add diagnosis content. "
            "Keep domain keys, question order, question count, question ids, and major flags unchanged. "
            "Return only a JSON object with keys GM, FM, SE, COG, LC. "
            "Each key must map to a list of objects: {\"id\": string, \"text\": string, \"major\": boolean}."
        )

        user_payload: dict[str, Any] = {
            "ageMonths": age_months,
            "birthHistory": birth_history,
            "healthHistory": health_history,
            "questionsByDomain": questions_by_domain,
            "rules": [
                "Do not add or remove questions",
                "Do not change IDs",
                "Do not change major flags",
                "Only rewrite text field",
            ],
        }

        content = self._chat_completion_content(
            system_prompt=system_prompt,
            user_payload=user_payload,
            temperature=0.2,
            max_tokens=1600,
        )
        if not content:
            return None

        parsed = self._extract_json_object(content)
        if not isinstance(parsed, Mapping):
            return None

        normalized: dict[str, list[dict[str, Any]]] = {}
        for domain in DOMAINS:
            base_rows = questions_by_domain.get(domain) or []
            candidate_rows = parsed.get(domain)
            if not isinstance(candidate_rows, list):
                return None
            if len(candidate_rows) != len(base_rows):
                return None

            rows: list[dict[str, Any]] = []
            for idx, base in enumerate(base_rows):
                candidate = candidate_rows[idx]
                if isinstance(candidate, Mapping):
                    text = str(candidate.get("text") or "").strip()
                else:
                    text = str(candidate or "").strip()
                if not text:
                    return None
                rows.append(
                    {
                        "id": str(base.get("id") or f"{domain}_{idx + 1}"),
                        "text": text,
                        "major": bool(base.get("major", False)),
                    }
                )
            normalized[domain] = rows

        return normalized

    def _chat_completion_content(
        self,
        *,
        system_prompt: str,
        user_payload: Mapping[str, Any],
        temperature: float,
        max_tokens: int,
    ) -> str | None:
        if not self.enabled:
            return None

        request_body = {
            "model": self.model,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": json.dumps(dict(user_payload))},
            ],
        }

        request = urllib.request.Request(
            url="https://api.openai.com/v1/chat/completions",
            data=json.dumps(request_body).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            return None

        choices = payload.get("choices")
        if not isinstance(choices, list) or not choices:
            return None
        message = choices[0].get("message", {})
        content = message.get("content")
        if not isinstance(content, str):
            return None
        return content.strip() or None

    @staticmethod
    def _extract_json_object(raw: str) -> dict[str, Any] | None:
        text = str(raw or "").strip()
        if not text:
            return None
        try:
            data = json.loads(text)
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            pass

        left = text.find("{")
        right = text.rfind("}")
        if left < 0 or right <= left:
            return None
        try:
            data = json.loads(text[left : right + 1])
        except json.JSONDecodeError:
            return None
        return data if isinstance(data, dict) else None
