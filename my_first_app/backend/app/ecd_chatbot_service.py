from __future__ import annotations

import json
import uuid
from datetime import date, datetime
from pathlib import Path
from typing import Any, Mapping

from fastapi import HTTPException

if __package__:
    from .pg_compat import get_conn
else:
    from pg_compat import get_conn

DOMAINS: tuple[str, ...] = ("GM", "FM", "SE", "COG", "LC")
ADAPTIVE_DOMAIN_ORDER: tuple[str, ...] = ("GM", "FM", "LC", "COG", "SE")
DOMAIN_LABELS: dict[str, str] = {
    "GM": "Gross Motor",
    "FM": "Fine Motor",
    "LC": "Language & Communication",
    "COG": "Cognitive",
    "SE": "Social & Emotional",
}
WELCOME_MESSAGE = "Welcome. Please answer the milestone questions carefully."
DISCLAIMER_MESSAGE = "This is a screening tool and not a medical diagnosis."


class EcdChatbotService:
    def __init__(self, db_url: str, milestones_path: str | None = None) -> None:
        self.db_url = db_url
        base_dir = Path(__file__).resolve().parents[1]
        default_path = base_dir / "data" / "ecd_chatbot_milestones.json"
        self.milestones_path = Path(milestones_path) if milestones_path else default_path
        self._milestones_cache: dict[str, Any] | None = None

    def init_db(self) -> None:
        with get_conn(self.db_url) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS chatbot_child_profile (
                  child_id TEXT PRIMARY KEY,
                  dob DATE NOT NULL,
                  age_months INTEGER NOT NULL,
                  birth_history JSONB NOT NULL,
                  question_set JSONB,
                  health_history JSONB NOT NULL,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                ALTER TABLE chatbot_child_profile
                ADD COLUMN IF NOT EXISTS question_set JSONB
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS chatbot_response_event (
                  id BIGSERIAL PRIMARY KEY,
                  child_id TEXT NOT NULL,
                  age_months INTEGER NOT NULL,
                  age_band TEXT NOT NULL,
                  raw_responses JSONB NOT NULL,
                  normalized_responses JSONB NOT NULL,
                  domain_results JSONB NOT NULL,
                  created_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS domain_results (
                  child_id TEXT PRIMARY KEY,
                  gm INTEGER NOT NULL CHECK (gm IN (0, 1)),
                  fm INTEGER NOT NULL CHECK (fm IN (0, 1)),
                  se INTEGER NOT NULL CHECK (se IN (0, 1)),
                  cog INTEGER NOT NULL CHECK (cog IN (0, 1)),
                  lc INTEGER NOT NULL CHECK (lc IN (0, 1)),
                  delayed_count INTEGER NOT NULL,
                  delayed_domains JSONB NOT NULL,
                  message TEXT NOT NULL,
                  disclaimer TEXT NOT NULL,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS chatbot_domain_progress (
                  child_id TEXT PRIMARY KEY,
                  age_months INTEGER NOT NULL,
                  age_band TEXT NOT NULL,
                  raw_responses JSONB NOT NULL,
                  normalized_responses JSONB NOT NULL,
                  answered_count INTEGER NOT NULL,
                  total_questions INTEGER NOT NULL,
                  current_domain TEXT,
                  current_question_index INTEGER,
                  completed BOOLEAN NOT NULL,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS chatbot_adaptive_session (
                  session_id TEXT PRIMARY KEY,
                  child_id TEXT NOT NULL,
                  session_state JSONB NOT NULL,
                  completed BOOLEAN NOT NULL DEFAULT FALSE,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                )
                """
            )

    def register_child(
        self,
        *,
        child_id: str,
        dob: date,
        birth_history: list[str],
        health_history: list[str],
    ) -> dict[str, Any]:
        now = datetime.utcnow().isoformat()
        age_months = self.calculate_age_months(dob)

        with get_conn(self.db_url) as conn:
            conn.execute(
                """
                INSERT INTO chatbot_child_profile(
                  child_id, dob, age_months, birth_history, health_history, created_at, updated_at
                )
                VALUES(%s, %s, %s, %s::jsonb, %s::jsonb, %s, %s)
                ON CONFLICT(child_id) DO UPDATE SET
                  dob = EXCLUDED.dob,
                  age_months = EXCLUDED.age_months,
                  birth_history = EXCLUDED.birth_history,
                  health_history = EXCLUDED.health_history,
                  updated_at = EXCLUDED.updated_at
                """,
                (
                    child_id,
                    dob.isoformat(),
                    age_months,
                    json.dumps(birth_history),
                    json.dumps(health_history),
                    now,
                    now,
                ),
            )

        return {
            "child_id": child_id,
            "dob": dob.isoformat(),
            "age_months": age_months,
            "birth_history": birth_history,
            "health_history": health_history,
        }

    def get_child(self, child_id: str) -> dict[str, Any] | None:
        with get_conn(self.db_url) as conn:
            row = conn.execute(
                """
                SELECT child_id, dob, age_months, birth_history, health_history, question_set
                FROM chatbot_child_profile
                WHERE child_id = %s
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
        if row is None:
            return None
        return {
            "child_id": row["child_id"],
            "dob": str(row["dob"]),
            "age_months": int(row["age_months"]),
            "birth_history": self._json_field_to_list(row["birth_history"]),
            "health_history": self._json_field_to_list(row["health_history"]),
            "question_set": self._json_field_to_dict(row["question_set"]),
        }

    def fetch_questions_for_child(self, child_id: str) -> dict[str, Any]:
        child = self.get_child(child_id)
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")
        base_questions = self.questions_for_age(int(child["age_months"]))
        stored_question_set = self.coerce_question_set(child.get("question_set"), base_questions)
        return {
            "welcomeMessage": WELCOME_MESSAGE,
            "childId": child["child_id"],
            "ageMonths": child["age_months"],
            "questionsByDomain": stored_question_set,
        }

    def questions_for_age(self, age_months: int) -> dict[str, list[dict[str, Any]]]:
        config = self._load_milestones()
        age_band = self._select_age_band(age_months, config)
        domains_cfg = (config.get("age_bands", {}).get(age_band, {}) or {}).get("domains", {}) or {}
        questions: dict[str, list[dict[str, Any]]] = {}
        for domain in DOMAINS:
            questions[domain] = [
                {
                    "id": str(q.get("id") or f"{domain}_{idx + 1}"),
                    "text": str(q.get("text") or ""),
                    "major": bool(q.get("major", False)),
                }
                for idx, q in enumerate(domains_cfg.get(domain) or [])
            ]
        return questions

    def save_child_question_set(
        self,
        *,
        child_id: str,
        question_set: Mapping[str, Any],
    ) -> None:
        with get_conn(self.db_url) as conn:
            conn.execute(
                """
                UPDATE chatbot_child_profile
                SET question_set = %s::jsonb, updated_at = %s
                WHERE child_id = %s
                """,
                (
                    json.dumps(dict(question_set)),
                    datetime.utcnow().isoformat(),
                    child_id,
                ),
            )

    @staticmethod
    def coerce_question_set(
        candidate: Any,
        fallback: Mapping[str, list[dict[str, Any]]],
    ) -> dict[str, list[dict[str, Any]]]:
        out: dict[str, list[dict[str, Any]]] = {}
        source = candidate if isinstance(candidate, Mapping) else {}

        for domain in DOMAINS:
            fallback_rows = fallback.get(domain) or []
            source_rows = source.get(domain) if isinstance(source, Mapping) else None

            rows: list[dict[str, Any]] = []
            for idx, base in enumerate(fallback_rows):
                text = str(base.get("text") or "").strip()
                if isinstance(source_rows, list) and idx < len(source_rows):
                    row = source_rows[idx]
                    if isinstance(row, Mapping):
                        candidate_text = str(row.get("text") or "").strip()
                    else:
                        candidate_text = str(row or "").strip()
                    if candidate_text:
                        text = candidate_text

                rows.append(
                    {
                        "id": str(base.get("id") or f"{domain}_{idx + 1}"),
                        "text": text,
                        "major": bool(base.get("major", False)),
                    }
                )

            out[domain] = rows
        return out

    def save_progress(
        self,
        *,
        child_id: str,
        responses: Mapping[str, Any],
        current_domain: str | None = None,
        current_question_index: int | None = None,
        completed: bool = False,
    ) -> dict[str, Any]:
        child = self.get_child(child_id)
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")

        age_months = int(child["age_months"])
        config = self._load_milestones()
        age_band = self._select_age_band(age_months, config)
        band_cfg = (config.get("age_bands", {}).get(age_band, {}) or {})
        domain_cfg = band_cfg.get("domains", {}) or {}

        raw_responses = dict(responses)
        normalized_responses: dict[str, list[dict[str, Any]]] = {}
        answered_count = 0

        for domain in DOMAINS:
            questions = domain_cfg.get(domain) or []
            if not questions:
                raise HTTPException(status_code=500, detail=f"Missing milestone config for domain {domain}")

            domain_input = raw_responses.get(domain)
            answers = self._extract_partial_domain_answers(domain, domain_input, questions)
            rows: list[dict[str, Any]] = []
            for idx, q in enumerate(questions):
                qid = str(q.get("id") or f"{domain}_{idx + 1}")
                if qid not in answers:
                    continue
                answer = bool(answers[qid])
                expected_yes = bool(q.get("expected_yes", True))
                concern = (not answer) if expected_yes else answer
                answered_count += 1
                rows.append(
                    {
                        "questionId": qid,
                        "question": str(q.get("text") or ""),
                        "answer": answer,
                        "concern": concern,
                        "major": bool(q.get("major", False)),
                    }
                )
            normalized_responses[domain] = rows

        total_questions = self._total_questions_from_domain_cfg(domain_cfg)
        safe_domain = current_domain if current_domain in DOMAINS else None
        safe_index = current_question_index if isinstance(current_question_index, int) and current_question_index >= 0 else None
        is_completed = bool(completed or (total_questions > 0 and answered_count >= total_questions))
        now = datetime.utcnow().isoformat()

        with get_conn(self.db_url) as conn:
            conn.execute(
                """
                INSERT INTO chatbot_domain_progress(
                  child_id, age_months, age_band, raw_responses, normalized_responses,
                  answered_count, total_questions, current_domain, current_question_index,
                  completed, created_at, updated_at
                )
                VALUES(
                  %s, %s, %s, %s::jsonb, %s::jsonb, %s, %s, %s, %s, %s, %s, %s
                )
                ON CONFLICT(child_id) DO UPDATE SET
                  age_months = EXCLUDED.age_months,
                  age_band = EXCLUDED.age_band,
                  raw_responses = EXCLUDED.raw_responses,
                  normalized_responses = EXCLUDED.normalized_responses,
                  answered_count = EXCLUDED.answered_count,
                  total_questions = EXCLUDED.total_questions,
                  current_domain = EXCLUDED.current_domain,
                  current_question_index = EXCLUDED.current_question_index,
                  completed = EXCLUDED.completed,
                  updated_at = EXCLUDED.updated_at
                """,
                (
                    child_id,
                    age_months,
                    age_band,
                    json.dumps(raw_responses),
                    json.dumps(normalized_responses),
                    answered_count,
                    total_questions,
                    safe_domain,
                    safe_index,
                    is_completed,
                    now,
                    now,
                ),
            )

        return {
            "childId": child_id,
            "ageMonths": age_months,
            "ageBand": age_band,
            "responses": raw_responses,
            "answeredCount": answered_count,
            "totalQuestions": total_questions,
            "currentDomain": safe_domain,
            "currentQuestionIndex": safe_index,
            "completed": is_completed,
            "updatedAt": now,
        }

    def get_progress(self, child_id: str) -> dict[str, Any]:
        child = self.get_child(child_id)
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")

        age_months = int(child["age_months"])
        config = self._load_milestones()
        age_band = self._select_age_band(age_months, config)
        band_cfg = (config.get("age_bands", {}).get(age_band, {}) or {})
        domain_cfg = band_cfg.get("domains", {}) or {}
        total_questions = self._total_questions_from_domain_cfg(domain_cfg)

        with get_conn(self.db_url) as conn:
            row = conn.execute(
                """
                SELECT
                  raw_responses, answered_count, total_questions, current_domain,
                  current_question_index, completed, updated_at
                FROM chatbot_domain_progress
                WHERE child_id = %s
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()

        if row is None:
            return {
                "childId": child_id,
                "ageMonths": age_months,
                "ageBand": age_band,
                "responses": {},
                "answeredCount": 0,
                "totalQuestions": total_questions,
                "currentDomain": None,
                "currentQuestionIndex": None,
                "completed": False,
                "updatedAt": None,
            }

        raw_responses = self._json_field_to_dict(row["raw_responses"])
        answered_count = int(row["answered_count"] or 0)
        stored_total_questions = int(row["total_questions"] or 0)
        return {
            "childId": child_id,
            "ageMonths": age_months,
            "ageBand": age_band,
            "responses": raw_responses,
            "answeredCount": answered_count,
            "totalQuestions": stored_total_questions if stored_total_questions > 0 else total_questions,
            "currentDomain": row["current_domain"],
            "currentQuestionIndex": row["current_question_index"],
            "completed": bool(row["completed"]),
            "updatedAt": row["updated_at"],
        }

    def evaluate_and_store(self, *, child_id: str, responses: Mapping[str, Any]) -> dict[str, Any]:
        child = self.get_child(child_id)
        if child is None:
            raise HTTPException(status_code=404, detail="Child not found")

        age_months = int(child["age_months"])
        config = self._load_milestones()
        age_band = self._select_age_band(age_months, config)
        band_cfg = (config.get("age_bands", {}).get(age_band, {}) or {})
        domain_cfg = band_cfg.get("domains", {}) or {}
        thresholds = band_cfg.get("thresholds", {}) or {}

        domain_results: dict[str, int] = {}
        normalized_responses: dict[str, list[dict[str, Any]]] = {}

        for domain in DOMAINS:
            questions = domain_cfg.get(domain) or []
            if not questions:
                raise HTTPException(status_code=500, detail=f"Missing milestone config for domain {domain}")

            domain_input = responses.get(domain)
            if domain_input is None:
                raise HTTPException(status_code=400, detail=f"Missing responses for domain {domain}")

            answers = self._extract_domain_answers(domain, domain_input, questions)
            concern_count = 0
            major_missing = False
            rows: list[dict[str, Any]] = []

            for idx, q in enumerate(questions):
                qid = str(q.get("id") or f"{domain}_{idx + 1}")
                answer = bool(answers[qid])
                expected_yes = bool(q.get("expected_yes", True))
                concern = (not answer) if expected_yes else answer
                if concern:
                    concern_count += 1
                if concern and bool(q.get("major", False)):
                    major_missing = True
                rows.append(
                    {
                        "questionId": qid,
                        "question": str(q.get("text") or ""),
                        "answer": answer,
                        "concern": concern,
                        "major": bool(q.get("major", False)),
                    }
                )

            threshold = self._threshold_for_domain(thresholds, domain)
            domain_results[domain] = 1 if major_missing or concern_count >= threshold else 0
            normalized_responses[domain] = rows

        delayed_count = sum(domain_results.values())
        delayed_domains = [d for d in DOMAINS if domain_results.get(d, 0) == 1]
        message = self.build_final_message(delayed_count)

        now = datetime.utcnow().isoformat()
        with get_conn(self.db_url) as conn:
            conn.execute(
                """
                INSERT INTO chatbot_response_event(
                  child_id, age_months, age_band, raw_responses, normalized_responses, domain_results, created_at
                )
                VALUES(%s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb, %s)
                """,
                (
                    child_id,
                    age_months,
                    age_band,
                    json.dumps(dict(responses)),
                    json.dumps(normalized_responses),
                    json.dumps(domain_results),
                    now,
                ),
            )
            conn.execute(
                """
                INSERT INTO domain_results(
                  child_id, gm, fm, se, cog, lc,
                  delayed_count, delayed_domains, message, disclaimer, created_at, updated_at
                )
                VALUES(%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s, %s)
                ON CONFLICT(child_id) DO UPDATE SET
                  gm = EXCLUDED.gm,
                  fm = EXCLUDED.fm,
                  se = EXCLUDED.se,
                  cog = EXCLUDED.cog,
                  lc = EXCLUDED.lc,
                  delayed_count = EXCLUDED.delayed_count,
                  delayed_domains = EXCLUDED.delayed_domains,
                  message = EXCLUDED.message,
                  disclaimer = EXCLUDED.disclaimer,
                  updated_at = EXCLUDED.updated_at
                """,
                (
                    child_id,
                    domain_results.get("GM", 0),
                    domain_results.get("FM", 0),
                    domain_results.get("SE", 0),
                    domain_results.get("COG", 0),
                    domain_results.get("LC", 0),
                    delayed_count,
                    json.dumps(delayed_domains),
                    message,
                    DISCLAIMER_MESSAGE,
                    now,
                    now,
                ),
            )
            conn.execute(
                """
                INSERT INTO chatbot_domain_progress(
                  child_id, age_months, age_band, raw_responses, normalized_responses,
                  answered_count, total_questions, current_domain, current_question_index,
                  completed, created_at, updated_at
                )
                VALUES(
                  %s, %s, %s, %s::jsonb, %s::jsonb, %s, %s, NULL, NULL, TRUE, %s, %s
                )
                ON CONFLICT(child_id) DO UPDATE SET
                  age_months = EXCLUDED.age_months,
                  age_band = EXCLUDED.age_band,
                  raw_responses = EXCLUDED.raw_responses,
                  normalized_responses = EXCLUDED.normalized_responses,
                  answered_count = EXCLUDED.answered_count,
                  total_questions = EXCLUDED.total_questions,
                  current_domain = EXCLUDED.current_domain,
                  current_question_index = EXCLUDED.current_question_index,
                  completed = EXCLUDED.completed,
                  updated_at = EXCLUDED.updated_at
                """,
                (
                    child_id,
                    age_months,
                    age_band,
                    json.dumps(dict(responses)),
                    json.dumps(normalized_responses),
                    self._total_answered_from_normalized(normalized_responses),
                    self._total_questions_from_domain_cfg(domain_cfg),
                    now,
                    now,
                ),
            )

        return {
            "childId": child_id,
            "domainResults": domain_results,
            "delayedCount": delayed_count,
            "delayedDomains": delayed_domains,
            "message": message,
            "disclaimer": DISCLAIMER_MESSAGE,
        }

    @staticmethod
    def build_final_message(delayed_count: int) -> str:
        if delayed_count <= 0:
            return "No developmental delays detected."
        if delayed_count == 1:
            return "The child shows delay in 1 domain."
        return f"The child shows delay in {delayed_count} domains."

    @staticmethod
    def parse_dob(value: str) -> date:
        text = str(value or "").strip()
        if not text:
            raise HTTPException(status_code=400, detail="date_of_birth is required")
        try:
            return datetime.strptime(text[:10], "%Y-%m-%d").date()
        except ValueError as exc:
            raise HTTPException(
                status_code=400,
                detail="date_of_birth must be in YYYY-MM-DD format",
            ) from exc

    @staticmethod
    def calculate_age_months(dob: date) -> int:
        today = datetime.utcnow().date()
        months = (today.year - dob.year) * 12 + (today.month - dob.month)
        if today.day < dob.day:
            months -= 1
        return max(months, 0)

    def _load_milestones(self) -> dict[str, Any]:
        if self._milestones_cache is not None:
            return self._milestones_cache

        if not self.milestones_path.exists():
            self._milestones_cache = self._fallback_milestones()
            return self._milestones_cache

        try:
            # utf-8-sig keeps compatibility with files saved with BOM (common on Windows editors)
            raw_text = self.milestones_path.read_text(encoding="utf-8-sig")
            data = json.loads(raw_text)
        except (OSError, json.JSONDecodeError):
            self._milestones_cache = self._fallback_milestones()
            return self._milestones_cache

        if not isinstance(data, dict) or not isinstance(data.get("age_bands"), dict):
            self._milestones_cache = self._fallback_milestones()
            return self._milestones_cache

        self._milestones_cache = data
        return data

    @staticmethod
    def _fallback_milestones() -> dict[str, Any]:
        bands: tuple[str, ...] = ("0-12", "13-24", "25-36", "37-48", "49-60", "61-72")
        age_domains: dict[str, dict[str, list[dict[str, Any]]]] = {}
        for band in bands:
            age_domains[band] = {
                "thresholds": {domain: 2 for domain in DOMAINS},
                "domains": {
                    "GM": [
                        {
                            "id": f"GM_{band}_1",
                            "text": f"Gross motor milestone appropriate for age {band} is present?",
                            "major": True,
                            "expected_yes": True,
                        },
                        {
                            "id": f"GM_{band}_2",
                            "text": f"Gross motor red flag present for age {band}?",
                            "major": True,
                            "expected_yes": False,
                        },
                    ],
                    "FM": [
                        {
                            "id": f"FM_{band}_1",
                            "text": f"Fine motor milestone appropriate for age {band} is present?",
                            "major": True,
                            "expected_yes": True,
                        },
                        {
                            "id": f"FM_{band}_2",
                            "text": f"Fine motor red flag present for age {band}?",
                            "major": True,
                            "expected_yes": False,
                        },
                    ],
                    "SE": [
                        {
                            "id": f"SE_{band}_1",
                            "text": f"Social-emotional milestone appropriate for age {band} is present?",
                            "major": True,
                            "expected_yes": True,
                        },
                        {
                            "id": f"SE_{band}_2",
                            "text": f"Social-emotional red flag present for age {band}?",
                            "major": True,
                            "expected_yes": False,
                        },
                    ],
                    "COG": [
                        {
                            "id": f"COG_{band}_1",
                            "text": f"Cognitive milestone appropriate for age {band} is present?",
                            "major": True,
                            "expected_yes": True,
                        },
                        {
                            "id": f"COG_{band}_2",
                            "text": f"Cognitive red flag present for age {band}?",
                            "major": True,
                            "expected_yes": False,
                        },
                    ],
                    "LC": [
                        {
                            "id": f"LC_{band}_1",
                            "text": f"Language and communication milestone appropriate for age {band} is present?",
                            "major": True,
                            "expected_yes": True,
                        },
                        {
                            "id": f"LC_{band}_2",
                            "text": f"Language and communication red flag present for age {band}?",
                            "major": True,
                            "expected_yes": False,
                        },
                    ],
                },
            }
        return {"age_bands": age_domains}

    @staticmethod
    def _select_age_band(age_months: int, config: Mapping[str, Any]) -> str:
        age_bands = config.get("age_bands")
        if not isinstance(age_bands, Mapping) or not age_bands:
            raise HTTPException(status_code=500, detail="Milestone age bands are missing")
        for band in age_bands.keys():
            start, end = EcdChatbotService._parse_band(band)
            if start <= age_months <= end:
                return band
        ranges = sorted(
            ((EcdChatbotService._parse_band(b)[1], b) for b in age_bands.keys()),
            key=lambda item: item[0],
        )
        return ranges[-1][1]

    @staticmethod
    def _parse_band(band: str) -> tuple[int, int]:
        try:
            left, right = str(band).split("-")
            return int(left.strip()), int(right.strip())
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Invalid age band format: {band}") from exc

    @staticmethod
    def _threshold_for_domain(thresholds: Mapping[str, Any], domain: str) -> int:
        try:
            value = int(thresholds.get(domain, 2))
        except Exception:
            value = 2
        return 1 if value < 1 else value

    def _extract_domain_answers(
        self,
        domain: str,
        domain_input: Any,
        questions: list[dict[str, Any]],
    ) -> dict[str, bool]:
        answers: dict[str, bool] = {}
        if isinstance(domain_input, Mapping):
            for idx, q in enumerate(questions):
                qid = str(q.get("id") or f"{domain}_{idx + 1}")
                candidate = domain_input.get(qid)
                if candidate is None:
                    candidate = domain_input.get(str(idx))
                if candidate is None:
                    candidate = domain_input.get(idx)
                if candidate is None:
                    raise HTTPException(status_code=400, detail=f"Missing answer for {domain} question {qid}")
                answers[qid] = self.normalize_yes_no(candidate)
            return answers

        if isinstance(domain_input, list):
            if len(domain_input) != len(questions):
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid answer count for {domain}: expected {len(questions)}, got {len(domain_input)}",
                )
            for idx, q in enumerate(questions):
                qid = str(q.get("id") or f"{domain}_{idx + 1}")
                item = domain_input[idx]
                candidate = item
                if isinstance(item, Mapping):
                    candidate = item.get("answer", item.get("value", item.get("response")))
                    if candidate is None:
                        candidate = item.get(qid)
                if candidate is None:
                    raise HTTPException(status_code=400, detail=f"Missing answer for {domain} question {qid}")
                answers[qid] = self.normalize_yes_no(candidate)
            return answers

        raise HTTPException(status_code=400, detail=f"Unsupported response format for domain {domain}")

    def _extract_partial_domain_answers(
        self,
        domain: str,
        domain_input: Any,
        questions: list[dict[str, Any]],
    ) -> dict[str, bool]:
        answers: dict[str, bool] = {}
        if domain_input is None:
            return answers

        if isinstance(domain_input, Mapping):
            for idx, q in enumerate(questions):
                qid = str(q.get("id") or f"{domain}_{idx + 1}")
                candidate = domain_input.get(qid)
                if candidate is None:
                    candidate = domain_input.get(str(idx))
                if candidate is None:
                    candidate = domain_input.get(idx)
                if candidate is None:
                    continue
                answers[qid] = self.normalize_yes_no(candidate)
            return answers

        if isinstance(domain_input, list):
            max_len = min(len(domain_input), len(questions))
            for idx in range(max_len):
                q = questions[idx]
                qid = str(q.get("id") or f"{domain}_{idx + 1}")
                item = domain_input[idx]
                candidate = item
                if isinstance(item, Mapping):
                    candidate = item.get("answer", item.get("value", item.get("response")))
                    if candidate is None:
                        candidate = item.get(qid)
                if candidate is None:
                    continue
                answers[qid] = self.normalize_yes_no(candidate)
            return answers

        raise HTTPException(status_code=400, detail=f"Unsupported response format for domain {domain}")

    def start_adaptive_session(
        self,
        *,
        child_id: str,
        date_of_birth: str | None = None,
        age_months: int | None = None,
        weight_kg: float | None = None,
        height_cm: float | None = None,
        basic_details: Mapping[str, Any] | None = None,
        birth_history: list[str] | None = None,
        health_history: list[str] | None = None,
    ) -> dict[str, Any]:
        safe_id = str(child_id or "").strip()
        if not safe_id:
            raise HTTPException(status_code=400, detail="child_id is required")

        clean_birth = [str(item).strip() for item in (birth_history or []) if str(item).strip()]
        clean_health = [str(item).strip() for item in (health_history or []) if str(item).strip()]
        clean_details = dict(basic_details or {})

        dob: date | None = None
        resolved_age: int | None = int(age_months) if age_months is not None else None
        if date_of_birth:
            dob = self.parse_dob(date_of_birth)
            resolved_age = self.calculate_age_months(dob)

        child = self.get_child(safe_id)
        if child is not None and dob is None:
            dob = self.parse_dob(str(child["dob"]))
        if child is not None and resolved_age is None:
            resolved_age = int(child["age_months"])

        if dob is None and resolved_age is not None:
            dob = self._approximate_dob_from_age_months(resolved_age)
        if dob is None:
            raise HTTPException(
                status_code=400,
                detail="Either date_of_birth or age_months is required to start an adaptive session",
            )
        if resolved_age is None:
            resolved_age = self.calculate_age_months(dob)

        if resolved_age < 0 or resolved_age > 96:
            raise HTTPException(status_code=400, detail="age_months must be between 0 and 96")

        if child is None or clean_birth or clean_health:
            existing_birth = child["birth_history"] if child is not None else []
            existing_health = child["health_history"] if child is not None else []
            self.register_child(
                child_id=safe_id,
                dob=dob,
                birth_history=clean_birth if clean_birth else list(existing_birth),
                health_history=clean_health if clean_health else list(existing_health),
            )

        session_id = f"sess_{uuid.uuid4().hex[:12]}"
        state = {
            "sessionId": session_id,
            "childId": safe_id,
            "ageMonths": int(resolved_age),
            "weightKg": self._safe_float(weight_kg),
            "heightCm": self._safe_float(height_cm),
            "basicDetails": clean_details,
            "birthHistory": clean_birth if clean_birth else list((child or {}).get("birth_history", [])),
            "healthHistory": clean_health if clean_health else list((child or {}).get("health_history", [])),
            "domainOrder": list(ADAPTIVE_DOMAIN_ORDER),
            "domainCursor": 0,
            "domainState": {
                domain: {
                    "asked": 0,
                    "concerns": 0,
                    "majorConcern": False,
                    "closed": False,
                }
                for domain in ADAPTIVE_DOMAIN_ORDER
            },
            "responses": {domain: [] for domain in ADAPTIVE_DOMAIN_ORDER},
            "questionQueue": [],
            "askedTags": [],
            "assistantMessage": None,
            "completed": False,
            "createdAt": datetime.utcnow().isoformat(),
            "updatedAt": datetime.utcnow().isoformat(),
        }

        self._ensure_adaptive_question_queue(state)
        self._save_adaptive_session(state)
        return self._adaptive_session_payload(state)

    def get_adaptive_session(self, session_id: str) -> dict[str, Any]:
        state = self._load_adaptive_session(session_id)
        self._ensure_adaptive_question_queue(state)
        self._save_adaptive_session(state)
        return self._adaptive_session_payload(state)

    def answer_adaptive_session(
        self,
        *,
        session_id: str,
        question_id: str,
        answer: Any,
    ) -> dict[str, Any]:
        state = self._load_adaptive_session(session_id)
        if bool(state.get("completed")):
            return self._adaptive_session_payload(state)

        self._ensure_adaptive_question_queue(state)
        queue = list(state.get("questionQueue") or [])
        if not queue:
            state["completed"] = True
            self._save_adaptive_session(state)
            return self._adaptive_session_payload(state)

        current = queue[0]
        expected_question_id = str(current.get("id") or "")
        safe_question_id = str(question_id or "").strip()
        if safe_question_id != expected_question_id:
            raise HTTPException(
                status_code=409,
                detail="Question mismatch. Refresh session and answer the current question.",
            )

        normalized_answer = self.normalize_yes_no(answer)
        expected_yes = bool(current.get("expectedYes", True))
        concern = (not normalized_answer) if expected_yes else normalized_answer
        domain = str(current.get("domain") or "").strip().upper()
        if domain not in ADAPTIVE_DOMAIN_ORDER:
            raise HTTPException(status_code=500, detail="Adaptive question has invalid domain")

        entry = {
            "questionId": expected_question_id,
            "question": str(current.get("text") or ""),
            "answer": bool(normalized_answer),
            "concern": bool(concern),
            "major": bool(current.get("major", False)),
            "tag": str(current.get("tag") or ""),
            "askedAt": datetime.utcnow().isoformat(),
        }

        responses = state.get("responses") or {}
        domain_rows = list(responses.get(domain) or [])
        domain_rows.append(entry)
        responses[domain] = domain_rows
        state["responses"] = responses

        asked_tags = list(state.get("askedTags") or [])
        tag = str(current.get("tag") or "")
        if tag:
            asked_tags.append(tag)
            state["askedTags"] = asked_tags

        domain_state_map = state.get("domainState") or {}
        domain_state = dict(domain_state_map.get(domain) or {})
        domain_state["asked"] = int(domain_state.get("asked", 0)) + 1
        if concern:
            domain_state["concerns"] = int(domain_state.get("concerns", 0)) + 1
            if bool(current.get("major", False)):
                domain_state["majorConcern"] = True
        domain_state_map[domain] = domain_state
        state["domainState"] = domain_state_map

        queue = queue[1:]
        if concern and int(domain_state.get("asked", 0)) < self._adaptive_max_questions_per_domain(state, domain):
            follow_ups = self._build_adaptive_follow_up_questions(
                domain=domain,
                age_months=int(state.get("ageMonths", 0) or 0),
                state=state,
                last_question=current,
            )
            if follow_ups:
                queue = follow_ups + queue

        domain_should_close = self._adaptive_should_close_domain(domain=domain, state=state, queue=queue)
        if domain_should_close and not queue:
            domain_state["closed"] = True
            domain_state_map[domain] = domain_state
            state["domainState"] = domain_state_map
            state["domainCursor"] = int(state.get("domainCursor", 0)) + 1

        state["questionQueue"] = queue
        self._ensure_adaptive_question_queue(state)
        self._save_adaptive_session(state)
        return self._adaptive_session_payload(state)

    def _save_adaptive_session(self, state: Mapping[str, Any]) -> None:
        session_id = str(state.get("sessionId") or "").strip()
        child_id = str(state.get("childId") or "").strip()
        if not session_id or not child_id:
            raise HTTPException(status_code=500, detail="Adaptive session is missing identity")

        now = datetime.utcnow().isoformat()
        mutable = dict(state)
        mutable["updatedAt"] = now
        mutable.setdefault("createdAt", now)

        with get_conn(self.db_url) as conn:
            conn.execute(
                """
                INSERT INTO chatbot_adaptive_session(
                  session_id, child_id, session_state, completed, created_at, updated_at
                )
                VALUES(%s, %s, %s::jsonb, %s, %s, %s)
                ON CONFLICT(session_id) DO UPDATE SET
                  child_id = EXCLUDED.child_id,
                  session_state = EXCLUDED.session_state,
                  completed = EXCLUDED.completed,
                  updated_at = EXCLUDED.updated_at
                """,
                (
                    session_id,
                    child_id,
                    json.dumps(mutable),
                    bool(mutable.get("completed", False)),
                    str(mutable.get("createdAt") or now),
                    now,
                ),
            )

    def _load_adaptive_session(self, session_id: str) -> dict[str, Any]:
        safe_id = str(session_id or "").strip()
        if not safe_id:
            raise HTTPException(status_code=400, detail="session_id is required")

        with get_conn(self.db_url) as conn:
            row = conn.execute(
                """
                SELECT session_state
                FROM chatbot_adaptive_session
                WHERE session_id = %s
                LIMIT 1
                """,
                (safe_id,),
            ).fetchone()

        if row is None:
            raise HTTPException(status_code=404, detail="Adaptive session not found")

        payload = row["session_state"]
        if isinstance(payload, str):
            try:
                decoded = json.loads(payload)
            except json.JSONDecodeError as exc:
                raise HTTPException(status_code=500, detail="Adaptive session payload is corrupted") from exc
            if not isinstance(decoded, dict):
                raise HTTPException(status_code=500, detail="Adaptive session payload has invalid format")
            return decoded
        if isinstance(payload, dict):
            return payload
        raise HTTPException(status_code=500, detail="Adaptive session payload has invalid type")

    def _adaptive_session_payload(self, state: Mapping[str, Any]) -> dict[str, Any]:
        completed = bool(state.get("completed", False))
        queue = list(state.get("questionQueue") or [])

        payload: dict[str, Any] = {
            "sessionId": str(state.get("sessionId") or ""),
            "childId": str(state.get("childId") or ""),
            "ageMonths": int(state.get("ageMonths", 0) or 0),
            "weightKg": state.get("weightKg"),
            "heightCm": state.get("heightCm"),
            "completed": completed,
            "assistantMessage": state.get("assistantMessage"),
            "progress": self._adaptive_progress_payload(state),
        }
        if completed:
            payload["summary"] = self._adaptive_summary_payload(state)
            payload["currentQuestion"] = None
        else:
            payload["summary"] = None
            payload["currentQuestion"] = self._adaptive_public_question(queue[0]) if queue else None
        return payload

    def _adaptive_progress_payload(self, state: Mapping[str, Any]) -> dict[str, Any]:
        responses = state.get("responses") or {}
        answered = 0
        for domain in ADAPTIVE_DOMAIN_ORDER:
            answered += len(list(responses.get(domain) or []))

        domain_state_map = state.get("domainState") or {}
        completed_domains = 0
        for domain in ADAPTIVE_DOMAIN_ORDER:
            d_state = domain_state_map.get(domain) or {}
            if bool(d_state.get("closed", False)):
                completed_domains += 1

        total_domains = len(ADAPTIVE_DOMAIN_ORDER)
        ratio = 0.0 if total_domains <= 0 else completed_domains / total_domains
        return {
            "answered": answered,
            "domainsCompleted": completed_domains,
            "totalDomains": total_domains,
            "progressPercent": int(ratio * 100),
        }

    def _adaptive_summary_payload(self, state: Mapping[str, Any]) -> dict[str, Any]:
        domain_state_map = state.get("domainState") or {}
        responses = state.get("responses") or {}
        domain_results: dict[str, int] = {}
        delayed_domains: list[str] = []
        response_vectors: dict[str, list[int]] = {}
        concern_vectors: dict[str, list[int]] = {}

        for domain in ADAPTIVE_DOMAIN_ORDER:
            d_state = domain_state_map.get(domain) or {}
            asked = int(d_state.get("asked", 0) or 0)
            concerns = int(d_state.get("concerns", 0) or 0)
            major = bool(d_state.get("majorConcern", False))
            concern_ratio = (float(concerns) / float(asked)) if asked > 0 else 0.0
            is_delayed = major or concerns >= 2 or (asked >= 3 and concern_ratio >= 0.6)
            domain_results[domain] = 1 if is_delayed else 0
            if is_delayed:
                delayed_domains.append(domain)

            rows = list(responses.get(domain) or [])
            response_vectors[domain] = [1 if bool(row.get("answer", False)) else 0 for row in rows]
            concern_vectors[domain] = [1 if bool(row.get("concern", False)) else 0 for row in rows]

        delayed_count = sum(domain_results.values())
        return {
            "domainResults": domain_results,
            "delayedCount": delayed_count,
            "delayedDomains": delayed_domains,
            "message": self.build_final_message(delayed_count),
            "disclaimer": DISCLAIMER_MESSAGE,
            "responseVectors": response_vectors,
            "concernVectors": concern_vectors,
        }

    def _adaptive_public_question(self, question: Mapping[str, Any]) -> dict[str, Any]:
        return {
            "id": str(question.get("id") or ""),
            "domain": str(question.get("domain") or ""),
            "domainLabel": DOMAIN_LABELS.get(str(question.get("domain") or ""), str(question.get("domain") or "")),
            "text": str(question.get("text") or ""),
            "inputType": str(question.get("inputType") or "yes_no"),
        }

    def _ensure_adaptive_question_queue(self, state: dict[str, Any]) -> None:
        if bool(state.get("completed", False)):
            state["assistantMessage"] = None
            return

        queue = list(state.get("questionQueue") or [])
        if queue:
            state["questionQueue"] = queue
            state["assistantMessage"] = None
            return

        domain_order = list(state.get("domainOrder") or list(ADAPTIVE_DOMAIN_ORDER))
        domain_state_map = state.get("domainState") or {}
        cursor = int(state.get("domainCursor", 0) or 0)

        while cursor < len(domain_order):
            domain = str(domain_order[cursor]).upper()
            d_state = dict(domain_state_map.get(domain) or {})
            if bool(d_state.get("closed", False)):
                cursor += 1
                continue
            seeded = self._build_adaptive_seed_questions(domain=domain, state=state)
            if not seeded:
                d_state["closed"] = True
                domain_state_map[domain] = d_state
                cursor += 1
                continue

            state["domainState"] = domain_state_map
            state["domainCursor"] = cursor
            state["questionQueue"] = seeded
            state["assistantMessage"] = f"Now assessing {DOMAIN_LABELS.get(domain, domain)}."
            state["updatedAt"] = datetime.utcnow().isoformat()
            return

        state["completed"] = True
        state["questionQueue"] = []
        state["assistantMessage"] = "Adaptive interview complete. Review and submit the assessment."
        state["updatedAt"] = datetime.utcnow().isoformat()

    def _build_adaptive_seed_questions(self, *, domain: str, state: Mapping[str, Any]) -> list[dict[str, Any]]:
        age_months = int(state.get("ageMonths", 0) or 0)
        stage = self._age_stage(age_months)
        flags = self._adaptive_profile_flags(state)
        asked_tags = set(str(tag) for tag in list(state.get("askedTags") or []))
        out: list[dict[str, Any]] = []

        def push(tag: str, text: str, *, expected_yes: bool = True, major: bool = False) -> None:
            if tag in asked_tags:
                return
            out.append(
                self._adaptive_question(
                    domain=domain,
                    tag=tag,
                    text=text,
                    expected_yes=expected_yes,
                    major=major,
                )
            )

        if domain == "GM":
            if stage == "infant":
                push("gm_core_posture", "Can the child hold head and trunk steady while sitting with support?")
                push("gm_core_roll", "Can the child roll or change position on their own?")
            elif stage == "toddler":
                push("gm_core_walk", "Can the child walk or run without frequent falls?")
                push("gm_core_stairs", "Can the child climb steps with support appropriate for age?")
            else:
                push("gm_core_balance", "Can the child jump, balance, or hop close to what peers can do?")
                push("gm_core_coord", "Can the child coordinate movements during play and daily activities?")
            push("gm_redflag_regression", "Has the child lost any motor skill they previously had?", expected_yes=False, major=True)

        if domain == "FM":
            if stage == "infant":
                push("fm_core_reach", "Does the child reach and grasp objects using both hands?")
                push("fm_core_transfer", "Can the child transfer an object from one hand to the other?")
            elif stage == "toddler":
                push("fm_core_pincer", "Can the child pick small items using thumb and finger (pincer grasp)?")
                push("fm_core_stack", "Can the child stack blocks or place objects with control?")
            else:
                push("fm_core_draw", "Can the child draw or copy simple shapes for their age?")
                push("fm_core_selfhelp", "Can the child handle self-help tasks like spoon use or buttoning at age level?")
            push("fm_redflag_weak_grip", "Do hands seem unusually weak or stiff during daily tasks?", expected_yes=False, major=True)

        if domain == "LC":
            if stage == "infant":
                push("lc_core_sound", "Does the child turn toward sounds or familiar voices?")
                push("lc_core_babble", "Does the child babble or make varied sounds during interaction?")
            elif stage == "toddler":
                push("lc_core_words", "Is the child using age-appropriate meaningful words and simple phrases?")
                push("lc_core_follow", "Can the child follow simple one-step instructions?")
            else:
                push("lc_core_sentence", "Can the child speak in understandable sentences for their age?")
                push("lc_core_conversation", "Can the child answer simple why/what questions in conversation?")
            push("lc_redflag_loss", "Has speech or understanding reduced compared to earlier months?", expected_yes=False, major=True)

        if domain == "COG":
            if stage == "infant":
                push("cog_core_track", "Does the child track objects and show curiosity about surroundings?")
                push("cog_core_cause", "Does the child explore cause-effect (e.g., shaking, dropping, pressing)?")
            elif stage == "toddler":
                push("cog_core_pretend", "Does the child do simple pretend play and problem-solving?")
                push("cog_core_sort", "Can the child match or sort simple objects by shape/color?")
            else:
                push("cog_core_attention", "Can the child stay engaged in age-appropriate tasks and games?")
                push("cog_core_reason", "Can the child understand simple sequences, routines, or concepts?")
            push("cog_redflag_confusion", "Do you notice persistent confusion in familiar routines?", expected_yes=False, major=True)

        if domain == "SE":
            if stage == "infant":
                push("se_core_smile", "Does the child respond socially with eye contact or smile during interaction?")
                push("se_core_soothe", "Can the child be soothed by familiar caregivers most times?")
            elif stage == "toddler":
                push("se_core_play", "Does the child show interest in social play with family or peers?")
                push("se_core_emotion", "Does the child show age-appropriate emotional responses?")
            else:
                push("se_core_peer", "Can the child cooperate with peers and follow simple group rules?")
                push("se_core_regulation", "Can the child regulate emotions with age-appropriate support?")
            push("se_redflag_withdrawal", "Is there persistent extreme withdrawal or aggression?", expected_yes=False, major=True)

        if flags["underweight"] and domain in {"GM", "FM", "COG"}:
            push(
                f"{domain.lower()}_nutrition_energy",
                "Does low energy or poor feeding seem to limit activity or learning?",
                expected_yes=False,
                major=False,
            )
        if flags["stunted"] and domain in {"GM", "LC"}:
            push(
                f"{domain.lower()}_growth_stress",
                "Have growth or recurrent illness concerns affected daily development activities?",
                expected_yes=False,
                major=False,
            )
        if flags["hearing_risk"] and domain == "LC":
            push(
                "lc_hearing_risk",
                "Do you suspect hearing difficulty when the child is called from behind?",
                expected_yes=False,
                major=True,
            )

        max_seed = min(3, len(out))
        return out[:max_seed]

    def _build_adaptive_follow_up_questions(
        self,
        *,
        domain: str,
        age_months: int,
        state: Mapping[str, Any],
        last_question: Mapping[str, Any],
    ) -> list[dict[str, Any]]:
        asked_tags = set(str(tag) for tag in list(state.get("askedTags") or []))
        flags = self._adaptive_profile_flags(state)
        stage = self._age_stage(age_months)
        out: list[dict[str, Any]] = []

        def push(tag: str, text: str, *, expected_yes: bool = True, major: bool = False) -> None:
            if tag in asked_tags:
                return
            out.append(
                self._adaptive_question(
                    domain=domain,
                    tag=tag,
                    text=text,
                    expected_yes=expected_yes,
                    major=major,
                )
            )

        if domain == "GM":
            push("gm_follow_falls", "Do falls, asymmetry, or one-sided weakness happen often?", expected_yes=False, major=True)
            push("gm_follow_mobility_context", "Compared with children of similar age, is mobility clearly behind?", expected_yes=False)
        if domain == "FM":
            push("fm_follow_bimanual", "Does the child avoid using one hand or struggle with coordinated hand use?", expected_yes=False, major=True)
            push("fm_follow_daily_task", "Are fine-motor difficulties affecting feeding, dressing, or play tasks?", expected_yes=False)
        if domain == "LC":
            push("lc_follow_commands", "Does the child miss simple instructions even in calm settings?", expected_yes=False, major=True)
            push("lc_follow_social_language", "Is language difficulty affecting social interaction most days?", expected_yes=False)
            if flags["hearing_risk"] or stage == "infant":
                push("lc_follow_hearing_repeat", "Do you need to repeat name-calls frequently to get response?", expected_yes=False, major=True)
        if domain == "COG":
            push("cog_follow_problem", "Does the child struggle to solve very familiar everyday problems?", expected_yes=False, major=True)
            push("cog_follow_attention", "Is attention span much shorter than expected for age?", expected_yes=False)
        if domain == "SE":
            push("se_follow_regulate", "Are emotional outbursts or withdrawal difficult to recover from?", expected_yes=False, major=True)
            push("se_follow_relationship", "Do social-emotional concerns interfere with bonding or peer play?", expected_yes=False)

        if flags["underweight"]:
            push(f"{domain.lower()}_follow_nutrition_link", "Could poor appetite, illness, or low weight be affecting this area?", expected_yes=False)

        return out[:2]

    def _adaptive_should_close_domain(
        self,
        *,
        domain: str,
        state: Mapping[str, Any],
        queue: list[dict[str, Any]],
    ) -> bool:
        domain_state_map = state.get("domainState") or {}
        d_state = domain_state_map.get(domain) or {}
        asked = int(d_state.get("asked", 0) or 0)
        concerns = int(d_state.get("concerns", 0) or 0)
        major = bool(d_state.get("majorConcern", False))
        min_q = self._adaptive_min_questions_per_domain(domain)
        max_q = self._adaptive_max_questions_per_domain(state, domain)

        if asked >= max_q:
            return True
        if queue:
            return False
        if asked >= min_q and concerns == 0:
            return True
        if asked >= (min_q + 1) and (major or concerns >= 2):
            return True
        return False

    def _adaptive_question(
        self,
        *,
        domain: str,
        tag: str,
        text: str,
        expected_yes: bool = True,
        major: bool = False,
    ) -> dict[str, Any]:
        return {
            "id": f"aq_{uuid.uuid4().hex[:10]}",
            "domain": domain,
            "tag": tag,
            "text": text.strip(),
            "expectedYes": bool(expected_yes),
            "major": bool(major),
            "inputType": "yes_no",
        }

    @staticmethod
    def _age_stage(age_months: int) -> str:
        if age_months <= 12:
            return "infant"
        if age_months <= 36:
            return "toddler"
        return "preschool"

    def _adaptive_profile_flags(self, state: Mapping[str, Any]) -> dict[str, bool]:
        age = int(state.get("ageMonths", 0) or 0)
        weight = self._safe_float(state.get("weightKg"))
        height = self._safe_float(state.get("heightCm"))
        history_blob = " ".join(
            [
                *(str(x).lower() for x in list(state.get("healthHistory") or [])),
                *(str(x).lower() for x in list(state.get("birthHistory") or [])),
                json.dumps(state.get("basicDetails") or {}).lower(),
            ]
        )
        return {
            "underweight": (weight is not None) and (weight < self._min_weight_for_age(age)),
            "stunted": (height is not None) and (height < self._min_height_for_age(age)),
            "hearing_risk": ("hearing" in history_blob) or ("ear" in history_blob),
        }

    @staticmethod
    def _min_weight_for_age(age_months: int) -> float:
        if age_months <= 6:
            return 5.5
        if age_months <= 12:
            return 7.0
        if age_months <= 24:
            return 9.0
        if age_months <= 36:
            return 11.0
        if age_months <= 48:
            return 13.0
        if age_months <= 60:
            return 15.0
        return 17.0

    @staticmethod
    def _min_height_for_age(age_months: int) -> float:
        if age_months <= 12:
            return 70.0
        if age_months <= 24:
            return 80.0
        if age_months <= 36:
            return 88.0
        if age_months <= 48:
            return 95.0
        if age_months <= 60:
            return 101.0
        return 107.0

    @staticmethod
    def _adaptive_min_questions_per_domain(domain: str) -> int:
        return 2 if domain in {"GM", "FM", "LC", "COG", "SE"} else 2

    def _adaptive_max_questions_per_domain(self, state: Mapping[str, Any], domain: str) -> int:
        flags = self._adaptive_profile_flags(state)
        max_q = 4
        if flags["underweight"] or flags["stunted"]:
            max_q += 1
        if domain == "LC" and flags["hearing_risk"]:
            max_q += 1
        return max_q

    @staticmethod
    def _safe_float(value: Any) -> float | None:
        if value is None:
            return None
        try:
            parsed = float(value)
        except (TypeError, ValueError):
            return None
        if parsed <= 0:
            return None
        return parsed

    @staticmethod
    def _approximate_dob_from_age_months(age_months: int) -> date:
        today = datetime.utcnow().date()
        safe_months = max(int(age_months), 0)
        years = safe_months // 12
        months = safe_months % 12
        year = today.year - years
        month = today.month - months
        while month <= 0:
            month += 12
            year -= 1
        day = min(today.day, 28)
        return date(year, month, day)

    @staticmethod
    def normalize_yes_no(value: Any) -> bool:
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            if int(value) in (0, 1):
                return bool(int(value))
            raise HTTPException(status_code=400, detail=f"Invalid numeric response value: {value}")
        text = str(value or "").strip().lower()
        if text in {"yes", "y", "1", "true", "t"}:
            return True
        if text in {"no", "n", "0", "false", "f"}:
            return False
        raise HTTPException(status_code=400, detail=f"Invalid yes/no response value: {value}")

    @staticmethod
    def _json_field_to_list(value: Any) -> list[str]:
        if isinstance(value, list):
            return [str(item) for item in value]
        if value is None:
            return []
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                decoded = []
            if isinstance(decoded, list):
                return [str(item) for item in decoded]
        return [str(value)]

    @staticmethod
    def _json_field_to_dict(value: Any) -> dict[str, Any]:
        if isinstance(value, dict):
            return value
        if value is None:
            return {}
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                decoded = {}
            if isinstance(decoded, dict):
                return decoded
        return {}

    @staticmethod
    def _total_questions_from_domain_cfg(domain_cfg: Mapping[str, Any]) -> int:
        total = 0
        for domain in DOMAINS:
            rows = domain_cfg.get(domain)
            if isinstance(rows, list):
                total += len(rows)
        return total

    @staticmethod
    def _total_answered_from_normalized(
        normalized_responses: Mapping[str, list[dict[str, Any]]],
    ) -> int:
        return sum(len(rows) for rows in normalized_responses.values())

    @staticmethod
    def new_child_id() -> str:
        return f"child_{uuid.uuid4().hex[:12]}"
