from __future__ import annotations

import os
import uuid
import sqlite3
from collections import Counter
from datetime import datetime, date
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
    db_path = os.getenv(
        "ECD_DATA_DB",
        os.path.abspath(os.path.join(os.path.dirname(__file__), "ecd_data.db")),
    )
    _init_db(db_path)

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
        response = ScreeningResponse(**result)
        _save_screening(db_path, payload, response)
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
        return response

    @app.get("/analytics/monitoring")
    def analytics_monitoring(role: str = "state", location_id: str = "") -> dict:
        return _compute_monitoring(db_path, role=role, location_id=location_id)

    @app.get("/analytics/impact")
    def analytics_impact(role: str = "state", location_id: str = "") -> dict:
        return _compute_impact(db_path, role=role, location_id=location_id)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.app.main:app", host="127.0.0.1", port=8000, reload=True)
