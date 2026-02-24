from __future__ import annotations

import os
import uuid
from collections import Counter
from datetime import datetime, date, timedelta
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

if __package__:
    from .model_service import load_artifacts, predict_risk
    from .intervention import generate_intervention, calculate_trend
    from .problem_b_service import ProblemBService
    from .pg_compat import get_conn
else:
    # Support running file directly: python main.py
    from model_service import load_artifacts, predict_risk
    from intervention import generate_intervention, calculate_trend
    from problem_b_service import ProblemBService
    from pg_compat import get_conn

try:
    if __package__:
        from .ecd_chatbot_api import build_ecd_chatbot_router
    else:
        from ecd_chatbot_api import build_ecd_chatbot_router
except ImportError:
    build_ecd_chatbot_router = None

try:
    if __package__:
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
    else:
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
except ImportError:
    # Legacy module not required for problem_b_service - can be skipped
    assign_activities_for_child = None
    compute_compliance = None
    derive_severity = None
    determine_next_action = None
    escalation_decision = None
    plan_regeneration_summary = None
    projection_from_compliance = None
    reset_frequency_status = None
    weekly_progress_rows = None

DEFAULT_ECD_DATABASE_URL = "postgresql://postgres:postgres@127.0.0.1:5432/ecd_data"


class LoginRequest(BaseModel):
    mobile_number: str
    password: str


class LoginResponse(BaseModel):
    token: str
    user_id: str


class RegistrationRequest(BaseModel):
    name: str
    mobile_number: str
    password: str
    awc_code: str
    mandal: Optional[str] = None
    district: Optional[str] = None


class ScreeningRequest(BaseModel):
    child_id: str
    age_months: int
    domain_responses: Dict[str, List[int]]
    aww_id: Optional[str] = None
    child_name: Optional[str] = None
    village: Optional[str] = None
    # Optional context fields if frontend sends later
    gender: Optional[str] = None
    awc_id: Optional[str] = None
    sector_id: Optional[str] = None
    mandal: Optional[str] = None
    district: Optional[str] = None
    assessment_cycle: Optional[str] = "Baseline"


class ScreeningResponse(BaseModel):
    risk_level: str
    domain_scores: Dict[str, str]
    explanation: List[str]
    delay_summary: Dict[str, int]
    referral_created: bool = False
    referral_data: Optional[Dict[str, str]] = None


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


class ReferralStatusUpdateRequest(BaseModel):
    status: str
    appointment_date: Optional[str] = None
    completion_date: Optional[str] = None
    worker_id: Optional[str] = None


class ReferralStatusUpdateByIdRequest(BaseModel):
    referral_id: str
    status: str
    appointment_date: Optional[str] = None
    completion_date: Optional[str] = None
    worker_id: Optional[str] = None


class ReferralEscalateRequest(BaseModel):
    worker_id: Optional[str] = None


class ChildRegisterRequest(BaseModel):
    child_id: str
    child_name: Optional[str] = None
    gender: Optional[str] = None
    age_months: Optional[int] = None
    date_of_birth: Optional[str] = None
    dob: Optional[str] = None
    awc_id: Optional[str] = None
    awc_code: Optional[str] = None
    sector_id: Optional[str] = None
    mandal_id: Optional[str] = None
    mandal: Optional[str] = None
    district_id: Optional[str] = None
    district: Optional[str] = None
    village: Optional[str] = None
    assessment_cycle: Optional[str] = None
    parent_name: Optional[str] = None
    parent_mobile: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


def _get_conn(db_url: str):
    return get_conn(db_url)


def _init_db(db_url: str) -> None:
    with _get_conn(db_url) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS aww_profile (
              aww_id TEXT PRIMARY KEY,
              name TEXT,
              mobile_number TEXT UNIQUE,
              password TEXT,
              awc_code TEXT,
              mandal TEXT,
              district TEXT,
              created_at TEXT,
              updated_at TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS child_profile (
              child_id TEXT PRIMARY KEY,
              dob TEXT,
              awc_code TEXT,
              district TEXT,
              mandal TEXT,
              assessment_cycle TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS screening_event (
              id BIGSERIAL PRIMARY KEY,
              child_id TEXT,
              age_months INTEGER,
              overall_risk TEXT,
              explainability TEXT,
              assessment_cycle TEXT,
              created_at TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS screening_domain_score (
              id BIGSERIAL PRIMARY KEY,
              screening_id BIGINT,
              domain TEXT,
              risk_label TEXT,
              score DOUBLE PRECISION
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS referral_action (
              referral_id TEXT PRIMARY KEY,
              child_id TEXT,
              aww_id TEXT,
              referral_required INTEGER,
              referral_type TEXT,
              urgency TEXT,
              referral_status TEXT,
              referral_date TEXT,
              completion_date TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS referral_status_history (
              id BIGSERIAL PRIMARY KEY,
              referral_id TEXT,
              old_status TEXT,
              new_status TEXT,
              changed_on TEXT,
              worker_id TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS followup_outcome (
              id BIGSERIAL PRIMARY KEY,
              child_id TEXT,
              baseline_delay_months INTEGER,
              followup_delay_months INTEGER,
              improvement_status TEXT,
              followup_completed INTEGER,
              followup_date TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS follow_up_activities (
              id BIGSERIAL PRIMARY KEY,
              referral_id TEXT,
              target_user TEXT,
              domain TEXT,
              activity_title TEXT,
              activity_description TEXT,
              frequency TEXT,
              duration_days INTEGER,
              created_on TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS follow_up_log (
              id BIGSERIAL PRIMARY KEY,
              referral_id TEXT,
              activity_id BIGINT,
              completed INTEGER DEFAULT 0,
              completed_on TEXT,
              remarks TEXT
            )
            """
        )
        conn.execute("ALTER TABLE referral_action ADD COLUMN IF NOT EXISTS appointment_date TEXT")
        conn.execute("ALTER TABLE referral_action ADD COLUMN IF NOT EXISTS followup_deadline TEXT")
        conn.execute("ALTER TABLE referral_action ADD COLUMN IF NOT EXISTS escalation_level INTEGER")
        conn.execute("ALTER TABLE referral_action ADD COLUMN IF NOT EXISTS escalated_to TEXT")
        conn.execute("ALTER TABLE referral_action ADD COLUMN IF NOT EXISTS last_updated TEXT")

        # Keep child_profile compatible with both old schema and current UI fields.
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS child_name TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS gender TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS age_months INTEGER")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS village TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS awc_id TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS awc_code TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS sector_id TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS mandal_id TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS mandal TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS district_id TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS district TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS dob DATE")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS assessment_cycle TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS created_at TEXT")
        conn.execute("ALTER TABLE child_profile ADD COLUMN IF NOT EXISTS updated_at TEXT")


def _risk_rank(label: str) -> int:
    label = (label or "").strip().lower()
    order = {"low": 0, "medium": 1, "high": 2, "critical": 3}
    return order.get(label, 0)


def _normalize_risk(label: str) -> str:
    label = (label or "").strip().lower()
    if label in {"critical", "very high"}:
        return "Critical"
    if label == "high":
        return "High"
    if label in {"medium", "moderate"}:
        return "Medium"
    return "Low"


def _risk_score(label: str) -> float:
    return {"Low": 0.2, "Medium": 0.5, "High": 0.75, "Critical": 0.92}.get(_normalize_risk(label), 0.2)


def _age_band(age_months: int) -> str:
    if age_months <= 12:
        return "0-12"
    if age_months <= 24:
        return "13-24"
    if age_months <= 36:
        return "25-36"
    if age_months <= 48:
        return "37-48"
    if age_months <= 60:
        return "49-60"
    return "61-72"


def _parse_date_safe(value: str | None) -> date | None:
    if not value:
        return None
    v = str(value).strip()
    if not v:
        return None
    try:
        return datetime.fromisoformat(v.replace("Z", "")).date()
    except ValueError:
        try:
            return datetime.strptime(v.split("T")[0], "%Y-%m-%d").date()
        except ValueError:
            return None


def _save_screening(db_path: str, payload: ScreeningRequest, result: ScreeningResponse) -> None:
    created_at = datetime.utcnow().isoformat()
    with _get_conn(db_path) as conn:
        conn.execute(
            """
            INSERT INTO child_profile(
              child_id, child_name, gender, age_months, village,
              awc_id, awc_code, sector_id, mandal_id, mandal, district_id, district,
              assessment_cycle, created_at, updated_at
            )
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT(child_id) DO UPDATE SET
              child_name=COALESCE(NULLIF(excluded.child_name, ''), child_profile.child_name),
              gender=COALESCE(NULLIF(excluded.gender, ''), child_profile.gender),
              age_months=excluded.age_months,
              village=COALESCE(NULLIF(excluded.village, ''), child_profile.village),
              awc_id=COALESCE(NULLIF(excluded.awc_id, ''), child_profile.awc_id),
              awc_code=COALESCE(NULLIF(excluded.awc_code, ''), child_profile.awc_code),
              sector_id=COALESCE(NULLIF(excluded.sector_id, ''), child_profile.sector_id),
              mandal_id=COALESCE(NULLIF(excluded.mandal_id, ''), child_profile.mandal_id),
              mandal=COALESCE(NULLIF(excluded.mandal, ''), child_profile.mandal),
              district_id=COALESCE(NULLIF(excluded.district_id, ''), child_profile.district_id),
              district=COALESCE(NULLIF(excluded.district, ''), child_profile.district),
              assessment_cycle=COALESCE(NULLIF(excluded.assessment_cycle, ''), child_profile.assessment_cycle),
              updated_at=excluded.updated_at
            """,
            (
                payload.child_id,
                payload.child_name or "",
                payload.gender or "",
                payload.age_months,
                payload.village or "",
                payload.awc_id or "",
                payload.awc_id or "",
                payload.sector_id or "",
                payload.mandal or "",
                payload.mandal or "",
                payload.district or "",
                payload.district or "",
                payload.assessment_cycle or "Baseline",
                created_at,
                created_at,
            ),
        )
        cur = conn.execute(
            """
            INSERT INTO screening_event(child_id, age_months, overall_risk, explainability, assessment_cycle, created_at)
            VALUES(%s,%s,%s,%s,%s,%s)
            RETURNING id
            """,
            (
                payload.child_id,
                payload.age_months,
                _normalize_risk(result.risk_level),
                "; ".join(result.explanation),
                payload.assessment_cycle or "Baseline",
                created_at,
            ),
        )
        screening_row = cur.fetchone()
        screening_id = int(screening_row["id"]) if screening_row else 0
        for domain, risk in result.domain_scores.items():
            conn.execute(
                """
                INSERT INTO screening_domain_score(screening_id, domain, risk_label, score)
                VALUES(%s,%s,%s,%s)
                """,
                (screening_id, domain, _normalize_risk(risk), _risk_score(risk)),
            )

        # Create/refresh a follow-up row so Problem D can start tracking outcomes.
        delay_months = int((result.delay_summary or {}).get("num_delays", 0)) * 2
        existing = conn.execute(
            """
            SELECT id FROM followup_outcome
            WHERE child_id=%s
            ORDER BY id DESC
            LIMIT 1
            """,
            (payload.child_id,),
        ).fetchone()
        if existing is None:
            conn.execute(
                """
                INSERT INTO followup_outcome(child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date)
                VALUES(%s,%s,%s,%s,%s,%s)
                """,
                (
                    payload.child_id,
                    delay_months,
                    delay_months,
                    "No Change",
                    0,
                    datetime.utcnow().date().isoformat(),
                ),
            )


def _risk_to_referral_policy(risk_level: str) -> Dict[str, str] | None:
    risk = _normalize_risk(risk_level)
    if risk == "Critical":
        return {
            "referral_type": "PHC",
            "referral_type_label": "Immediate Specialist Referral",
            "urgency": "Immediate",
            "followup_days": "2",
            "facility": "District Specialist",
        }
    if risk == "High":
        return {
            "referral_type": "PHC",
            "referral_type_label": "Specialist Evaluation",
            "urgency": "Priority",
            "followup_days": "10",
            "facility": "Block Specialist",
        }
    # Strict Problem B mapping: no referral for Medium/Low.
    return None


def _build_domain_reason(domain_scores: Dict[str, str]) -> str:
    if not domain_scores:
        return "General developmental risk"
    severity = {"low": 0, "medium": 1, "high": 2, "critical": 3}
    best_domain = None
    best_risk = "low"
    best_score = -1
    for domain, risk in domain_scores.items():
        score = severity.get(str(risk).strip().lower(), 0)
        if score > best_score:
            best_score = score
            best_domain = domain
            best_risk = str(risk)
    if best_domain is None:
        return "General developmental risk"
    return f"{best_domain} ({_normalize_risk(best_risk)})"


def _domain_display(domain: str) -> str:
    mapping = {
        "GM": "Gross Motor",
        "FM": "Fine Motor",
        "LC": "Speech & Language",
        "COG": "Cognitive",
        "SE": "Social-Emotional",
    }
    return mapping.get(str(domain).strip().upper(), str(domain))


def _risk_points(label: str) -> int:
    normalized = _normalize_risk(label)
    return {"Low": 1, "Medium": 2, "High": 3, "Critical": 4}.get(normalized, 1)


def _status_to_frontend(status: str) -> str:
    normalized = str(status or "").strip().lower()
    if normalized in {"pending"}:
        return "PENDING"
    if normalized in {"appointment scheduled", "scheduled"}:
        return "SCHEDULED"
    if normalized in {"under treatment", "visited"}:
        return "VISITED"
    if normalized in {"completed"}:
        return "COMPLETED"
    if normalized in {"missed"}:
        return "MISSED"
    return "PENDING"


def _status_to_db(status: str) -> str:
    normalized = str(status or "").strip().upper()
    if normalized == "PENDING":
        return "Pending"
    if normalized == "SCHEDULED":
        return "Appointment Scheduled"
    if normalized == "VISITED":
        return "Under Treatment"
    if normalized == "COMPLETED":
        return "Completed"
    if normalized == "MISSED":
        return "Missed"
    raise HTTPException(status_code=400, detail="Invalid referral status")


def _today_iso() -> str:
    return datetime.utcnow().date().isoformat()


def _escalation_target(level: int) -> str:
    if level <= 0:
        return "Block Medical Officer"
    if level == 1:
        return "Block Medical Officer"
    if level == 2:
        return "District Health Officer"
    return "State Supervisor"


def _apply_overdue_escalation(
    conn: Any,
    *,
    referral_id: str,
    status: str,
    followup_deadline: str | None,
    escalation_level: int | None,
) -> None:
    if not followup_deadline:
        return
    normalized = _status_to_frontend(status)
    if normalized == "COMPLETED":
        return
    deadline = _parse_date_safe(followup_deadline)
    if deadline is None:
        return
    today = datetime.utcnow().date()
    if today <= deadline:
        return
    level = int(escalation_level or 0) + 1
    new_deadline = today + timedelta(days=2)
    conn.execute(
        """
        UPDATE referral_action
        SET escalation_level = %s,
            followup_deadline = %s,
            last_updated = %s
        WHERE referral_id = %s
        """,
        (level, new_deadline.isoformat(), today.isoformat(), referral_id),
    )


def _create_referral_action(
    db_path: str,
    *,
    child_id: str,
    aww_id: str,
    risk_level: str,
    domain_scores: Dict[str, str],
) -> Dict[str, str] | None:
    policy = _risk_to_referral_policy(risk_level)
    if policy is None:
        return None
    referral_id = f"ref_{uuid.uuid4().hex[:12]}"
    created_on = datetime.utcnow().date()
    followup_by = created_on + timedelta(days=int(policy["followup_days"]))
    with _get_conn(db_path) as conn:
        conn.execute(
            """
            INSERT INTO referral_action(
                referral_id,
                child_id,
                aww_id,
                referral_required,
                referral_type,
                urgency,
                referral_status,
                referral_date,
                completion_date,
                followup_deadline,
                escalation_level,
                escalated_to,
                last_updated
            )
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """,
            (
                referral_id,
                child_id,
                aww_id,
                1,
                policy["referral_type"],
                policy["urgency"],
                "Pending",
                created_on.isoformat(),
                None,
                followup_by.isoformat(),
                0,
                None,
                created_on.isoformat(),
            ),
        )
    return {
        "referral_id": referral_id,
        "risk_level": _normalize_risk(risk_level),
        "referral_type": policy["referral_type"],
        "referral_type_label": policy["referral_type_label"],
        "urgency": policy["urgency"],
        "status": "Pending",
        "created_on": created_on.isoformat(),
        "followup_by": followup_by.isoformat(),
        "domain_reason": _build_domain_reason(domain_scores),
    }


def _compute_monitoring(db_path: str, role: str, location_id: str) -> dict:
    role_to_column = {"aww": "awc_id", "supervisor": "sector_id", "cdpo": "mandal_id", "district": "district_id", "state": ""}
    filter_column = role_to_column.get(role, "")
    with _get_conn(db_path) as conn:
        children = conn.execute("SELECT * FROM child_profile").fetchall()
        if filter_column and location_id:
            children = [c for c in children if (c[filter_column] or "") == location_id]
        child_ids = [c["child_id"] for c in children]
        child_map = {c["child_id"]: dict(c) for c in children}

        screenings = conn.execute("SELECT * FROM screening_event ORDER BY created_at DESC, id DESC").fetchall()
        latest_screen_by_child: Dict[str, Dict[str, Any]] = {}
        for s in screenings:
            cid = s["child_id"]
            if cid in child_map and cid not in latest_screen_by_child:
                latest_screen_by_child[cid] = s

        latest_ids = [row["id"] for row in latest_screen_by_child.values()]
        domain_rows: List[Dict[str, Any]] = []
        if latest_ids:
            placeholders = ",".join("%s" for _ in latest_ids)
            domain_rows = conn.execute(
                f"SELECT * FROM screening_domain_score WHERE screening_id IN ({placeholders})",
                tuple(latest_ids),
            ).fetchall()
        domain_rows_by_screen: Dict[int, List[Dict[str, Any]]] = {}
        for row in domain_rows:
            domain_rows_by_screen.setdefault(int(row["screening_id"]), []).append(row)

        risk_distribution = Counter({"Low": 0, "Medium": 0, "High": 0, "Critical": 0})
        age_band_rows = {k: {"age_band": k, "low": 0, "medium": 0, "high": 0, "critical": 0} for k in ["0-12", "13-24", "25-36", "37-48", "49-60", "61-72"]}
        for cid, s in latest_screen_by_child.items():
            risk = _normalize_risk(s["overall_risk"])
            risk_distribution[risk] += 1
            age_band_rows[_age_band(int(s["age_months"] or 0))][risk.lower()] += 1

        domain_burden = Counter({"GM": 0, "FM": 0, "LC": 0, "COG": 0, "SE": 0})
        for row in domain_rows:
            label = _normalize_risk(row["risk_label"])
            if label in {"High", "Critical"}:
                domain_burden[row["domain"]] += 1

        referrals = conn.execute("SELECT * FROM referral_action").fetchall()
        referrals = [r for r in referrals if r["child_id"] in child_map]
        pending_referrals = sum(1 for r in referrals if int(r["referral_required"] or 0) == 1 and (r["referral_status"] or "") == "Pending")
        completed_referrals = sum(1 for r in referrals if (r["referral_status"] or "") == "Completed")
        under_treatment_referrals = sum(1 for r in referrals if (r["referral_status"] or "") == "Under Treatment")

        followups = conn.execute("SELECT * FROM followup_outcome").fetchall()
        followups = [f for f in followups if f["child_id"] in child_map]
        followup_due = sum(1 for f in followups if int(f["followup_completed"] or 0) == 0)
        followup_done = sum(1 for f in followups if int(f["followup_completed"] or 0) == 1)
        followup_improving = sum(1 for f in followups if (f["improvement_status"] or "") == "Improving")
        followup_worsening = sum(1 for f in followups if (f["improvement_status"] or "") == "Worsening")
        followup_same = sum(1 for f in followups if (f["improvement_status"] or "") == "No Change")

        # Active intervention proxy:
        # child has unfinished follow-up OR referral under treatment/pending.
        intervention_active_ids = set(
            f["child_id"] for f in followups if int(f["followup_completed"] or 0) == 0
        )
        intervention_active_ids.update(
            r["child_id"] for r in referrals if (r["referral_status"] or "") in {"Pending", "Under Treatment"}
        )
        intervention_active_children = len(intervention_active_ids)

        today = datetime.utcnow().date()
        overdue_referrals = []
        for r in referrals:
            if (r["referral_status"] or "") != "Pending":
                continue
            r_date = _parse_date_safe(r["referral_date"])
            if r_date and (today - r_date).days > 14:
                overdue_referrals.append(
                    {
                        "child_id": r["child_id"],
                        "days_pending": (today - r_date).days,
                        "urgency": r["urgency"] or "",
                        "referral_type": r["referral_type"] or "",
                    }
                )

        latest_referral_by_child: Dict[str, Dict[str, Any]] = {}
        for r in sorted(referrals, key=lambda x: (x["referral_date"] or "", x["referral_id"] or ""), reverse=True):
            if r["child_id"] not in latest_referral_by_child:
                latest_referral_by_child[r["child_id"]] = r
        latest_followup_by_child: Dict[str, Dict[str, Any]] = {}
        for f in sorted(followups, key=lambda x: (x["followup_date"] or "", x["id"] or 0), reverse=True):
            if f["child_id"] not in latest_followup_by_child:
                latest_followup_by_child[f["child_id"]] = f

        high_risk_children = []
        priority_children = []
        for cid, s in latest_screen_by_child.items():
            risk = _normalize_risk(s["overall_risk"])
            c = child_map[cid]
            referral = latest_referral_by_child.get(cid)
            followup = latest_followup_by_child.get(cid)
            days_since_flagged = 0
            s_date = _parse_date_safe(s["created_at"])
            if s_date:
                days_since_flagged = max((today - s_date).days, 0)

            if risk in {"High", "Critical"}:
                affected_domains = []
                for d in domain_rows_by_screen.get(int(s["id"]), []):
                    if _normalize_risk(d["risk_label"]) in {"High", "Critical"}:
                        affected_domains.append(d["domain"])
                high_risk_children.append(
                    {
                        "child_id": cid,
                        "child_name": cid,
                        "age_months": s["age_months"],
                        "risk_category": risk,
                        "domain_affected": ", ".join(affected_domains) if affected_domains else "General",
                        "referral_status": (referral["referral_status"] if referral else "Pending"),
                        "days_since_flagged": days_since_flagged,
                    }
                )

            referral_status = (referral["referral_status"] if referral else "Pending")
            followup_completed = int(followup["followup_completed"] or 0) == 1 if followup else False
            improvement_status = (followup["improvement_status"] if followup else "No Change")
            if risk == "Critical":
                rank = 1
            elif risk == "High" and referral_status == "Pending":
                rank = 2
            elif risk == "High" and not followup_completed:
                rank = 3
            elif risk == "Medium" and improvement_status == "Worsening":
                rank = 4
            else:
                rank = 9
            if rank == 9:
                continue
            priority_children.append(
                {
                    "child_id": cid,
                    "risk": risk,
                    "age_months": s["age_months"],
                    "awc_id": c.get("awc_id", ""),
                    "mandal_id": c.get("mandal_id", ""),
                    "district_id": c.get("district_id", ""),
                    "rank": rank,
                }
            )
        priority_children.sort(key=lambda x: (x["rank"], -_risk_rank(x["risk"])))
        high_risk_children.sort(key=lambda x: (_risk_rank(x["risk_category"]), x["days_since_flagged"]), reverse=True)

        mandal_counts = Counter()
        mandal_high = Counter()
        for cid, s in latest_screen_by_child.items():
            c = child_map[cid]
            mandal = c.get("mandal_id") or "UNKNOWN"
            mandal_counts[mandal] += 1
            if _normalize_risk(s["overall_risk"]) in {"High", "Critical"}:
                mandal_high[mandal] += 1
        hotspots = []
        for mandal, total in mandal_counts.items():
            pct = (mandal_high[mandal] * 100 / total) if total else 0
            if pct > 15:
                hotspots.append({"mandal_id": mandal, "high_risk_pct": round(pct, 2)})
        hotspots.sort(key=lambda x: x["high_risk_pct"], reverse=True)

        by_awc_children = Counter((child_map[cid].get("awc_id") or "N/A") for cid in child_map.keys())
        by_awc_screened = Counter((child_map[cid].get("awc_id") or "N/A") for cid in latest_screen_by_child.keys())
        by_awc_risk = Counter()
        for cid, s in latest_screen_by_child.items():
            if _normalize_risk(s["overall_risk"]) in {"High", "Critical"}:
                by_awc_risk[(child_map[cid].get("awc_id") or "N/A")] += 1

        by_awc_ref_pending = Counter((child_map[r["child_id"]].get("awc_id") or "N/A") for r in referrals if (r["referral_status"] or "") == "Pending")
        by_awc_ref_done = Counter((child_map[r["child_id"]].get("awc_id") or "N/A") for r in referrals if (r["referral_status"] or "") == "Completed")
        by_awc_follow_due = Counter((child_map[f["child_id"]].get("awc_id") or "N/A") for f in followups if int(f["followup_completed"] or 0) == 0)
        by_awc_follow_done = Counter((child_map[f["child_id"]].get("awc_id") or "N/A") for f in followups if int(f["followup_completed"] or 0) == 1)

        aww_performance = []
        for awc_id, total in by_awc_children.items():
            screened = by_awc_screened[awc_id]
            coverage = (screened * 100 / total) if total else 0
            ref_done = by_awc_ref_done[awc_id]
            ref_pending = by_awc_ref_pending[awc_id]
            ref_rate = (ref_done * 100 / (ref_done + ref_pending)) if (ref_done + ref_pending) else 0
            fu_done = by_awc_follow_done[awc_id]
            fu_due = by_awc_follow_due[awc_id]
            fu_rate = (fu_done * 100 / (fu_done + fu_due)) if (fu_done + fu_due) else 0
            score = round(ref_rate * 0.4 + fu_rate * 0.3 + coverage * 0.3, 2)
            aww_performance.append(
                {
                    "awc_id": awc_id,
                    "total_children": total,
                    "high_risk_children": by_awc_risk[awc_id],
                    "screening_coverage": round(coverage, 2),
                    "referral_completion_rate": round(ref_rate, 2),
                    "followup_compliance_rate": round(fu_rate, 2),
                    "performance_score": score,
                    "underperforming": score < 60,
                }
            )
        aww_performance.sort(key=lambda x: x["performance_score"])

        district_counts = Counter()
        district_high = Counter()
        for cid, s in latest_screen_by_child.items():
            district = child_map[cid].get("district_id") or "UNKNOWN"
            district_counts[district] += 1
            if _normalize_risk(s["overall_risk"]) in {"High", "Critical"}:
                district_high[district] += 1
        district_ranking = []
        for district, total in district_counts.items():
            pct = (district_high[district] * 100 / total) if total else 0
            district_ranking.append(
                {
                    "district_id": district,
                    "total_children": total,
                    "high_risk_count": district_high[district],
                    "high_risk_pct": round(pct, 2),
                }
            )
        district_ranking.sort(key=lambda x: x["high_risk_pct"], reverse=True)

        trend_counter_total = Counter()
        trend_counter_high = Counter()
        for cid, s in latest_screen_by_child.items():
            month = str(s["created_at"])[:7]
            trend_counter_total[month] += 1
            if _normalize_risk(s["overall_risk"]) in {"High", "Critical"}:
                trend_counter_high[month] += 1
        trend_rows = []
        for month in sorted(trend_counter_total.keys()):
            total = trend_counter_total[month]
            high = trend_counter_high[month]
            trend_rows.append({"month": month, "screenings": total, "high_risk": high, "high_risk_pct": round((high * 100 / total) if total else 0, 2)})

    total_children = len(children)
    total_screened = len(latest_screen_by_child)
    coverage = round((total_screened * 100 / total_children), 2) if total_children else 0.0
    referral_completion = round((completed_referrals * 100 / (completed_referrals + pending_referrals)), 2) if (completed_referrals + pending_referrals) else 0.0
    followup_compliance = round((followup_done * 100 / (followup_done + followup_due)), 2) if (followup_done + followup_due) else 0.0
    avg_referral_days = 0.0
    referral_durations = []
    for r in referrals:
        if (r["referral_status"] or "") != "Completed":
            continue
        d1 = _parse_date_safe(r["referral_date"])
        d2 = _parse_date_safe(r["completion_date"])
        if d1 and d2:
            referral_durations.append((d2 - d1).days)
    if referral_durations:
        avg_referral_days = round(sum(referral_durations) / len(referral_durations), 2)

    alerts: List[dict] = []
    if risk_distribution["High"] + risk_distribution["Critical"] > 0:
        alerts.append({"level": "red", "message": "High/Critical risk children detected. Immediate action required."})
    if overdue_referrals:
        alerts.append({"level": "yellow", "message": f"{len(overdue_referrals)} referral(s) pending for more than 14 days."})
    if hotspots:
        alerts.append({"level": "orange", "message": f"{len(hotspots)} mandal hotspot(s) detected above 15% high-risk threshold."})

    return {
        "role": role,
        "location_id": location_id,
        "total_children": total_children,
        "total_screened": total_screened,
        "high_risk_children": risk_distribution["High"] + risk_distribution["Critical"],
        "intervention_active_children": intervention_active_children,
        "risk_distribution": dict(risk_distribution),
        "pending_referrals": pending_referrals,
        "total_referred_children": sum(1 for r in referrals if int(r["referral_required"] or 0) == 1),
        "completed_referrals": completed_referrals,
        "under_treatment_referrals": under_treatment_referrals,
        "avg_referral_days": avg_referral_days,
        "followup_due": followup_due,
        "followup_done": followup_done,
        "followup_improving": followup_improving,
        "followup_worsening": followup_worsening,
        "followup_same": followup_same,
        "screening_coverage": coverage,
        "coverage_warning": coverage < 80,
        "followup_compliance": followup_compliance,
        "referral_completion": referral_completion,
        "age_band_risk_rows": list(age_band_rows.values()),
        "hotspots": hotspots,
        "aww_performance": sorted(aww_performance, key=lambda x: x["performance_score"]),
        "underperforming_awcs": [x for x in aww_performance if x["underperforming"]],
        "district_ranking": district_ranking,
        "alerts": alerts,
        "domain_burden": dict(domain_burden),
        "high_risk_children_rows": high_risk_children[:50],
        "priority_children": priority_children[:5],
        "overdue_referrals": sorted(overdue_referrals, key=lambda x: x["days_pending"], reverse=True),
        "trend_rows": trend_rows,
        "aww_trained": True if role == "aww" else None,
        "training_mode": "Blended" if role == "aww" else "",
    }


def _compute_impact(db_path: str, role: str, location_id: str) -> dict:
    role_to_column = {
        "aww": "awc_id",
        "supervisor": "sector_id",
        "cdpo": "mandal_id",
        "district": "district_id",
        "state": "",
    }
    column = role_to_column.get(role, "")
    where_clause = ""
    params: tuple = ()
    if column and location_id:
        where_clause = f" WHERE c.{column} = %s "
        params = (location_id,)
    with _get_conn(db_path) as conn:
        children = conn.execute("SELECT * FROM child_profile").fetchall()
        if column and location_id:
            children = [c for c in children if (c[column] or "") == location_id]
        child_ids = [c["child_id"] for c in children]
        child_map = {c["child_id"]: dict(c) for c in children}
        rows = conn.execute("SELECT * FROM followup_outcome").fetchall()
        rows = [r for r in rows if r["child_id"] in child_map]
        screenings = conn.execute("SELECT * FROM screening_event ORDER BY created_at ASC, id ASC").fetchall()
        by_child: Dict[str, List[Dict[str, Any]]] = {}
        for s in screenings:
            if s["child_id"] in child_map:
                by_child.setdefault(s["child_id"], []).append(s)

    improving = sum(1 for r in rows if (r["improvement_status"] or "") == "Improving")
    worsening = sum(1 for r in rows if (r["improvement_status"] or "") == "Worsening")
    no_change = sum(1 for r in rows if (r["improvement_status"] or "") == "No Change")
    diffs = [int(r["baseline_delay_months"] or 0) - int(r["followup_delay_months"] or 0) for r in rows]
    avg_reduction = round(sum(diffs) / len(diffs), 2) if diffs else 0.0
    followup_done = sum(1 for r in rows if int(r["followup_completed"] or 0) == 1)
    followup_compliance = round((followup_done * 100 / len(rows)), 2) if rows else 0.0

    exit_from_high = 0
    for _, screens in by_child.items():
        if len(screens) < 2:
            continue
        start = _normalize_risk(screens[0]["overall_risk"])
        end = _normalize_risk(screens[-1]["overall_risk"])
        if start in {"High", "Critical"} and end in {"Low", "Medium"}:
            exit_from_high += 1

    trend_counter = Counter()
    for r in rows:
        month = str(r["followup_date"] or "")[:7]
        if month:
            trend_counter[(month, r["improvement_status"] or "No Change")] += 1
    months = sorted({k[0] for k in trend_counter.keys()})
    trend_rows = []
    for m in months:
        trend_rows.append(
            {
                "month": m,
                "improving": trend_counter[(m, "Improving")],
                "worsening": trend_counter[(m, "Worsening")],
                "no_change": trend_counter[(m, "No Change")],
            }
        )

    return {
        "role": role,
        "location_id": location_id,
        "improving": improving,
        "worsening": worsening,
        "no_change": no_change,
        "avg_delay_reduction": avg_reduction,
        "followup_compliance": followup_compliance,
        "exit_from_high_risk": exit_from_high,
        "trend_rows": trend_rows,
        "current_screened": len(by_child),
    }


def _generate_follow_up_activities(db_path: str, referral_id: str, child_id: str, risk_level: str, domain_scores: Dict[str, str], autism_risk: str = "Low", nutrition_risk: str = "Low") -> List[Dict]:
    """Generate domain-specific home activities based on referral risk profile."""
    activities = []
    activity_id = 1

    # Extract delay information from domain scores
    delayed_domains = []
    for domain, risk in domain_scores.items():
        domain_upper = str(domain).upper().strip()
        if domain_upper in {"GM", "FM", "LC", "COG", "SE"}:
            risk_normalized = _normalize_risk(str(risk))
            if risk_normalized in {"High", "Critical", "Medium"}:
                delayed_domains.append(domain_upper)

    # Rule 1: Gross Motor Delay → Daily floor play activities
    if "GM" in delayed_domains:
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "CAREGIVER",
            "domain": "GM",
            "activity_title": "Daily Floor Play & Standing Support",
            "activity_description": "Encourage crawling and standing with support. Let child practice weight-shifting. 20-30 mins daily.",
            "frequency": "DAILY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

        # Add AWW monitoring activity
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "AWW",
            "domain": "GM",
            "activity_title": "Weekly Motor Development Check",
            "activity_description": "Observe and assess child's motor milestones. Document progress. Counsel caregiver.",
            "frequency": "WEEKLY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

    # Rule 2: Fine Motor Delay → Hand activities
    if "FM" in delayed_domains:
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "CAREGIVER",
            "domain": "FM",
            "activity_title": "Hand & Finger Exercises",
            "activity_description": "Practice grasping, finger play, and self-feeding. Use household items (spoons, balls). 15 mins daily.",
            "frequency": "DAILY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

    # Rule 3: Language & Communication Delay → Speech activities
    if "LC" in delayed_domains:
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "CAREGIVER",
            "domain": "LC",
            "activity_title": "Language Stimulation Activities",
            "activity_description": "Talk to child, name objects, sing songs. Encourage babbling and word repetition. 20 mins daily.",
            "frequency": "DAILY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

    # Rule 4: Cognitive Delay → Problem-solving activities
    if "COG" in delayed_domains:
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "CAREGIVER",
            "domain": "COG",
            "activity_title": "Cognitive Play & Problem Solving",
            "activity_description": "Hide-and-seek games, shape sorting, stacking toys. Encourage exploration and discovery. 20 mins daily.",
            "frequency": "DAILY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

    # Rule 5: Social-Emotional Delay → Interaction activities
    if "SE" in delayed_domains or autism_risk in {"Moderate", "High"}:
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "CAREGIVER",
            "domain": "SE",
            "activity_title": "Social Interaction & Eye Contact Practice",
            "activity_description": "Call child's name, maintain eye contact during play. Practice greeting gestures. 10-15 mins, 3x daily.",
            "frequency": "DAILY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

    # Rule 6: Nutrition Risk → Feeding guidance
    if nutrition_risk in {"High", "Severe", "Critical"}:
        activities.append({
            "id": activity_id,
            "referral_id": referral_id,
            "target_user": "AWW",
            "domain": "Nutrition",
            "activity_title": "Weekly Weight Monitoring & Nutrition Counseling",
            "activity_description": "Check child's weight weekly. Monitor growth. Counsel caregiver on nutrition, fortified foods, supplementation.",
            "frequency": "WEEKLY",
            "duration_days": 30,
            "created_on": datetime.utcnow().date().isoformat(),
        })
        activity_id += 1

    # Save activities to database
    with _get_conn(db_path) as conn:
        for activity in activities:
            conn.execute(
                """
                INSERT INTO follow_up_activities (
                    referral_id, target_user, domain, activity_title,
                    activity_description, frequency, duration_days, created_on
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    activity["referral_id"],
                    activity["target_user"],
                    activity["domain"],
                    activity["activity_title"],
                    activity["activity_description"],
                    activity["frequency"],
                    activity["duration_days"],
                    activity["created_on"],
                ),
            )
    return activities


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
    db_path = os.getenv(
        "ECD_DATABASE_URL",
        os.getenv("DATABASE_URL", DEFAULT_ECD_DATABASE_URL),
    )
    try:
        _init_db(db_path)
    except Exception as exc:
        raise RuntimeError(
            "Database initialization failed. Set ECD_DATABASE_URL (or DATABASE_URL) "
            "to a reachable PostgreSQL database, for example "
            "'postgresql://<user>:<password>@127.0.0.1:5432/ecd_data'."
        ) from exc

    if build_ecd_chatbot_router is None:
        raise RuntimeError("ECD chatbot API module is missing; ensure app/ecd_chatbot_api.py is present.")
    app.include_router(build_ecd_chatbot_router(db_path))
    # Simple in-memory store for tasks/checklists (child_id -> data)
    tasks_store: Dict[str, Dict] = {}
    # In-memory activity assignment + tracking store for Problem B engine
    activity_tracking_store: Dict[str, List[Dict]] = {}
    activity_plan_summary_store: Dict[str, Dict] = {}
    # In-memory referral appointments (referral_id -> list of appointments)
    appointments_store: Dict[str, List[Dict]] = {}
    # In-memory referral status override (referral_id -> status)
    referral_status_store: Dict[str, str] = {}

    def _suggested_referral_status(referral_id: str) -> str:
        appointments = appointments_store.get(referral_id, [])
        if not appointments:
            return "Pending"
        completed = sum(1 for a in appointments if a.get("status") == "COMPLETED")
        if completed == 0:
            return "Appointment Scheduled"
        if completed >= 1 and len(appointments) == 1:
            return "Completed"
        if len(appointments) > 1:
            return "Under Treatment"
        return "Appointment Scheduled"

    def _current_referral_status(referral_id: str) -> str:
        return referral_status_store.get(referral_id, _suggested_referral_status(referral_id))

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

    @app.post("/auth/register")
    def register_aww(payload: RegistrationRequest) -> dict:
        """Register a new AWW (Anganwadi Worker) to PostgreSQL database."""
        try:
            if not payload.name.strip():
                raise HTTPException(status_code=400, detail="Name is required")
            if len(payload.mobile_number.strip()) != 10 or not payload.mobile_number.strip().isdigit():
                raise HTTPException(status_code=400, detail="Invalid mobile number - must be 10 digits")
            if not payload.password.strip():
                raise HTTPException(status_code=400, detail="Password is required")
            if not payload.awc_code.strip():
                raise HTTPException(status_code=400, detail="AWC code is required")

            aww_id = f"aww_{payload.mobile_number}"
            created_at = datetime.utcnow().isoformat()
            updated_at = datetime.utcnow().isoformat()

            # Insert into PostgreSQL ecd_data.aww_profile
            with get_conn(db_path) as conn:
                conn.execute(
                    """
                    INSERT INTO aww_profile(
                      aww_id, name, mobile_number, password, awc_code, 
                      mandal, district, created_at, updated_at
                    )
                    VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT(mobile_number) DO UPDATE SET
                      name=EXCLUDED.name,
                      password=EXCLUDED.password,
                      awc_code=EXCLUDED.awc_code,
                      mandal=EXCLUDED.mandal,
                      district=EXCLUDED.district,
                      updated_at=EXCLUDED.updated_at
                    """,
                    (
                        aww_id,
                        payload.name.strip(),
                        payload.mobile_number.strip(),
                        payload.password,
                        payload.awc_code.strip(),
                        payload.mandal or "",
                        payload.district or "",
                        created_at,
                        updated_at,
                    ),
                )
            
            return {
                "status": "ok",
                "message": "AWW registered successfully",
                "aww_id": aww_id,
                "created_at": created_at,
            }
        except Exception as exc:
            print(f"❌ Registration error: {exc}")
            raise HTTPException(status_code=500, detail=f"Registration failed: {str(exc)}")

    @app.post("/children/register")
    def register_child(payload: ChildRegisterRequest) -> dict:
        """Register child profile to PostgreSQL ecd_data.child_profile table."""
        child_id = (payload.child_id or "").strip()
        if not child_id:
            raise HTTPException(status_code=400, detail="child_id is required")

        dob = (payload.date_of_birth or payload.dob or "").strip() or None
        awc_code = (payload.awc_id or payload.awc_code or "").strip() or "AWS_DEMO_001"
        district = (payload.district_id or payload.district or "").strip() or ""
        mandal = (payload.mandal_id or payload.mandal or "").strip() or ""
        assessment_cycle = (payload.assessment_cycle or "Baseline").strip()

        try:
            with _get_conn(db_path) as conn:
                conn.execute(
                    """
                    INSERT INTO child_profile(
                      child_id, dob, awc_code, district, mandal, assessment_cycle
                    )
                    VALUES(%s, %s, %s, %s, %s, %s)
                    ON CONFLICT(child_id) DO UPDATE SET
                      dob=EXCLUDED.dob,
                      awc_code=EXCLUDED.awc_code,
                      district=EXCLUDED.district,
                      mandal=EXCLUDED.mandal,
                      assessment_cycle=EXCLUDED.assessment_cycle
                    """,
                    (
                        child_id,
                        dob,
                        awc_code,
                        district,
                        mandal,
                        assessment_cycle,
                    ),
                )

                row = conn.execute(
                    """
                    SELECT child_id, dob, awc_code, district, mandal, assessment_cycle
                    FROM child_profile
                    WHERE child_id = %s
                    LIMIT 1
                    """,
                    (child_id,),
                ).fetchone()

            return {
                "status": "ok",
                "message": "Child profile registered successfully",
                "child": dict(row) if row else {"child_id": child_id}
            }
        except Exception as exc:
            print(f"❌ Child registration error: {exc}")
            raise HTTPException(status_code=500, detail=f"Child registration failed: {str(exc)}")

    @app.get("/children/{child_id}")
    def get_child(child_id: str) -> dict:
        with _get_conn(db_path) as conn:
            row = conn.execute(
                """
                SELECT child_id, child_name, gender, age_months, dob,
                       awc_id, awc_code, mandal_id, mandal, district_id, district,
                       assessment_cycle, created_at, updated_at
                FROM child_profile
                WHERE child_id = %s
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Child not found")
        return dict(row)

    @app.get("/children")
    def list_children(limit: int = 200) -> dict:
        safe_limit = max(1, min(limit, 1000))
        with _get_conn(db_path) as conn:
            rows = conn.execute(
                """
                SELECT child_id, child_name, gender, age_months, dob,
                       awc_id, awc_code, mandal_id, mandal, district_id, district,
                       assessment_cycle, created_at, updated_at
                FROM child_profile
                ORDER BY created_at DESC, child_id DESC
                LIMIT %s
                """,
                (safe_limit,),
            ).fetchall()
        return {"count": len(rows), "items": [dict(r) for r in rows]}

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
        risk_level = str(result.get("risk_level", "low"))
        domain_scores = dict(result.get("domain_scores") or {})
        referral_data = _create_referral_action(
            db_path,
            child_id=payload.child_id,
            aww_id=(payload.aww_id or payload.awc_id or "").strip() or "unknown_aww",
            risk_level=risk_level,
            domain_scores=domain_scores,
        )
        result["referral_created"] = referral_data is not None
        result["referral_data"] = referral_data
        response = ScreeningResponse(**result)
        _save_screening(db_path, payload, response)
        return response

    @app.post("/referral/create", response_model=ReferralResponse)
    def create_referral(payload: ReferralRequest) -> ReferralResponse:
        if payload.referral_type not in {"PHC", "RBSK"}:
            raise HTTPException(status_code=400, detail="Referral type must be PHC or RBSK")
        referral_id = f"ref_{uuid.uuid4().hex[:12]}"
        created_on = datetime.utcnow().date()
        followup_days = 2 if _normalize_risk(payload.overall_risk) == "Critical" else 10
        followup_by = created_on + timedelta(days=followup_days)
        response = ReferralResponse(
            referral_id=referral_id,
            status="Pending",
            created_at=datetime.utcnow().isoformat(),
        )
        with _get_conn(db_path) as conn:
            conn.execute(
                """
                INSERT INTO referral_action(
                    referral_id,
                    child_id,
                    aww_id,
                    referral_required,
                    referral_type,
                    urgency,
                    referral_status,
                    referral_date,
                    completion_date,
                    followup_deadline,
                    escalation_level,
                    escalated_to,
                    last_updated
                )
                VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """,
                (
                    referral_id,
                    payload.child_id,
                    payload.aww_id,
                    1,
                    payload.referral_type,
                    payload.urgency,
                    "Pending",
                    created_on.isoformat(),
                    None,
                    followup_by.isoformat(),
                    0,
                    None,
                    created_on.isoformat(),
                ),
            )
        
        # Generate follow-up activities based on risk profile
        domain_scores_dict = getattr(payload, 'domain_scores', {})
        if not isinstance(domain_scores_dict, dict):
            domain_scores_dict = {}
        
        _generate_follow_up_activities(
            db_path,
            referral_id=referral_id,
            child_id=payload.child_id,
            risk_level=payload.overall_risk,
            domain_scores=domain_scores_dict,
            autism_risk=getattr(payload, 'autism_risk', 'Low'),
            nutrition_risk=getattr(payload, 'nutrition_risk', 'Low'),
        )
        
        return response

    @app.get("/referral/by-child/{child_id}")
    def get_referral_by_child(child_id: str):
        with _get_conn(db_path) as conn:
            row = conn.execute(
                """
                SELECT referral_id, child_id, aww_id, referral_type, urgency, referral_status,
                       referral_date, followup_deadline, escalation_level, escalated_to, last_updated
                FROM referral_action
                WHERE child_id = %s
                ORDER BY referral_date DESC, referral_id DESC
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
            screen = conn.execute(
                """
                SELECT overall_risk
                FROM screening_event
                WHERE child_id = %s
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Referral not found for child")

        referral_type = (row["referral_type"] or "").strip().upper()
        severity = _normalize_risk(screen["overall_risk"] if screen else "")
        if severity == "Critical":
            urgency = "Immediate"
            referral_type_label = "Immediate Specialist Referral"
            followup_days = 2
            facility = "District Specialist"
        else:
            urgency = "Priority"
            referral_type_label = "Specialist Evaluation"
            followup_days = 10
            facility = "Block Specialist"

        referral_date = _parse_date_safe(row["referral_date"]) or datetime.utcnow().date()
        followup_by = _parse_date_safe(row["followup_deadline"]) or (
            referral_date + timedelta(days=followup_days)
        )

        with _get_conn(db_path) as conn:
            _apply_overdue_escalation(
                conn,
                referral_id=row["referral_id"],
                status=row["referral_status"],
                followup_deadline=followup_by.isoformat(),
                escalation_level=row["escalation_level"],
            )

        return {
            "referral_id": row["referral_id"],
            "child_id": row["child_id"],
            "aww_id": row["aww_id"],
            "referral_type": referral_type,
            "referral_type_label": referral_type_label,
            "urgency": urgency,
            "facility": facility,
            "status": _current_referral_status(row["referral_id"]),
            "created_on": referral_date.isoformat(),
            "followup_by": followup_by.isoformat(),
            "escalation_level": int(row["escalation_level"] or 0),
            "escalated_to": row["escalated_to"],
            "last_updated": row["last_updated"] or referral_date.isoformat(),
        }

    @app.get("/referral/child/{child_id}/details")
    def get_referral_details(child_id: str):
        with _get_conn(db_path) as conn:
            referral = conn.execute(
                """
                SELECT referral_id, child_id, aww_id, referral_type, urgency, referral_status,
                       referral_date, completion_date, appointment_date, followup_deadline,
                       escalation_level, escalated_to, last_updated
                FROM referral_action
                WHERE child_id = %s
                ORDER BY referral_date DESC, referral_id DESC
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
            if referral is None:
                raise HTTPException(status_code=404, detail="Referral not found for child")

            child = conn.execute(
                """
                SELECT child_id, child_name, gender, age_months, village, awc_id
                FROM child_profile
                WHERE child_id = %s
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
            screen = conn.execute(
                """
                SELECT id, overall_risk, explainability
                FROM screening_event
                WHERE child_id = %s
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                """,
                (child_id,),
            ).fetchone()
            domain_rows = []
            if screen is not None:
                domain_rows = conn.execute(
                    """
                    SELECT domain, risk_label
                    FROM screening_domain_score
                    WHERE screening_id = %s
                    """,
                    (screen["id"],),
                ).fetchall()

        severity = _normalize_risk(screen["overall_risk"] if screen else "Low").upper()
        risk_score = int(sum(_risk_points(r["risk_label"]) for r in domain_rows) * 2)

        delayed_domains = [
            _domain_display(r["domain"])
            for r in domain_rows
            if str(r["domain"]).upper() in {"GM", "FM", "LC", "COG", "SE"}
            and _risk_rank(str(r["risk_label"])) >= 1
        ]
        # Preserve order and remove duplicates.
        delayed_domains = list(dict.fromkeys(delayed_domains))

        autism_label = "No Significant Risk"
        adhd_label = "No Significant Risk"
        for r in domain_rows:
            domain_key = str(r["domain"]).upper()
            value = _normalize_risk(str(r["risk_label"]))
            if domain_key == "BPS_AUT":
                autism_label = f"{value} Risk" if value in {"Medium", "High", "Critical"} else "No Significant Risk"
            if domain_key == "BPS_ADHD":
                adhd_label = f"{value} Risk" if value in {"Medium", "High", "Critical"} else "No Significant Risk"

        behavior_flags = []
        explainability = str(screen["explainability"] if screen else "").strip()
        if explainability:
            for token in [t.strip() for t in explainability.replace("\n", ";").split(";") if t.strip()]:
                # Skip raw domain labels like "GM: high", keep meaningful notes.
                if ":" in token and token.split(":", 1)[0].strip().upper() in {"GM", "FM", "LC", "COG", "SE"}:
                    continue
                behavior_flags.append(token)
                if len(behavior_flags) >= 3:
                    break
        if not behavior_flags:
            behavior_flags = ["No behavioral red flags observed."]

        if severity == "CRITICAL":
            urgency = "Immediate"
            facility = "District specialist"
            followup_days = 2
        else:
            urgency = "Priority"
            facility = "Block / District specialist"
            followup_days = 10

        created_on = _parse_date_safe(referral["referral_date"]) or datetime.utcnow().date()
        deadline = _parse_date_safe(referral["followup_deadline"])
        if deadline is None:
            deadline = created_on + timedelta(days=followup_days)
        appointment_date = _parse_date_safe(referral["appointment_date"])
        completion_date = _parse_date_safe(referral["completion_date"])

        with _get_conn(db_path) as conn:
            _apply_overdue_escalation(
                conn,
                referral_id=referral["referral_id"],
                status=referral["referral_status"],
                followup_deadline=deadline.isoformat(),
                escalation_level=referral["escalation_level"],
            )

        return {
            "referral_id": referral["referral_id"],
            "child_info": {
                "name": str(child["child_name"] or child_id) if child else child_id,
                "child_id": child_id,
                "age": int(child["age_months"] or 0) if child else 0,
                "gender": str(child["gender"] or "Unknown") if child else "Unknown",
                "village_or_awc_id": str(
                    child["village"] or child["awc_id"] or "N/A"
                ) if child else "N/A",
                "assigned_worker": str(referral["aww_id"] or "N/A"),
            },
            "risk_summary": {
                "severity": severity,
                "risk_score": risk_score,
                "delayed_domains": delayed_domains,
                "autism_risk": autism_label,
                "adhd_risk": adhd_label,
                "behavior_flags": behavior_flags,
            },
            "decision": {
                "urgency": urgency.upper(),
                "facility": facility,
                "created_on": created_on.isoformat(),
                "deadline": deadline.isoformat(),
                "escalation_level": int(referral["escalation_level"] or 0),
                "escalated_to": referral["escalated_to"],
            },
            "status": _status_to_frontend(referral["referral_status"]),
            "appointment_date": appointment_date.isoformat() if appointment_date else None,
            "completion_date": completion_date.isoformat() if completion_date else None,
            "last_updated": referral["last_updated"] or created_on.isoformat(),
        }

    @app.get("/analytics/monitoring")
    def analytics_monitoring(role: str = "state", location_id: str = "") -> dict:
        return _compute_monitoring(db_path, role=role, location_id=location_id)

    @app.get("/analytics/impact")
    def analytics_impact(role: str = "state", location_id: str = "") -> dict:
        return _compute_impact(db_path, role=role, location_id=location_id)

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

    class AppointmentCreateRequest(BaseModel):
        referral_id: str
        child_id: str
        scheduled_date: str
        appointment_type: str
        notes: Optional[str] = ""
        created_by: Optional[str] = "aww"

    class AppointmentUpdateRequest(BaseModel):
        status: str
        notes: Optional[str] = ""

    @app.post("/appointments")
    def create_appointment(payload: AppointmentCreateRequest):
        appointment_id = f"appt_{uuid.uuid4().hex[:10]}"
        record = {
            "appointment_id": appointment_id,
            "referral_id": payload.referral_id,
            "child_id": payload.child_id,
            "scheduled_date": payload.scheduled_date,
            "appointment_type": payload.appointment_type,
            "status": "SCHEDULED",
            "created_by": payload.created_by or "aww",
            "created_on": datetime.utcnow().isoformat(),
            "notes": payload.notes or "",
        }
        appointments_store.setdefault(payload.referral_id, []).append(record)
        return {
            "status": "ok",
            "appointment": record,
            "suggested_status": _suggested_referral_status(payload.referral_id),
            "current_status": _current_referral_status(payload.referral_id),
        }

    @app.put("/appointments/{appointment_id}")
    def update_appointment(appointment_id: str, payload: AppointmentUpdateRequest):
        new_status = payload.status.strip().upper()
        if new_status not in {"SCHEDULED", "COMPLETED", "CANCELLED", "RESCHEDULED", "MISSED"}:
            raise HTTPException(status_code=400, detail="Invalid appointment status")
        for referral_id, records in appointments_store.items():
            for record in records:
                if record.get("appointment_id") == appointment_id:
                    record["status"] = new_status
                    if payload.notes:
                        record["notes"] = payload.notes
                    return {
                        "status": "ok",
                        "appointment": record,
                        "suggested_status": _suggested_referral_status(referral_id),
                        "current_status": _current_referral_status(referral_id),
                    }
        raise HTTPException(status_code=404, detail="Appointment not found")

    @app.get("/referral/{referral_id}/appointments")
    def list_appointments(referral_id: str):
        try:
            records = appointments_store.get(referral_id, [])
            next_scheduled = None
            scheduled = [r for r in records if r.get("status") == "SCHEDULED"]
            if scheduled:
                next_scheduled = sorted(scheduled, key=lambda r: r.get("scheduled_date") or "")[0]
            return {
                "referral_id": referral_id,
                "appointments": records,
                "suggested_status": _suggested_referral_status(referral_id),
                "current_status": _current_referral_status(referral_id),
                "next_appointment": next_scheduled,
            }
        except Exception as e:
            print(f"Error listing appointments: {e}")
            raise HTTPException(status_code=500, detail=str(e))

    @app.post("/referral/{referral_id}/status")
    def update_referral_status(referral_id: str, payload: ReferralStatusUpdateRequest):
        status = _status_to_db(payload.status)
        today = _today_iso()
        with _get_conn(db_path) as conn:
            row = conn.execute(
                "SELECT referral_id, referral_status FROM referral_action WHERE referral_id = %s LIMIT 1",
                (referral_id,),
            ).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Referral not found")
            completion_date = payload.completion_date or (
                today if status == "Completed" else None
            )
            appointment_date = payload.appointment_date or (
                today if status in {"Appointment Scheduled", "Under Treatment"} else None
            )
            escalation_level = None
            followup_deadline = None
            if status == "Missed":
                current = conn.execute(
                    "SELECT escalation_level FROM referral_action WHERE referral_id = %s",
                    (referral_id,),
                ).fetchone()
                level = int(current["escalation_level"] or 0) + 1 if current else 1
                escalation_level = level
                followup_deadline = (
                    datetime.utcnow().date() + timedelta(days=2)
                ).isoformat()
            conn.execute(
                """
                UPDATE referral_action
                SET referral_status = %s,
                    completion_date = COALESCE(%s, completion_date),
                    appointment_date = COALESCE(%s, appointment_date),
                    followup_deadline = COALESCE(%s, followup_deadline),
                    escalation_level = COALESCE(%s, escalation_level),
                    last_updated = %s
                WHERE referral_id = %s
                """,
                (
                    status,
                    completion_date,
                    appointment_date,
                    followup_deadline,
                    escalation_level,
                    today,
                    referral_id,
                ),
            )
            conn.execute(
                """
                INSERT INTO referral_status_history(
                    referral_id, old_status, new_status, changed_on, worker_id
                )
                VALUES(%s,%s,%s,%s,%s)
                """,
                (
                    referral_id,
                    row["referral_status"],
                    status,
                    today,
                    payload.worker_id,
                ),
            )
        referral_status_store[referral_id] = _status_to_frontend(status)
        return {
            "status": "ok",
            "referral_id": referral_id,
            "current_status": _status_to_frontend(status),
            "suggested_status": _suggested_referral_status(referral_id),
        }

    @app.put("/referral/update-status")
    def update_referral_status_by_id(payload: ReferralStatusUpdateByIdRequest):
        return update_referral_status(
            payload.referral_id,
            ReferralStatusUpdateRequest(
                status=payload.status,
                appointment_date=payload.appointment_date,
                completion_date=payload.completion_date,
                worker_id=payload.worker_id,
            ),
        )

    @app.post("/referral/{referral_id}/escalate")
    def escalate_referral(referral_id: str, payload: ReferralEscalateRequest):
        today = _today_iso()
        with _get_conn(db_path) as conn:
            row = conn.execute(
                """
                SELECT escalation_level, referral_status
                FROM referral_action
                WHERE referral_id = %s
                """,
                (referral_id,),
            ).fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="Referral not found")
            level = int(row["escalation_level"] or 0) + 1
            escalated_to = _escalation_target(level)
            new_deadline = (datetime.utcnow().date() + timedelta(days=2)).isoformat()
            conn.execute(
                """
                UPDATE referral_action
                SET escalation_level = %s,
                    escalated_to = %s,
                    followup_deadline = %s,
                    last_updated = %s
                WHERE referral_id = %s
                """,
                (level, escalated_to, new_deadline, today, referral_id),
            )
        return {
            "status": "ok",
            "referral_id": referral_id,
            "escalation_level": level,
            "escalated_to": escalated_to,
            "followup_deadline": new_deadline,
        }

    @app.get("/referral/{referral_id}/history")
    def get_referral_history(referral_id: str):
        with _get_conn(db_path) as conn:
            rows = conn.execute(
                """
                SELECT id, referral_id, old_status, new_status, changed_on, worker_id
                FROM referral_status_history
                WHERE referral_id = %s
                ORDER BY changed_on DESC, id DESC
                """,
                (referral_id,),
            ).fetchall()
        history = [
            {
                "id": r["id"],
                "referral_id": r["referral_id"],
                "old_status": _status_to_frontend(r["old_status"]),
                "new_status": _status_to_frontend(r["new_status"]),
                "changed_on": r["changed_on"],
                "worker_id": r["worker_id"],
            }
            for r in rows
        ]
        return {"referral_id": referral_id, "history": history}

    # ============================================================================
    # Problem B: Follow-Up Tracking Endpoints
    # ============================================================================

    @app.get("/follow-up/{referral_id}")
    def get_follow_up_page(referral_id: str):
        """Get complete follow-up page data: referral summary + activities"""
        with _get_conn(db_path) as conn:
            # Get referral details
            referral = conn.execute(
                """
                SELECT referral_id, child_id, aww_id, referral_type, urgency,
                       referral_status, referral_date, followup_deadline,
                       escalation_level, escalated_to
                FROM referral_action
                WHERE referral_id = %s
                """,
                (referral_id,),
            ).fetchone()

            if referral is None:
                raise HTTPException(status_code=404, detail="Referral not found")

            # Get follow-up activities
            activities = conn.execute(
                """
                SELECT id, referral_id, target_user, domain, activity_title,
                       activity_description, frequency, duration_days, created_on
                FROM follow_up_activities
                WHERE referral_id = %s
                ORDER BY target_user, domain
                """,
                (referral_id,),
            ).fetchall()

            # Get activity completion logs
            activity_logs = conn.execute(
                """
                SELECT activity_id, completed, completed_on, remarks
                FROM follow_up_log
                WHERE referral_id = %s
                ORDER BY completed_on DESC
                """,
                (referral_id,),
            ).fetchall()

        # Build activity completion map
        log_map = {int(log["activity_id"]): log for log in activity_logs}

        # Format response
        formatted_activities = []
        for act in activities:
            log = log_map.get(act["id"], {})
            formatted_activities.append({
                "id": act["id"],
                "target_user": act["target_user"],
                "domain": act["domain"],
                "title": act["activity_title"],
                "description": act["activity_description"],
                "frequency": act["frequency"],
                "duration_days": act["duration_days"],
                "completed": log.get("completed", 0) == 1,
                "completed_on": log.get("completed_on"),
                "remarks": log.get("remarks"),
            })

        # Determine days to deadline
        deadline = _parse_date_safe(referral["followup_deadline"])
        today = datetime.utcnow().date()
        days_remaining = (deadline - today).days if deadline else 0
        is_overdue = days_remaining < 0 and _status_to_frontend(referral["referral_status"]) != "COMPLETED"

        return {
            "referral_id": referral_id,
            "child_id": referral["child_id"],
            "facility": referral["referral_type"],
            "urgency": referral["urgency"],
            "status": _status_to_frontend(referral["referral_status"]),
            "created_on": referral["referral_date"],
            "deadline": referral["followup_deadline"],
            "days_remaining": days_remaining,
            "is_overdue": is_overdue,
            "escalation_level": referral["escalation_level"],
            "escalated_to": referral["escalated_to"],
            "activities": formatted_activities,
            "total_activities": len(formatted_activities),
            "completed_activities": sum(1 for a in formatted_activities if a["completed"]),
        }

    class CompleteActivityRequest(BaseModel):
        remarks: Optional[str] = None

    @app.post("/follow-up/{referral_id}/activity/{activity_id}/complete")
    def complete_activity(referral_id: str, activity_id: int, payload: CompleteActivityRequest):
        """Mark an activity as completed"""
        today = datetime.utcnow().date().isoformat()

        with _get_conn(db_path) as conn:
            # Verify activity exists
            activity = conn.execute(
                """
                SELECT id FROM follow_up_activities
                WHERE id = %s AND referral_id = %s
                """,
                (activity_id, referral_id),
            ).fetchone()

            if activity is None:
                raise HTTPException(status_code=404, detail="Activity not found")

            # Insert completion log
            conn.execute(
                """
                INSERT INTO follow_up_log (
                    referral_id, activity_id, completed, completed_on, remarks
                ) VALUES (%s, %s, %s, %s, %s)
                """,
                (referral_id, activity_id, 1, today, payload.remarks or ""),
            )

        return {
            "status": "ok",
            "activity_id": activity_id,
            "completed_on": today,
        }

    @app.get("/follow-up/{referral_id}/progress")
    def get_follow_up_progress(referral_id: str):
        """Get follow-up completion progress"""
        with _get_conn(db_path) as conn:
            # Count total activities
            total = conn.execute(
                """
                SELECT COUNT(*) as cnt FROM follow_up_activities
                WHERE referral_id = %s
                """,
                (referral_id,),
            ).fetchone()["cnt"]

            # Count completed activities
            completed = conn.execute(
                """
                SELECT COUNT(DISTINCT activity_id) as cnt FROM follow_up_log
                WHERE referral_id = %s AND completed = 1
                """,
                (referral_id,),
            ).fetchone()["cnt"]

        completion_percent = int((completed / total * 100) if total > 0 else 0)

        return {
            "referral_id": referral_id,
            "total_activities": total,
            "completed_activities": completed,
            "completion_percent": completion_percent,
        }

    @app.post("/follow-up/auto-escalate-overdue")
    def auto_escalate_overdue():
        """Auto-escalate all overdue referrals that haven't been completed"""
        today = datetime.utcnow().date()
        escalated_count = 0

        with _get_conn(db_path) as conn:
            # Find all overdue referrals
            overdue = conn.execute(
                """
                SELECT referral_id, escalation_level, referral_status
                FROM referral_action
                WHERE followup_deadline < %s AND referral_status != 'Completed'
                """,
                (today.isoformat(),),
            ).fetchall()

            for referral in overdue:
                referral_id = referral["referral_id"]
                current_level = int(referral["escalation_level"] or 0)
                new_level = current_level + 1
                escalated_to = _escalation_target(new_level)
                new_deadline = (today + timedelta(days=2)).isoformat()

                # Update referral
                conn.execute(
                    """
                    UPDATE referral_action
                    SET escalation_level = %s,
                        escalated_to = %s,
                        followup_deadline = %s,
                        last_updated = %s
                    WHERE referral_id = %s
                    """,
                    (new_level, escalated_to, new_deadline, today.isoformat(), referral_id),
                )

                # Log in status history
                conn.execute(
                    """
                    INSERT INTO referral_status_history (
                        referral_id, old_status, new_status, changed_on, worker_id
                    ) VALUES (%s, %s, %s, %s, %s)
                    """,
                    (
                        referral_id,
                        referral["referral_status"],
                        "Escalated (Overdue)",
                        today.isoformat(),
                        "SYSTEM_AUTO",
                    ),
                )

                escalated_count += 1

        return {
            "status": "ok",
            "escalated_count": escalated_count,
            "timestamp": datetime.utcnow().isoformat(),
            "message": f"Auto-escalated {escalated_count} overdue referral(s)",
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

    # ============================================================================
    # Problem B: Intervention Plan Management Endpoints
    # ============================================================================

    class InterventionPlanCreateRequest(BaseModel):
        child_id: str
        domain: str
        risk_level: str
        baseline_delay_months: Optional[int] = 3
        age_months: int

    @app.post("/intervention/plan/create")
    def create_intervention(payload: InterventionPlanCreateRequest):
        """Create intervention phase from risk assessment - starts strict 7-phase lifecycle"""
        try:
            from .problem_b_service import problem_b_service
        except ImportError:
            from problem_b_service import problem_b_service

        result = problem_b_service.create_intervention_phase(
            child_id=payload.child_id,
            domain=payload.domain,
            severity=payload.risk_level,  # risk_level -> severity
            baseline_delay=float(payload.baseline_delay_months),
            age_months=payload.age_months
        )
        return result

    class WeeklyProgressLogRequest(BaseModel):
        phase_id: str
        current_delay_months: float
        aww_completed: Optional[int] = 0
        caregiver_completed: Optional[int] = 0
        notes: Optional[str] = ""

    @app.post("/intervention/{phase_id}/progress/log")
    def log_weekly_progress(phase_id: str, payload: WeeklyProgressLogRequest):
        """Log activity completion and get review decision"""
        try:
            from .problem_b_service import problem_b_service
        except ImportError:
            from problem_b_service import problem_b_service

        # Persist weekly task logs from AWW/Caregiver completion counts.
        # This keeps compliance engine aligned with submitted weekly progress.
        try:
            with problem_b_service._get_conn(problem_b_service.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    SELECT activity_id, role FROM activities
                    WHERE phase_id = %s
                    ORDER BY role, created_at ASC
                    """,
                    (phase_id,),
                )
                activities = cursor.fetchall()
                aww_ids = [r["activity_id"] for r in activities if str(r["role"]).strip().lower() == "aww"]
                caregiver_ids = [r["activity_id"] for r in activities if str(r["role"]).strip().lower() != "aww"]
                aww_completed = max(int(payload.aww_completed or 0), 0)
                caregiver_completed = max(int(payload.caregiver_completed or 0), 0)
                now = datetime.utcnow().isoformat()

                def _log(activity_ids, completed_count):
                    for idx, activity_id in enumerate(activity_ids):
                        task_id = f"task_{uuid.uuid4().hex[:12]}"
                        done = 1 if idx < completed_count else 0
                        cursor.execute(
                            """
                            INSERT INTO task_logs(task_id, activity_id, date_logged, completed)
                            VALUES (%s, %s, %s, %s)
                            """,
                            (task_id, activity_id, now, done),
                        )

                _log(aww_ids, aww_completed)
                _log(caregiver_ids, caregiver_completed)
                conn.commit()
        except Exception:
            # Keep review flow non-blocking if task log insert has issues.
            pass

        # Calculate compliance for this phase
        compliance = problem_b_service.calculate_compliance(phase_id)
        
        # Run review if at review date
        review_result = problem_b_service.run_review_engine(phase_id, payload.current_delay_months)

        return {
            "phase_id": phase_id,
            "decision": review_result.get("decision", "CONTINUE"),
            "reason": review_result.get("reason", "Progress on track"),
            "adherence": float(compliance),
            "improvement": float(review_result.get("improvement", 0.0) or 0.0),
            "review_id": review_result.get("review_id", ""),
            "review_count": int(review_result.get("review_count", 0) or 0),
            "compliance": compliance,
            "review_decision": review_result,
            "notes": payload.notes
        }

    @app.get("/intervention/{phase_id}/activities")
    def get_intervention_activities(phase_id: str):
        """Fetch generated activities for a phase."""
        try:
            with problem_b_service._get_conn(problem_b_service.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    SELECT activity_id, phase_id, domain, role, name, frequency_per_week, created_at
                    FROM activities
                    WHERE phase_id = %s
                    ORDER BY role, created_at ASC
                    """,
                    (phase_id,),
                )
                rows = [dict(r) for r in cursor.fetchall()]
            return {"phase_id": phase_id, "activities": rows}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @app.get("/intervention/{phase_id}/history")
    def get_intervention_history(phase_id: str):
        """Fetch full phase history: status, activities, review decisions, task logs."""
        try:
            phase_status = problem_b_service.get_phase_status(phase_id)
            if phase_status.get("status") == "error":
                raise HTTPException(status_code=404, detail=phase_status.get("message", "Phase not found"))

            with problem_b_service._get_conn(problem_b_service.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    SELECT activity_id, phase_id, domain, role, name, frequency_per_week, created_at
                    FROM activities
                    WHERE phase_id = %s
                    ORDER BY role, created_at ASC
                    """,
                    (phase_id,),
                )
                activities = [dict(r) for r in cursor.fetchall()]

                cursor.execute(
                    """
                    SELECT review_id, phase_id, review_date, compliance, improvement, decision_action, decision_reason
                    FROM review_log
                    WHERE phase_id = %s
                    ORDER BY review_date DESC
                    """,
                    (phase_id,),
                )
                reviews = [dict(r) for r in cursor.fetchall()]

                cursor.execute(
                    """
                    SELECT t.task_id, t.activity_id, t.date_logged, t.completed, a.role, a.name
                    FROM task_logs t
                    JOIN activities a ON a.activity_id = t.activity_id
                    WHERE a.phase_id = %s
                    ORDER BY t.date_logged DESC
                    LIMIT 200
                    """,
                    (phase_id,),
                )
                task_logs = [dict(r) for r in cursor.fetchall()]

            return {
                "phase_id": phase_id,
                "phase_status": phase_status,
                "activities": activities,
                "reviews": reviews,
                "task_logs": task_logs,
            }
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @app.get("/intervention/{phase_id}/status")
    def get_phase_status(phase_id: str):
        """Get current phase status with metrics"""
        try:
            from .problem_b_service import problem_b_service
        except ImportError:
            from problem_b_service import problem_b_service

        result = problem_b_service.get_phase_status(phase_id)
        return result

    @app.post("/intervention/{phase_id}/review")
    def trigger_review(phase_id: str, payload: WeeklyProgressLogRequest):
        """Trigger review engine - automatic decision point"""
        try:
            from .problem_b_service import problem_b_service
        except ImportError:
            from problem_b_service import problem_b_service

        result = problem_b_service.run_review_engine(phase_id, payload.current_delay_months)
        return result

    class PlanClosureRequest(BaseModel):
        closure_status: str = "success"  # success, referred, extended
        final_notes: Optional[str] = ""

    @app.post("/intervention/{phase_id}/complete")
    def complete_intervention_phase(phase_id: str, payload: PlanClosureRequest):
        """Mark intervention phase as completed"""
        try:
            try:
                from .problem_b_service import problem_b_service
            except ImportError:
                from problem_b_service import problem_b_service
            with _get_conn(problem_b_service.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "UPDATE intervention_phase SET status = 'COMPLETED' WHERE phase_id = %s",
                    (phase_id,),
                )
                if cursor.rowcount == 0:
                    raise HTTPException(status_code=404, detail="Phase not found")

                conn.commit()
                return {
                    "phase_id": phase_id,
                    "status": "COMPLETED",
                    "closure_type": payload.closure_status,
                    "completed_at": datetime.utcnow().isoformat(),
                }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn
    from pathlib import Path

    # Pick an import path that matches the current working directory.
    cwd = Path.cwd()
    if (cwd / "backend" / "app" / "main.py").exists():
        app_path = "backend.app.main:app"
    elif (cwd / "app" / "main.py").exists():
        app_path = "app.main:app"
    else:
        app_path = "main:app"

    uvicorn.run(app_path, host="127.0.0.1", port=8000, reload=True)

