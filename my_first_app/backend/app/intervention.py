from __future__ import annotations

from typing import Dict, List, Tuple
from datetime import datetime

def _intensity_from_risk(risk_level: str) -> str:
    r = str(risk_level).lower()
    if r == "critical":
        return "High"
    if r in {"high"}:
        return "Moderate"
    if r in {"medium", "moderate"}:
        return "Low"
    return "Routine"


def _domain_interventions(domain: str, severity: str, age_months: int) -> Tuple[List[str], List[str]]:
    """Return (center_activities, home_activities) for a domain based on severity and age."""
    center: List[str] = []
    home: List[str] = []
    d = domain.upper()
    sev = str(severity).lower()

    if d == "LC":
        center = [
            "Structured storytelling circle (15 min)",
            "Peer communication group",
            "Picture naming & object labelling games",
        ]
        home = [
            "Name 5 objects daily",
            "Encourage 2-word phrases",
            "Daily 10-min reading and picture naming",
        ]
    elif d == "GM":
        center = ["Balance & movement play", "Structured gross-motor activities"]
        home = ["Guided play with climbing and stepping tasks"]
    elif d == "FM":
        center = ["Fine motor stations (blocks, stacking)"]
        home = ["Daily drawing or block stacking practice"]
    elif d == "SE":
        center = ["Peer play & emotion naming circle"]
        home = ["Parent-child turn-taking games"]
    elif d == "COG":
        center = ["Shape sorting and memory games"]
        home = ["Simple memory card games at home"]
    else:
        center = ["General stimulation activities"]
        home = ["Play and reading at home"]

    # Adjust intensity/focus based on severity
    if sev in {"critical", "high"}:
        center = [f"(High intensity) {c}" for c in center]
        home = [f"(Daily) {h}" for h in home]
    elif sev in {"medium", "moderate"}:
        center = [f"(Moderate) {c}" for c in center]
        home = [f"(3x/week) {h}" for h in home]

    # Age-based tweak (example): for very young children, prefer play-based prompts
    if age_months < 24:
        home = [f"(Play-based) {h}" for h in home]

    return center, home


def generate_intervention(payload: dict) -> Dict:
    """Generate a personalized intervention plan from a screening payload.

    Input: expects same structure as ScreeningRequest/model expects: age_months, domain_responses, optional risk fields
    Returns: dict with snapshot, plan, intensity, explanation, referral guidance and aww checklist template
    """
    age = int(payload.get("age_months", 0))
    domain_scores = payload.get("domain_scores") or payload.get("domain_responses", {})

    # If domain_scores is domain_responses, convert to severity flags using simple heuristic
    if domain_scores and all(isinstance(v, list) for v in domain_scores.values()):
        ds: Dict[str, str] = {}
        for k, arr in domain_scores.items():
            misses = sum(1 for x in arr if int(x) == 0)
            ratio = misses / max(len(arr), 1)
            if ratio >= 0.75:
                ds[k] = "Critical"
            elif ratio >= 0.5:
                ds[k] = "High"
            elif ratio >= 0.25:
                ds[k] = "Mild"
            else:
                ds[k] = "Normal"
        domain_scores = ds

    # If domain_scores is provided already as statuses, use them
    if not isinstance(domain_scores, dict):
        domain_scores = {}

    # Build developmental snapshot
    snapshot = {d: domain_scores.get(d, "Normal") for d in ["GM", "FM", "LC", "COG", "SE"]}

    # Count delays
    num_delays = sum(1 for v in snapshot.values() if v.lower() in {"critical", "high", "mild", "moderate"} and v.lower() != "normal")

    priority_score = int(payload.get("baseline_score", 0)) if payload.get("baseline_score") is not None else 0
    risk_category = payload.get("risk_level", "Low")
    intensity = _intensity_from_risk(risk_category)

    # Generate plan by domain
    center_activities: List[str] = []
    home_activities: List[str] = []
    for domain, severity in snapshot.items():
        c, h = _domain_interventions(domain, severity, age)
        center_activities.extend(c)
        home_activities.extend(h)

    # Trim duplicates while preserving order
    def unique(seq: List[str]) -> List[str]:
        seen = set()
        out = []
        for s in seq:
            if s not in seen:
                seen.add(s)
                out.append(s)
        return out

    center_activities = unique(center_activities)
    home_activities = unique(home_activities)

    # AWW checklist template
    aww_checklist = [
        {"key": "storytelling", "label": "Demonstrated storytelling", "done": False},
        {"key": "peer_activity", "label": "Conducted peer activity", "done": False},
        {"key": "home_visit", "label": "Home visit completed", "done": False},
        {"key": "parent_counsel", "label": "Parent counselled", "done": False},
    ]

    # Risk explanation box
    explanation = payload.get("explanation") or payload.get("reason") or []
    if isinstance(explanation, list):
        explanation_box = explanation
    else:
        explanation_box = [str(explanation)] if explanation else []

    result = {
        "development_snapshot": snapshot,
        "num_delays": num_delays,
        "priority_score": priority_score,
        "risk_category": risk_category,
        "intensity": intensity,
        "center_activities": center_activities,
        "home_activities": home_activities,
        "aww_checklist": aww_checklist,
        "explainable_reasons": explanation_box,
        "generated_at": datetime.utcnow().isoformat(),
    }
    return result


def calculate_trend(baseline_delay: int, followup_delay: int) -> Dict:
    reduction = baseline_delay - followup_delay
    if reduction > 2:
        trend = "Improving"
    elif reduction >= 0:
        trend = "Stable"
    else:
        trend = "Worsening"

    action = "continue"
    if trend == "Improving":
        action = "reduce_intensity"
    elif trend == "Worsening":
        action = "escalate"

    return {"reduction": reduction, "trend": trend, "recommended_action": action}
