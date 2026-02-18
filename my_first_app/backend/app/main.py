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
try:
    from .intervention import generate_intervention, calculate_trend
except Exception:
    from intervention import generate_intervention, calculate_trend
try:
    from .problem_b_service import (
        adjust_intensity,
        generate_intervention_plan,
        next_review_decision,
        rule_logic_table,
        schema_tables,
    )
except Exception:
    from problem_b_service import (
        adjust_intensity,
        generate_intervention_plan,
        next_review_decision,
        rule_logic_table,
        schema_tables,
    )
try:
    from .problem_b_activity_engine import (
        assign_activities_for_child,
        compute_compliance,
        derive_severity,
        determine_next_action,
        escalation_decision,
        plan_regeneration_summary,
        projection_from_compliance,
        reset_frequency_status,
        weekly_progress_rows,
    )
except Exception:
    from problem_b_activity_engine import (
        assign_activities_for_child,
        compute_compliance,
        derive_severity,
        determine_next_action,
        escalation_decision,
        plan_regeneration_summary,
        projection_from_compliance,
        reset_frequency_status,
        weekly_progress_rows,
    )


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
    artifacts = None
    model_load_error: Optional[str] = None
    try:
        artifacts = load_artifacts(model_dir)
    except Exception as exc:
        model_load_error = str(exc)
    # Simple in-memory store for tasks/checklists (child_id -> data)
    tasks_store: Dict[str, Dict] = {}
    # In-memory activity assignment + tracking store for Problem B engine
    activity_tracking_store: Dict[str, List[Dict]] = {}
    activity_plan_summary_store: Dict[str, Dict] = {}

    def _phase_payload(child_id: str) -> Dict:
        rows = activity_tracking_store.get(child_id, [])
        summary = activity_plan_summary_store.get(child_id, {
            "child_id": child_id,
            "domains": [],
            "total_activities": 0,
            "daily_count": 0,
            "weekly_count": 0,
            "phase_duration_weeks": 1,
        })
        compliance = compute_compliance(rows)
        phase_weeks = int(summary.get("phase_duration_weeks", 1) or 1)
        weekly_rows = weekly_progress_rows(rows, phase_weeks)
        weeks_completed = len([r for r in weekly_rows if int(r.get("completion_percentage", 0)) > 0])
        adherence_percent = int(compliance.get("completion_percent", 0))
        improvement = 0
        action = determine_next_action(improvement, adherence_percent, weeks_completed)
        regen = plan_regeneration_summary(len(rows), action, summary.get("domains", []))
        return {
            "summary": summary,
            "activities": rows,
            "compliance": compliance,
            "weekly_progress": weekly_rows,
            "projection": projection_from_compliance(int(compliance.get("completion_percent", 0))),
            "escalation_decision": escalation_decision(weekly_rows),
            "next_action": action,
            "plan_regeneration": regen,
        }

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
        if artifacts is None:
            # Fallback heuristic when model artifacts are unavailable.
            domain_scores = {}
            explanation = []
            total_delay_flags = 0
            for domain, answers in payload.domain_responses.items():
                misses = sum(1 for v in answers if int(v) == 0)
                ratio = misses / max(len(answers), 1)
                if ratio >= 0.75:
                    label = "critical"
                elif ratio >= 0.5:
                    label = "high"
                elif ratio >= 0.25:
                    label = "medium"
                else:
                    label = "low"
                domain_scores[domain] = label
                if label in {"critical", "high", "medium"}:
                    total_delay_flags += 1
                explanation.append(f"{domain}: {label}")
            if total_delay_flags >= 3:
                risk_level = "critical"
            elif total_delay_flags == 2:
                risk_level = "high"
            elif total_delay_flags == 1:
                risk_level = "medium"
            else:
                risk_level = "low"
            delay_summary = {f"{d}_delay": 1 if domain_scores.get(d, "low") in {"critical", "high", "medium"} else 0 for d in ["GM", "FM", "LC", "COG", "SE"]}
            delay_summary["num_delays"] = sum(delay_summary.values())
            if model_load_error:
                explanation.append("Using fallback risk engine due to model load issue.")
            result = {
                "risk_level": risk_level,
                "domain_scores": domain_scores,
                "explanation": explanation,
                "delay_summary": delay_summary,
            }
        else:
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

    @app.post("/intervention/plan")
    def intervention_plan(payload: Dict):
        # Accept raw dict payload to avoid pydantic nesting issues in runtime
        data = payload or {}
        # Normalize numeric domain scores into severity labels expected by generator
        ds = data.get("domain_scores")
        if isinstance(ds, dict):
            normalized = {}
            for k, v in ds.items():
                try:
                    val = float(v)
                except Exception:
                    normalized[k] = v
                    continue
                # map 0-1 score (lower worse) to severity
                if val <= 0.25:
                    normalized[k] = "Critical"
                elif val <= 0.5:
                    normalized[k] = "High"
                elif val <= 0.75:
                    normalized[k] = "Mild"
                else:
                    normalized[k] = "Normal"
            data["domain_scores"] = normalized
        result = generate_intervention(data)
        return result

    class FollowupRequest(BaseModel):
        child_id: str
        baseline_delay: int
        followup_delay: int

    @app.post("/followup/assess")
    def followup_assess(payload: FollowupRequest):
        return calculate_trend(payload.baseline_delay, payload.followup_delay)

    class ProblemBPlanRequest(BaseModel):
        child_id: str
        gm_delay: int = 0
        fm_delay: int = 0
        lc_delay: int = 0
        cog_delay: int = 0
        se_delay: int = 0
        risk_category: str = "Low"

    @app.post("/problem-b/intervention-plan")
    def problem_b_intervention_plan(payload: ProblemBPlanRequest):
        return generate_intervention_plan(payload.model_dump())

    class ProblemBTrendRequest(BaseModel):
        baseline_delay: int
        followup_delay: int

    @app.post("/problem-b/trend")
    def problem_b_trend(payload: ProblemBTrendRequest):
        reduction, trend = calculate_trend(payload.baseline_delay, payload.followup_delay)
        return {
            "delay_reduction": reduction,
            "trend": trend,
        }

    class ProblemBAdjustRequest(BaseModel):
        current_intensity: str
        trend: str
        delay_reduction: int = 0

    @app.post("/problem-b/adjust-intensity")
    def problem_b_adjust(payload: ProblemBAdjustRequest):
        adjusted = adjust_intensity(payload.current_intensity, payload.trend)
        decision = next_review_decision(adjusted, payload.delay_reduction, payload.trend)
        return {
            "adjusted_intensity": adjusted,
            "next_review_decision": decision,
        }

    @app.get("/problem-b/rules")
    def problem_b_rules():
        return rule_logic_table()

    @app.get("/problem-b/schema")
    def problem_b_schema():
        return schema_tables()

    @app.get("/problem-b/system-flow")
    def problem_b_system_flow():
        return {
            "flow": [
                "Assessment Data",
                "Risk Calculation",
                "Intervention Generator",
                "Referral Decision",
                "Caregiver Engagement Engine",
                "Follow-Up Assessment",
                "Trend Analysis",
                "Intensity Adjustment",
                "Dashboard Reporting",
            ]
        }

    class ActivityGenerationRequest(BaseModel):
        child_id: str
        age_months: int
        delayed_domains: List[str]
        autism_risk: Optional[str] = "Low"
        baseline_risk_category: Optional[str] = "Low"
        severity_level: Optional[str] = None

    @app.post("/problem-b/activities/generate")
    def generate_problem_b_activities(payload: ActivityGenerationRequest):
        delayed = [d for d in payload.delayed_domains if d in {"GM", "FM", "LC", "COG", "SE"}]
        severity = payload.severity_level or derive_severity(
            delayed,
            autism_risk=payload.autism_risk or "Low",
            baseline_risk_category=payload.baseline_risk_category or "Low",
        )
        assigned, summary = assign_activities_for_child(
            child_id=payload.child_id,
            age_months=payload.age_months,
            delayed_domains=delayed,
            severity_level=severity,
        )
        activity_tracking_store[payload.child_id] = assigned
        activity_plan_summary_store[payload.child_id] = summary
        return _phase_payload(payload.child_id)

    @app.get("/problem-b/activities/{child_id}")
    def get_problem_b_activities(child_id: str):
        return _phase_payload(child_id)

    class ActivityStatusUpdateRequest(BaseModel):
        child_id: str
        activity_id: str
        status: str = Field(default="completed")

    @app.post("/problem-b/activities/mark-status")
    def update_activity_status(payload: ActivityStatusUpdateRequest):
        rows = activity_tracking_store.get(payload.child_id, [])
        status = payload.status.strip().lower()
        if status not in {"pending", "completed", "skipped"}:
            raise HTTPException(status_code=400, detail="Invalid status")
        updated = False
        for row in rows:
            if row.get("activity_id") == payload.activity_id:
                row["status"] = status
                row["completion_date"] = datetime.utcnow().isoformat() if status == "completed" else None
                required = max(int(row.get("required_count", 1)), 1)
                row["completed_count"] = required if status == "completed" else 0
                row["compliance_score"] = 1 if status == "completed" else 0
                updated = True
                break
        if not updated:
            raise HTTPException(status_code=404, detail="Activity not found")
        return {
            "status": "ok",
            "child_id": payload.child_id,
            "activity_id": payload.activity_id,
            "updated_status": status,
            **_phase_payload(payload.child_id),
        }

    @app.get("/problem-b/compliance/{child_id}")
    def get_problem_b_compliance(child_id: str):
        rows = activity_tracking_store.get(child_id, [])
        compliance = compute_compliance(rows)
        summary = activity_plan_summary_store.get(child_id, {})
        phase_weeks = int(summary.get("phase_duration_weeks", 1) or 1)
        weekly_rows = weekly_progress_rows(rows, phase_weeks)
        return {
            "child_id": child_id,
            **compliance,
            "projection": projection_from_compliance(int(compliance.get("completion_percent", 0))),
            "escalation_decision": escalation_decision(weekly_rows),
        }

    class ResetFrequencyRequest(BaseModel):
        child_id: str
        frequency_type: str

    @app.post("/problem-b/activities/reset-frequency")
    def reset_frequency(payload: ResetFrequencyRequest):
        freq = payload.frequency_type.strip().lower()
        if freq not in {"daily", "weekly"}:
            raise HTTPException(status_code=400, detail="frequency_type must be daily or weekly")
        rows = activity_tracking_store.get(payload.child_id, [])
        updated_count = reset_frequency_status(rows, freq)
        phase = _phase_payload(payload.child_id)
        return {
            "status": "ok",
            "child_id": payload.child_id,
            "frequency_type": freq,
            "updated_count": updated_count,
            **phase,
        }

    class CaregiverEngagementRequest(BaseModel):
        child_id: str
        mode: str
        contact: Optional[Dict[str, str]] = None

    @app.post("/caregiver/engage")
    def caregiver_engage(payload: CaregiverEngagementRequest):
        mode = payload.mode.lower()
        if "phone" in mode and payload.contact:
            return {"status": "queued", "mode": payload.mode, "note": "IVR/WhatsApp message scheduled"}
        return {"status": "ok", "mode": payload.mode, "note": "Printed material to be provided"}

    class TasksSaveRequest(BaseModel):
        child_id: str
        aww_checks: Optional[Dict[str, bool]] = None
        parent_checks: Optional[Dict[str, bool]] = None
        caregiver_checks: Optional[Dict[str, bool]] = None
        aww_remarks: Optional[str] = None
        caregiver_remarks: Optional[str] = None

    @app.post("/tasks/save")
    def save_tasks(payload: TasksSaveRequest):
        data = payload.model_dump()
        child = data.pop("child_id")
        tasks_store[child] = data
        return {"status": "saved", "child_id": child}

    @app.get("/tasks/{child_id}")
    def get_tasks(child_id: str):
        return tasks_store.get(child_id, {
            "aww_checks": {},
            "parent_checks": {},
            "caregiver_checks": {},
            "aww_remarks": "",
            "caregiver_remarks": "",
        })

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.app.main:app", host="127.0.0.1", port=8000, reload=True)
