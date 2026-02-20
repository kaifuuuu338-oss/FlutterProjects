from __future__ import annotations

import os
import json
import uuid
import sqlite3
import tempfile
from collections import Counter
from datetime import datetime, date
from typing import Dict, List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
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


class ChildRegisterRequest(BaseModel):
    child_id: str
    child_name: Optional[str] = None
    gender: Optional[str] = None
    age_months: int = 0
    awc_id: Optional[str] = None
    sector_id: Optional[str] = None
    mandal_id: Optional[str] = None
    district_id: Optional[str] = None
    created_at: Optional[str] = None


class ChildRegisterResponse(BaseModel):
    child_id: str
    status: str
    created_at: str


class ScreeningRequest(BaseModel):
    child_id: str
    age_months: int
    domain_responses: Dict[str, List[int]]
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


def _get_conn(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def _init_db(db_path: str) -> None:
    with _get_conn(db_path) as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS child_profile (
              child_id TEXT PRIMARY KEY,
              gender TEXT,
              age_months INTEGER,
              awc_id TEXT,
              sector_id TEXT,
              mandal_id TEXT,
              district_id TEXT,
              created_at TEXT
            );

            CREATE TABLE IF NOT EXISTS screening_event (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              child_id TEXT,
              age_months INTEGER,
              overall_risk TEXT,
              explainability TEXT,
              assessment_cycle TEXT,
              created_at TEXT
            );

            CREATE TABLE IF NOT EXISTS screening_domain_score (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              screening_id INTEGER,
              domain TEXT,
              risk_label TEXT,
              score REAL
            );

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
            );

            CREATE TABLE IF NOT EXISTS followup_outcome (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              child_id TEXT,
              baseline_delay_months INTEGER,
              followup_delay_months INTEGER,
              improvement_status TEXT,
              followup_completed INTEGER,
              followup_date TEXT
            );

            CREATE TABLE IF NOT EXISTS app_state (
              state_key TEXT PRIMARY KEY,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS intervention_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              child_id TEXT NOT NULL,
              source TEXT NOT NULL,
              request_json TEXT NOT NULL,
              response_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS followup_assessment (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              child_id TEXT NOT NULL,
              baseline_delay INTEGER NOT NULL,
              followup_delay INTEGER NOT NULL,
              delay_reduction INTEGER NOT NULL,
              trend TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS caregiver_engagement_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              child_id TEXT NOT NULL,
              mode TEXT NOT NULL,
              contact_json TEXT,
              status TEXT NOT NULL,
              note TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )


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


def _pg_connect(pg_dsn: str):
    return psycopg2.connect(pg_dsn, cursor_factory=RealDictCursor)


def _init_pg_db(pg_dsn: str) -> None:
    with _pg_connect(pg_dsn) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS child_profile (
                  child_id TEXT PRIMARY KEY,
                  gender TEXT,
                  age_months INTEGER,
                  awc_id TEXT,
                  sector_id TEXT,
                  mandal_id TEXT,
                  district_id TEXT,
                  created_at TEXT
                );
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS screening_event (
                  id SERIAL PRIMARY KEY,
                  child_id TEXT,
                  age_months INTEGER,
                  overall_risk TEXT,
                  explainability TEXT,
                  assessment_cycle TEXT,
                  created_at TEXT
                );
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS screening_domain_score (
                  id SERIAL PRIMARY KEY,
                  screening_id INTEGER,
                  domain TEXT,
                  risk_label TEXT,
                  score DOUBLE PRECISION
                );
                """
            )
            cur.execute(
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
                );
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS followup_outcome (
                  id SERIAL PRIMARY KEY,
                  child_id TEXT,
                  baseline_delay_months INTEGER,
                  followup_delay_months INTEGER,
                  improvement_status TEXT,
                  followup_completed INTEGER,
                  followup_date TEXT
                );
                """
            )
        conn.commit()


def _upsert_child_profile_pg(pg_dsn: str, payload: ChildRegisterRequest) -> ChildRegisterResponse:
    created_at = payload.created_at or datetime.utcnow().isoformat()
    with _pg_connect(pg_dsn) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO child_profile(child_id, gender, age_months, awc_id, sector_id, mandal_id, district_id, created_at)
                VALUES(%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT(child_id) DO UPDATE SET
                  gender=COALESCE(NULLIF(EXCLUDED.gender, ''), child_profile.gender),
                  age_months=EXCLUDED.age_months,
                  awc_id=COALESCE(NULLIF(EXCLUDED.awc_id, ''), child_profile.awc_id),
                  sector_id=COALESCE(NULLIF(EXCLUDED.sector_id, ''), child_profile.sector_id),
                  mandal_id=COALESCE(NULLIF(EXCLUDED.mandal_id, ''), child_profile.mandal_id),
                  district_id=COALESCE(NULLIF(EXCLUDED.district_id, ''), child_profile.district_id)
                """,
                (
                    payload.child_id,
                    payload.gender or "",
                    int(payload.age_months or 0),
                    payload.awc_id or "",
                    payload.sector_id or "",
                    payload.mandal_id or "",
                    payload.district_id or "",
                    created_at,
                ),
            )
        conn.commit()
    return ChildRegisterResponse(child_id=payload.child_id, status="synced", created_at=created_at)


def _save_screening_pg(pg_dsn: str, payload: ScreeningRequest, result: ScreeningResponse) -> None:
    created_at = datetime.utcnow().isoformat()
    with _pg_connect(pg_dsn) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO child_profile(child_id, gender, age_months, awc_id, sector_id, mandal_id, district_id, created_at)
                VALUES(%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT(child_id) DO UPDATE SET
                  gender=COALESCE(NULLIF(EXCLUDED.gender, ''), child_profile.gender),
                  age_months=EXCLUDED.age_months,
                  awc_id=COALESCE(NULLIF(EXCLUDED.awc_id, ''), child_profile.awc_id),
                  sector_id=COALESCE(NULLIF(EXCLUDED.sector_id, ''), child_profile.sector_id),
                  mandal_id=COALESCE(NULLIF(EXCLUDED.mandal_id, ''), child_profile.mandal_id),
                  district_id=COALESCE(NULLIF(EXCLUDED.district_id, ''), child_profile.district_id)
                """,
                (
                    payload.child_id,
                    payload.gender or "",
                    payload.age_months,
                    payload.awc_id or "",
                    payload.sector_id or "",
                    payload.mandal or "",
                    payload.district or "",
                    created_at,
                ),
            )
            cur.execute(
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
            screening_id = int(cur.fetchone()["id"])
            for domain, risk in result.domain_scores.items():
                cur.execute(
                    """
                    INSERT INTO screening_domain_score(screening_id, domain, risk_label, score)
                    VALUES(%s,%s,%s,%s)
                    """,
                    (screening_id, domain, _normalize_risk(risk), _risk_score(risk)),
                )
            delay_months = int((result.delay_summary or {}).get("num_delays", 0)) * 2
            cur.execute(
                """
                SELECT id FROM followup_outcome
                WHERE child_id=%s
                ORDER BY id DESC
                LIMIT 1
                """,
                (payload.child_id,),
            )
            existing = cur.fetchone()
            if existing is None:
                cur.execute(
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
        conn.commit()


def _create_referral_pg(pg_dsn: str, payload: ReferralRequest, referral_id: str) -> None:
    with _pg_connect(pg_dsn) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO referral_action(referral_id, child_id, aww_id, referral_required, referral_type, urgency, referral_status, referral_date, completion_date)
                VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """,
                (
                    referral_id,
                    payload.child_id,
                    payload.aww_id,
                    1,
                    payload.referral_type,
                    payload.urgency,
                    "Pending",
                    datetime.utcnow().date().isoformat(),
                    None,
                ),
            )
        conn.commit()

def _save_screening(db_path: str, payload: ScreeningRequest, result: ScreeningResponse) -> None:
    created_at = datetime.utcnow().isoformat()
    with _get_conn(db_path) as conn:
        conn.execute(
            """
            INSERT INTO child_profile(child_id, gender, age_months, awc_id, sector_id, mandal_id, district_id, created_at)
            VALUES(?,?,?,?,?,?,?,?)
            ON CONFLICT(child_id) DO UPDATE SET
              gender=COALESCE(NULLIF(excluded.gender, ''), child_profile.gender),
              age_months=excluded.age_months,
              awc_id=COALESCE(NULLIF(excluded.awc_id, ''), child_profile.awc_id),
              sector_id=COALESCE(NULLIF(excluded.sector_id, ''), child_profile.sector_id),
              mandal_id=COALESCE(NULLIF(excluded.mandal_id, ''), child_profile.mandal_id),
              district_id=COALESCE(NULLIF(excluded.district_id, ''), child_profile.district_id)
            """,
            (
                payload.child_id,
                payload.gender or "",
                payload.age_months,
                payload.awc_id or "",
                payload.sector_id or "",
                payload.mandal or "",
                payload.district or "",
                created_at,
            ),
        )
        cur = conn.execute(
            """
            INSERT INTO screening_event(child_id, age_months, overall_risk, explainability, assessment_cycle, created_at)
            VALUES(?,?,?,?,?,?)
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
        screening_id = cur.lastrowid
        for domain, risk in result.domain_scores.items():
            conn.execute(
                """
                INSERT INTO screening_domain_score(screening_id, domain, risk_label, score)
                VALUES(?,?,?,?)
                """,
                (screening_id, domain, _normalize_risk(risk), _risk_score(risk)),
            )

        # Create/refresh a follow-up row so Problem D can start tracking outcomes.
        delay_months = int((result.delay_summary or {}).get("num_delays", 0)) * 2
        existing = conn.execute(
            """
            SELECT id FROM followup_outcome
            WHERE child_id=?
            ORDER BY id DESC
            LIMIT 1
            """,
            (payload.child_id,),
        ).fetchone()
        if existing is None:
            conn.execute(
                """
                INSERT INTO followup_outcome(child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date)
                VALUES(?,?,?,?,?,?)
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


def _upsert_child_profile(db_path: str, payload: ChildRegisterRequest) -> ChildRegisterResponse:
    created_at = payload.created_at or datetime.utcnow().isoformat()
    with _get_conn(db_path) as conn:
        conn.execute(
            """
            INSERT INTO child_profile(child_id, gender, age_months, awc_id, sector_id, mandal_id, district_id, created_at)
            VALUES(?,?,?,?,?,?,?,?)
            ON CONFLICT(child_id) DO UPDATE SET
              gender=COALESCE(NULLIF(excluded.gender, ''), child_profile.gender),
              age_months=excluded.age_months,
              awc_id=COALESCE(NULLIF(excluded.awc_id, ''), child_profile.awc_id),
              sector_id=COALESCE(NULLIF(excluded.sector_id, ''), child_profile.sector_id),
              mandal_id=COALESCE(NULLIF(excluded.mandal_id, ''), child_profile.mandal_id),
              district_id=COALESCE(NULLIF(excluded.district_id, ''), child_profile.district_id)
            """,
            (
                payload.child_id,
                payload.gender or "",
                int(payload.age_months or 0),
                payload.awc_id or "",
                payload.sector_id or "",
                payload.mandal_id or "",
                payload.district_id or "",
                created_at,
            ),
        )
    return ChildRegisterResponse(
        child_id=payload.child_id,
        status="synced",
        created_at=created_at,
    )


def _state_key(kind: str, entity_id: str) -> str:
    return f"{kind}:{entity_id}"


def _save_state(db_path: str, kind: str, entity_id: str, payload: dict | list) -> None:
    key = _state_key(kind, entity_id)
    with _get_conn(db_path) as conn:
        conn.execute(
            """
            INSERT INTO app_state(state_key, payload_json, updated_at)
            VALUES(?,?,?)
            ON CONFLICT(state_key) DO UPDATE SET
              payload_json=excluded.payload_json,
              updated_at=excluded.updated_at
            """,
            (key, json.dumps(payload), datetime.utcnow().isoformat()),
        )


def _load_state(db_path: str, kind: str, entity_id: str, default):
    key = _state_key(kind, entity_id)
    with _get_conn(db_path) as conn:
        row = conn.execute(
            "SELECT payload_json FROM app_state WHERE state_key=?",
            (key,),
        ).fetchone()
    if row is None:
        return default
    try:
        return json.loads(row["payload_json"])
    except Exception:
        return default


def _compute_monitoring(db_path: str, role: str, location_id: str) -> dict:
    role_to_column = {"aww": "awc_id", "supervisor": "sector_id", "cdpo": "mandal_id", "district": "district_id", "state": ""}
    filter_column = role_to_column.get(role, "")
    with _get_conn(db_path) as conn:
        children = conn.execute("SELECT * FROM child_profile").fetchall()
        if filter_column and location_id:
            q = str(location_id).strip().upper()
            children = [
                c
                for c in children
                if str(c[filter_column] or "").strip().upper() == q
            ]
        child_ids = [c["child_id"] for c in children]
        child_map = {c["child_id"]: dict(c) for c in children}

        screenings = conn.execute("SELECT * FROM screening_event ORDER BY created_at DESC, id DESC").fetchall()
        latest_screen_by_child: Dict[str, sqlite3.Row] = {}
        for s in screenings:
            cid = s["child_id"]
            if cid in child_map and cid not in latest_screen_by_child:
                latest_screen_by_child[cid] = s

        latest_ids = [row["id"] for row in latest_screen_by_child.values()]
        domain_rows: List[sqlite3.Row] = []
        if latest_ids:
            placeholders = ",".join("?" for _ in latest_ids)
            domain_rows = conn.execute(
                f"SELECT * FROM screening_domain_score WHERE screening_id IN ({placeholders})",
                tuple(latest_ids),
            ).fetchall()
        domain_rows_by_screen: Dict[int, List[sqlite3.Row]] = {}
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

        latest_referral_by_child: Dict[str, sqlite3.Row] = {}
        for r in sorted(referrals, key=lambda x: (x["referral_date"] or "", x["referral_id"] or ""), reverse=True):
            if r["child_id"] not in latest_referral_by_child:
                latest_referral_by_child[r["child_id"]] = r
        latest_followup_by_child: Dict[str, sqlite3.Row] = {}
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
        where_clause = f" WHERE c.{column} = ? "
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
        by_child: Dict[str, List[sqlite3.Row]] = {}
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


def _refresh_pg_mirror_sqlite(pg_dsn: str) -> str:
    """
    Build a temporary SQLite mirror from PostgreSQL for analytics functions.
    This keeps existing monitoring/impact logic unchanged while PostgreSQL is source-of-truth.
    """
    mirror_path = os.path.join(tempfile.gettempdir(), "ecd_pg_mirror.db")
    _init_db(mirror_path)

    with _get_conn(mirror_path) as sqlite_conn:
        sqlite_conn.execute("DELETE FROM screening_domain_score")
        sqlite_conn.execute("DELETE FROM screening_event")
        sqlite_conn.execute("DELETE FROM referral_action")
        sqlite_conn.execute("DELETE FROM followup_outcome")
        sqlite_conn.execute("DELETE FROM child_profile")

        with _pg_connect(pg_dsn) as pg_conn:
            with pg_conn.cursor() as cur:
                cur.execute("SELECT child_id, gender, age_months, awc_id, sector_id, mandal_id, district_id, created_at FROM child_profile")
                for r in cur.fetchall():
                    sqlite_conn.execute(
                        """
                        INSERT INTO child_profile(child_id, gender, age_months, awc_id, sector_id, mandal_id, district_id, created_at)
                        VALUES(?,?,?,?,?,?,?,?)
                        """,
                        (
                            r.get("child_id"),
                            r.get("gender"),
                            int(r.get("age_months") or 0),
                            r.get("awc_id") or "",
                            r.get("sector_id") or "",
                            r.get("mandal_id") or "",
                            r.get("district_id") or "",
                            r.get("created_at") or "",
                        ),
                    )

                cur.execute("SELECT id, child_id, age_months, overall_risk, explainability, assessment_cycle, created_at FROM screening_event")
                for r in cur.fetchall():
                    sqlite_conn.execute(
                        """
                        INSERT INTO screening_event(id, child_id, age_months, overall_risk, explainability, assessment_cycle, created_at)
                        VALUES(?,?,?,?,?,?,?)
                        """,
                        (
                            int(r.get("id") or 0),
                            r.get("child_id"),
                            int(r.get("age_months") or 0),
                            r.get("overall_risk") or "",
                            r.get("explainability") or "",
                            r.get("assessment_cycle") or "Baseline",
                            r.get("created_at") or "",
                        ),
                    )

                cur.execute("SELECT id, screening_id, domain, risk_label, score FROM screening_domain_score")
                for r in cur.fetchall():
                    sqlite_conn.execute(
                        """
                        INSERT INTO screening_domain_score(id, screening_id, domain, risk_label, score)
                        VALUES(?,?,?,?,?)
                        """,
                        (
                            int(r.get("id") or 0),
                            int(r.get("screening_id") or 0),
                            r.get("domain") or "",
                            r.get("risk_label") or "",
                            float(r.get("score") or 0.0),
                        ),
                    )

                cur.execute(
                    """
                    SELECT referral_id, child_id, aww_id, referral_required, referral_type, urgency, referral_status, referral_date, completion_date
                    FROM referral_action
                    """
                )
                for r in cur.fetchall():
                    sqlite_conn.execute(
                        """
                        INSERT INTO referral_action(referral_id, child_id, aww_id, referral_required, referral_type, urgency, referral_status, referral_date, completion_date)
                        VALUES(?,?,?,?,?,?,?,?,?)
                        """,
                        (
                            r.get("referral_id"),
                            r.get("child_id"),
                            r.get("aww_id"),
                            int(r.get("referral_required") or 0),
                            r.get("referral_type") or "",
                            r.get("urgency") or "",
                            r.get("referral_status") or "",
                            r.get("referral_date") or "",
                            r.get("completion_date"),
                        ),
                    )

                cur.execute(
                    """
                    SELECT id, child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date
                    FROM followup_outcome
                    """
                )
                for r in cur.fetchall():
                    sqlite_conn.execute(
                        """
                        INSERT INTO followup_outcome(id, child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date)
                        VALUES(?,?,?,?,?,?,?)
                        """,
                        (
                            int(r.get("id") or 0),
                            r.get("child_id"),
                            int(r.get("baseline_delay_months") or 0),
                            int(r.get("followup_delay_months") or 0),
                            r.get("improvement_status") or "No Change",
                            int(r.get("followup_completed") or 0),
                            r.get("followup_date") or "",
                        ),
                    )
    return mirror_path


def _compute_monitoring_postgres(pg_dsn: str, role: str, location_id: str) -> dict:
    mirror_path = _refresh_pg_mirror_sqlite(pg_dsn)
    return _compute_monitoring(mirror_path, role, location_id)


def _compute_impact_postgres(pg_dsn: str, role: str, location_id: str) -> dict:
    mirror_path = _refresh_pg_mirror_sqlite(pg_dsn)
    return _compute_impact(mirror_path, role, location_id)


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
        "ECD_DATA_DB",
        os.path.abspath(os.path.join(os.path.dirname(__file__), "ecd_data.db")),
    )
    postgres_dsn = os.getenv("ECD_POSTGRES_DSN", "").strip()
    _init_db(db_path)
    if postgres_dsn:
        _init_pg_db(postgres_dsn)
    def _phase_payload(child_id: str) -> Dict:
        rows = _load_state(db_path, "pb_activity_rows", child_id, [])
        summary = _load_state(db_path, "pb_activity_summary", child_id, {
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

    @app.post("/children/register", response_model=ChildRegisterResponse)
    def register_child(payload: ChildRegisterRequest) -> ChildRegisterResponse:
        if not payload.child_id.strip():
            raise HTTPException(status_code=400, detail="child_id is required")
        response = _upsert_child_profile(db_path, payload)
        if postgres_dsn:
            _upsert_child_profile_pg(postgres_dsn, payload)
        return response

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
            result = predict_risk(payload.dict(), artifacts)
        response = ScreeningResponse(**result)
        _save_screening(db_path, payload, response)
        if postgres_dsn:
            _save_screening_pg(postgres_dsn, payload, response)
        return response

    @app.post("/referral/create", response_model=ReferralResponse)
    def create_referral(payload: ReferralRequest) -> ReferralResponse:
        if payload.referral_type not in {"PHC", "RBSK"}:
            raise HTTPException(status_code=400, detail="Referral type must be PHC or RBSK")
        referral_id = f"ref_{uuid.uuid4().hex[:12]}"
        response = ReferralResponse(
            referral_id=referral_id,
            status="Pending",
            created_at=datetime.utcnow().isoformat(),
        )
        with _get_conn(db_path) as conn:
            conn.execute(
                """
                INSERT INTO referral_action(referral_id, child_id, aww_id, referral_required, referral_type, urgency, referral_status, referral_date, completion_date)
                VALUES(?,?,?,?,?,?,?,?,?)
                """,
                (
                    referral_id,
                    payload.child_id,
                    payload.aww_id,
                    1,
                    payload.referral_type,
                    payload.urgency,
                    "Pending",
                    datetime.utcnow().date().isoformat(),
                    None,
                ),
            )
        if postgres_dsn:
            _create_referral_pg(postgres_dsn, payload, referral_id)
        return response

    @app.get("/analytics/monitoring")
    def analytics_monitoring(role: str = "state", location_id: str = "") -> dict:
        if postgres_dsn:
            return _compute_monitoring_postgres(postgres_dsn, role=role, location_id=location_id)
        return _compute_monitoring(db_path, role=role, location_id=location_id)

    @app.get("/analytics/impact")
    def analytics_impact(role: str = "state", location_id: str = "") -> dict:
        if postgres_dsn:
            return _compute_impact_postgres(postgres_dsn, role=role, location_id=location_id)
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
        child_id = str(data.get("child_id") or "")
        if child_id:
            with _get_conn(db_path) as conn:
                conn.execute(
                    """
                    INSERT INTO intervention_history(child_id, source, request_json, response_json, created_at)
                    VALUES(?,?,?,?,?)
                    """,
                    (
                        child_id,
                        "intervention/plan",
                        json.dumps(data),
                        json.dumps(result),
                        datetime.utcnow().isoformat(),
                    ),
                )
        return result

    class FollowupRequest(BaseModel):
        child_id: str
        baseline_delay: int
        followup_delay: int

    @app.post("/followup/assess")
    def followup_assess(payload: FollowupRequest):
        reduction, trend = calculate_trend(payload.baseline_delay, payload.followup_delay)
        now_iso = datetime.utcnow().isoformat()
        with _get_conn(db_path) as conn:
            conn.execute(
                """
                INSERT INTO followup_assessment(child_id, baseline_delay, followup_delay, delay_reduction, trend, created_at)
                VALUES(?,?,?,?,?,?)
                """,
                (
                    payload.child_id,
                    int(payload.baseline_delay),
                    int(payload.followup_delay),
                    int(reduction),
                    trend,
                    now_iso,
                ),
            )
            conn.execute(
                """
                INSERT INTO followup_outcome(child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date)
                VALUES(?,?,?,?,?,?)
                """,
                (
                    payload.child_id,
                    int(payload.baseline_delay),
                    int(payload.followup_delay),
                    "Improving" if trend == "Improved" else ("Worsening" if trend == "Worsened" else "No Change"),
                    1,
                    datetime.utcnow().date().isoformat(),
                ),
            )
        if postgres_dsn:
            with _pg_connect(postgres_dsn) as pg_conn:
                with pg_conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO followup_outcome(child_id, baseline_delay_months, followup_delay_months, improvement_status, followup_completed, followup_date)
                        VALUES(%s,%s,%s,%s,%s,%s)
                        """,
                        (
                            payload.child_id,
                            int(payload.baseline_delay),
                            int(payload.followup_delay),
                            "Improving" if trend == "Improved" else ("Worsening" if trend == "Worsened" else "No Change"),
                            1,
                            datetime.utcnow().date().isoformat(),
                        ),
                    )
                pg_conn.commit()
        return {"delay_reduction": reduction, "trend": trend}

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
        req = payload.dict()
        result = generate_intervention_plan(req)
        with _get_conn(db_path) as conn:
            conn.execute(
                """
                INSERT INTO intervention_history(child_id, source, request_json, response_json, created_at)
                VALUES(?,?,?,?,?)
                """,
                (
                    payload.child_id,
                    "problem-b/intervention-plan",
                    json.dumps(req),
                    json.dumps(result),
                    datetime.utcnow().isoformat(),
                ),
            )
        return result

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
        _save_state(db_path, "pb_activity_rows", payload.child_id, assigned)
        _save_state(db_path, "pb_activity_summary", payload.child_id, summary)
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
        rows = _load_state(db_path, "pb_activity_rows", payload.child_id, [])
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
        _save_state(db_path, "pb_activity_rows", payload.child_id, rows)
        return {
            "status": "ok",
            "child_id": payload.child_id,
            "activity_id": payload.activity_id,
            "updated_status": status,
            **_phase_payload(payload.child_id),
        }

    @app.get("/problem-b/compliance/{child_id}")
    def get_problem_b_compliance(child_id: str):
        rows = _load_state(db_path, "pb_activity_rows", child_id, [])
        compliance = compute_compliance(rows)
        summary = _load_state(db_path, "pb_activity_summary", child_id, {})
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
        rows = _load_state(db_path, "pb_activity_rows", payload.child_id, [])
        updated_count = reset_frequency_status(rows, freq)
        _save_state(db_path, "pb_activity_rows", payload.child_id, rows)
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
        status = "ok"
        note = "Printed material to be provided"
        if "phone" in mode and payload.contact:
            status = "queued"
            note = "IVR/WhatsApp message scheduled"
        with _get_conn(db_path) as conn:
            conn.execute(
                """
                INSERT INTO caregiver_engagement_log(child_id, mode, contact_json, status, note, created_at)
                VALUES(?,?,?,?,?,?)
                """,
                (
                    payload.child_id,
                    payload.mode,
                    json.dumps(payload.contact or {}),
                    status,
                    note,
                    datetime.utcnow().isoformat(),
                ),
            )
        return {"status": status, "mode": payload.mode, "note": note}

    class TasksSaveRequest(BaseModel):
        child_id: str
        aww_checks: Optional[Dict[str, bool]] = None
        parent_checks: Optional[Dict[str, bool]] = None
        caregiver_checks: Optional[Dict[str, bool]] = None
        aww_remarks: Optional[str] = None
        caregiver_remarks: Optional[str] = None

    @app.post("/tasks/save")
    def save_tasks(payload: TasksSaveRequest):
        data = payload.dict()
        child = data.pop("child_id")
        _save_state(db_path, "tasks", child, data)
        return {"status": "saved", "child_id": child}

    @app.get("/tasks/{child_id}")
    def get_tasks(child_id: str):
        return _load_state(db_path, "tasks", child_id, {
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
