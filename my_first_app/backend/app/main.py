from __future__ import annotations

import os
import uuid
from datetime import datetime
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

try:
    from .model_service import load_artifacts, predict_risk
except Exception:
    # Allow running this file directly (python main.py) by falling back to
    # importing from the local module name when package context is missing.
    from model_service import load_artifacts, predict_risk


class LoginRequest(BaseModel):
    mobile_number: str
    password: str


class LoginResponse(BaseModel):
    token: str
    user_id: str


class ScreeningRequest(BaseModel):
    child_id: str
    age_months: int
    domain_responses: Dict[str, List[int]]
    # Optional context fields if frontend sends later
    gender: Optional[str] = None
    mandal: Optional[str] = None
    district: Optional[str] = None
    assessment_cycle: Optional[str] = "Baseline"


class ScreeningResponse(BaseModel):
    risk_level: str
    domain_scores: Dict[str, str]
    explanation: List[str]
    delay_summary: Dict[str, int]


class ReferralRequest(BaseModel):
    child_id: str
    aww_id: str
    age_months: int
    overall_risk: str
    domain_scores: Dict[str, float]
    referral_type: str
    urgency: str
    expected_follow_up: Optional[str] = None
    notes: Optional[str] = ""
    referral_timestamp: str


class ReferralResponse(BaseModel):
    referral_id: str
    status: str
    created_at: str


def create_app() -> FastAPI:
    app = FastAPI(title="ECD AI Backend", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    model_dir = os.getenv(
        "ECD_MODEL_DIR",
        os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "..",
                "model_assets",
                "model",
                "trained_models",
            )
        ),
    )
    artifacts = load_artifacts(model_dir)

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok", "time": datetime.utcnow().isoformat()}

    @app.post("/auth/login", response_model=LoginResponse)
    def login(payload: LoginRequest) -> LoginResponse:
        if len(payload.mobile_number.strip()) != 10 or not payload.mobile_number.strip().isdigit():
            raise HTTPException(status_code=400, detail="Invalid mobile number")
        if not payload.password.strip():
            raise HTTPException(status_code=400, detail="Password is required")
        token = f"demo_jwt_{uuid.uuid4().hex}"
        return LoginResponse(token=token, user_id=f"aww_{payload.mobile_number}")

    @app.post("/screening/submit", response_model=ScreeningResponse)
    def submit_screening(payload: ScreeningRequest) -> ScreeningResponse:
        result = predict_risk(payload.model_dump(), artifacts)
        return ScreeningResponse(**result)

    @app.post("/referral/create", response_model=ReferralResponse)
    def create_referral(payload: ReferralRequest) -> ReferralResponse:
        if payload.referral_type not in {"PHC", "RBSK"}:
            raise HTTPException(status_code=400, detail="Referral type must be PHC or RBSK")
        referral_id = f"ref_{uuid.uuid4().hex[:12]}"
        return ReferralResponse(
            referral_id=referral_id,
            status="Pending",
            created_at=datetime.utcnow().isoformat(),
        )

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.app.main:app", host="127.0.0.1", port=8000, reload=True)
