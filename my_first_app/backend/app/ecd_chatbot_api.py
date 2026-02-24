from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

if __package__:
    from .ecd_chatbot_service import EcdChatbotService, WELCOME_MESSAGE
    from .openai_llm_service import OpenAiLlmService
else:
    from ecd_chatbot_service import EcdChatbotService, WELCOME_MESSAGE
    from openai_llm_service import OpenAiLlmService


class ChildRegisterPayload(BaseModel):
    child_id: str | None = None
    date_of_birth: str
    birth_history: list[str] = Field(default_factory=list)
    health_history: list[str] = Field(default_factory=list)


class DomainSubmitPayload(BaseModel):
    child_id: str
    responses: dict[str, Any]
    use_llm: bool = True


class DomainProgressPayload(BaseModel):
    child_id: str
    responses: dict[str, Any] = Field(default_factory=dict)
    current_domain: str | None = None
    current_question_index: int | None = None
    completed: bool = False


class AdaptiveSessionStartPayload(BaseModel):
    child_id: str
    date_of_birth: str | None = None
    age_months: int | None = None
    weight_kg: float | None = None
    height_cm: float | None = None
    basic_details: dict[str, Any] = Field(default_factory=dict)
    birth_history: list[str] = Field(default_factory=list)
    health_history: list[str] = Field(default_factory=list)


class AdaptiveSessionAnswerPayload(BaseModel):
    question_id: str
    answer: Any
    use_llm: bool = True


class LlmOnlyPayload(BaseModel):
    delayed_count: int
    delayed_domains: list[str] = Field(default_factory=list)
    domain_results: dict[str, int] = Field(default_factory=dict)


def build_ecd_chatbot_router(db_url: str) -> APIRouter:
    router = APIRouter(prefix="/api", tags=["ecd-chatbot"])
    service = EcdChatbotService(db_url)
    service.init_db()
    llm_service = OpenAiLlmService()

    @router.post("/child/register")
    def register_child(payload: ChildRegisterPayload) -> dict[str, Any]:
        child_id = (payload.child_id or "").strip() or service.new_child_id()
        dob = service.parse_dob(payload.date_of_birth)
        birth_history = [item.strip() for item in payload.birth_history if item and item.strip()]
        health_history = [item.strip() for item in payload.health_history if item and item.strip()]

        child = service.register_child(
            child_id=child_id,
            dob=dob,
            birth_history=birth_history,
            health_history=health_history,
        )
        if not llm_service.enabled:
            raise HTTPException(
                status_code=503,
                detail="Dynamic milestone questions require OPENAI_API_KEY (or OPEN_API_KEY).",
            )

        base_questions = service.questions_for_age(int(child["age_months"]))
        personalized_questions = llm_service.personalize_questions(
            age_months=int(child["age_months"]),
            birth_history=birth_history,
            health_history=health_history,
            questions_by_domain=base_questions,
        )
        if personalized_questions is None:
            raise HTTPException(
                status_code=502,
                detail="Failed to generate dynamic milestone questions from OpenAI.",
            )
        final_questions = service.coerce_question_set(
            personalized_questions,
            base_questions,
        )
        service.save_child_question_set(
            child_id=child["child_id"],
            question_set=final_questions,
        )

        return {
            "welcomeMessage": WELCOME_MESSAGE,
            "childId": child["child_id"],
            "dateOfBirth": child["dob"],
            "ageMonths": child["age_months"],
            "birthHistory": child["birth_history"],
            "healthHistory": child["health_history"],
            "questionsByDomain": final_questions,
            "llmEnabled": llm_service.enabled,
        }

    @router.get("/milestones/{child_id}")
    def milestones_for_child(child_id: str) -> dict[str, Any]:
        safe_id = child_id.strip()
        if not safe_id:
            raise HTTPException(status_code=400, detail="child_id is required")
        result = service.fetch_questions_for_child(safe_id)
        result["llmEnabled"] = llm_service.enabled
        return result

    @router.post("/domain/submit")
    def submit_domain_responses(payload: DomainSubmitPayload) -> dict[str, Any]:
        safe_id = payload.child_id.strip()
        if not safe_id:
            raise HTTPException(status_code=400, detail="child_id is required")

        result = service.evaluate_and_store(child_id=safe_id, responses=payload.responses)
        result["llmEnabled"] = llm_service.enabled

        if payload.use_llm:
            result["llmGuidance"] = llm_service.build_guidance(
                delayed_count=int(result.get("delayedCount", 0)),
                delayed_domains=list(result.get("delayedDomains", [])),
                domain_results=dict(result.get("domainResults", {})),
            )
        else:
            result["llmGuidance"] = None

        return result

    @router.post("/domain/progress")
    def save_domain_progress(payload: DomainProgressPayload) -> dict[str, Any]:
        safe_id = payload.child_id.strip()
        if not safe_id:
            raise HTTPException(status_code=400, detail="child_id is required")

        return service.save_progress(
            child_id=safe_id,
            responses=payload.responses,
            current_domain=payload.current_domain,
            current_question_index=payload.current_question_index,
            completed=payload.completed,
        )

    @router.get("/domain/progress/{child_id}")
    def read_domain_progress(child_id: str) -> dict[str, Any]:
        safe_id = child_id.strip()
        if not safe_id:
            raise HTTPException(status_code=400, detail="child_id is required")
        return service.get_progress(safe_id)

    @router.post("/chat/session/start")
    def start_adaptive_chat_session(payload: AdaptiveSessionStartPayload) -> dict[str, Any]:
        result = service.start_adaptive_session(
            child_id=payload.child_id,
            date_of_birth=payload.date_of_birth,
            age_months=payload.age_months,
            weight_kg=payload.weight_kg,
            height_cm=payload.height_cm,
            basic_details=payload.basic_details,
            birth_history=payload.birth_history,
            health_history=payload.health_history,
        )
        result["llmEnabled"] = llm_service.enabled
        return result

    @router.get("/chat/session/{session_id}")
    def get_adaptive_chat_session(session_id: str) -> dict[str, Any]:
        result = service.get_adaptive_session(session_id)
        result["llmEnabled"] = llm_service.enabled
        return result

    @router.post("/chat/session/{session_id}/answer")
    def answer_adaptive_chat_session(
        session_id: str,
        payload: AdaptiveSessionAnswerPayload,
    ) -> dict[str, Any]:
        result = service.answer_adaptive_session(
            session_id=session_id,
            question_id=payload.question_id,
            answer=payload.answer,
        )
        result["llmEnabled"] = llm_service.enabled

        if payload.use_llm and bool(result.get("completed")):
            summary = result.get("summary") or {}
            if isinstance(summary, dict):
                summary["llmGuidance"] = llm_service.build_guidance(
                    delayed_count=int(summary.get("delayedCount", 0)),
                    delayed_domains=list(summary.get("delayedDomains", [])),
                    domain_results=dict(summary.get("domainResults", {})),
                )
                result["summary"] = summary

        return result

    @router.post("/llm/guidance")
    def llm_guidance(payload: LlmOnlyPayload) -> dict[str, Any]:
        guidance = llm_service.build_guidance(
            delayed_count=payload.delayed_count,
            delayed_domains=payload.delayed_domains,
            domain_results=payload.domain_results,
        )
        return {
            "llmEnabled": llm_service.enabled,
            "guidance": guidance,
        }

    return router
