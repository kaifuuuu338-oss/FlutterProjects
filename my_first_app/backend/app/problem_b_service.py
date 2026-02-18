from __future__ import annotations

from typing import Dict, List, Tuple


def generate_intervention_plan(child: Dict) -> Dict:
    plan = {
        "center_activities": [],
        "home_activities": [],
        "intensity": "Routine",
    }

    gm_delay = int(child.get("gm_delay", 0))
    fm_delay = int(child.get("fm_delay", 0))
    lc_delay = int(child.get("lc_delay", 0))
    cog_delay = int(child.get("cog_delay", 0))
    se_delay = int(child.get("se_delay", 0))
    risk_category = str(child.get("risk_category", "Low")).lower()

    if gm_delay > 2:
        plan["center_activities"].append("Structured balance play")
        plan["home_activities"].append("Climb stairs with supervision")

    if fm_delay > 2:
        plan["center_activities"].append("Block stacking practice")
        plan["home_activities"].append("Drawing and spoon transfer practice")

    if lc_delay > 3:
        plan["center_activities"].append("Storytelling circle (15 mins)")
        plan["home_activities"].append("Name 5 objects daily")
        plan["home_activities"].append("Expand 2-word phrases")

    if se_delay > 2:
        plan["center_activities"].append("Peer play session")
        plan["home_activities"].append("Emotion naming practice")

    if cog_delay > 2:
        plan["center_activities"].append("Shape sorting and memory games")
        plan["home_activities"].append("Memory card game")

    if risk_category == "critical":
        plan["intensity"] = "High (Daily)"
    elif risk_category == "high":
        plan["intensity"] = "Moderate (5x/week)"
    elif risk_category == "medium":
        plan["intensity"] = "Low (3x/week)"

    plan["center_activities"] = _dedupe(plan["center_activities"])
    plan["home_activities"] = _dedupe(plan["home_activities"])
    return plan


def calculate_trend(baseline: int, followup: int) -> Tuple[int, str]:
    reduction = baseline - followup
    if reduction > 2:
        trend = "Improving"
    elif reduction >= 0:
        trend = "Stable"
    else:
        trend = "Worsening"
    return reduction, trend


def adjust_intensity(current_intensity: str, trend: str) -> str:
    if trend == "Improving":
        return "Reduce intensity"
    if trend == "Worsening":
        return "Escalate referral"
    return current_intensity


def next_review_decision(current_intensity: str, reduction: int, trend: str) -> str:
    if trend == "Worsening":
        return "Escalate referral"
    if reduction > 2:
        return "Reduce intensity"
    if trend == "Stable":
        return "Continue"
    return adjust_intensity(current_intensity, trend)


def rule_logic_table() -> Dict[str, List[Dict[str, str]]]:
    return {
        "domain_rules": [
            {"condition": "GM_delay > 2", "intervention": "Balance play + Climbing"},
            {"condition": "FM_delay > 2", "intervention": "Block stacking + Drawing"},
            {"condition": "LC_delay > 3", "intervention": "Storytelling + Object naming"},
            {"condition": "SE_delay > 2", "intervention": "Peer play + Emotion naming"},
            {"condition": "COG_delay > 2", "intervention": "Shape sorting + Memory games"},
        ],
        "intensity_rules": [
            {"severity": "Critical", "intensity": "High (Daily)"},
            {"severity": "High", "intensity": "Moderate (5x/week)"},
            {"severity": "Medium", "intensity": "Low (3x/week)"},
            {"severity": "Low", "intensity": "Routine"},
        ],
        "escalation_rules": [
            {"condition": "No improvement 2 reviews", "action": "Escalate"},
            {"condition": "Worsening", "action": "Referral"},
            {"condition": "Improvement >2 months", "action": "Reduce intensity"},
        ],
    }


def schema_tables() -> Dict[str, List[str]]:
    return {
        "child_profile": [
            "child_id (PK)",
            "name",
            "dob",
            "age_months",
            "gender",
            "awc_code",
            "sector",
            "mandal",
            "district",
            "state",
        ],
        "developmental_risk": [
            "risk_id (PK)",
            "child_id (FK)",
            "gm_delay_months",
            "fm_delay_months",
            "lc_delay_months",
            "cog_delay_months",
            "se_delay_months",
            "num_delays",
            "risk_score",
            "risk_category",
            "assessment_date",
        ],
        "neuro_behavioral": [
            "child_id (FK)",
            "autism_risk",
            "adhd_risk",
            "behavioral_risk",
        ],
        "intervention_plan": [
            "plan_id (PK)",
            "child_id (FK)",
            "intensity_level",
            "start_date",
            "review_date",
            "active_status",
        ],
        "intervention_activities": [
            "activity_id (PK)",
            "plan_id (FK)",
            "domain",
            "activity_type",
            "description",
            "frequency",
        ],
        "referral": [
            "referral_id (PK)",
            "child_id (FK)",
            "referral_type",
            "urgency",
            "status",
            "created_date",
            "followup_date",
            "reason",
        ],
        "followup_assessment": [
            "followup_id (PK)",
            "child_id (FK)",
            "gm_delay",
            "fm_delay",
            "lc_delay",
            "cog_delay",
            "se_delay",
            "assessment_date",
            "trend_status",
            "delay_reduction",
        ],
        "caregiver_engagement": [
            "engagement_id (PK)",
            "child_id (FK)",
            "mode",
            "last_nudge_date",
            "compliance_score",
        ],
    }


def _dedupe(items: List[str]) -> List[str]:
    seen = set()
    out: List[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out
