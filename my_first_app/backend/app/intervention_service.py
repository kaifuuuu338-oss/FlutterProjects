from __future__ import annotations

from typing import Dict, List


DOMAIN_LABELS = {
    "GM": "Gross Motor",
    "FM": "Fine Motor",
    "LC": "Language & Communication",
    "COG": "Cognitive",
    "SE": "Social & Emotional",
}


def _normalize_risk(value: str) -> str:
    v = str(value or "").strip().lower()
    if v in {"critical", "high", "medium", "moderate", "low"}:
        return "medium" if v == "moderate" else v
    return "low"


def _domain_level_to_intensity(level: str) -> str:
    risk = _normalize_risk(level)
    if risk == "critical":
        return "Very High"
    if risk == "high":
        return "High"
    if risk == "medium":
        return "Moderate"
    return "Low"


def _domain_templates(age_months: int) -> Dict[str, Dict[str, List[str]]]:
    toddler = age_months < 36
    return {
        "GM": {
            "anganwadi_actions": [
                "Structured movement play for 15 minutes daily",
                "Balance and climbing practice with supervision",
                "Track weekly motor milestone checklist",
            ],
            "home_actions": [
                "Climb 3-5 stairs with caregiver support",
                "Ball kicking and chasing play for 10 minutes",
                "Parent-led movement imitation game daily",
            ],
        },
        "FM": {
            "anganwadi_actions": [
                "Stacking, bead, and pegboard activities",
                "Crayon grasp and tracing practice",
                "Hand-eye coordination play in small groups",
            ],
            "home_actions": [
                "Sort pulses or safe household items by hand",
                "Tear-and-paste paper activity with caregiver",
                "Spoon transfer game for 10 minutes",
            ],
        },
        "LC": {
            "anganwadi_actions": [
                "Storytelling circle with repetition prompts",
                "Object naming and action-word practice",
                "Peer turn-taking conversation activity",
            ],
            "home_actions": [
                "Name 5 objects at home every day",
                "Sound imitation and picture talk",
                "Read or narrate one short story nightly",
            ],
        },
        "COG": {
            "anganwadi_actions": [
                "Simple puzzle and matching tasks",
                "Cause-effect toy demonstrations",
                "Guided memory and sequencing game",
            ],
            "home_actions": [
                "Shape or color sorting game daily",
                "Find-hidden-object activity",
                "Name-and-group household objects",
            ],
        },
        "SE": {
            "anganwadi_actions": [
                "Turn-taking and cooperative play session",
                "Emotion identification with picture cards",
                "Routine-based behavior regulation support",
            ],
            "home_actions": [
                "One-to-one play and praise routine daily",
                "Simple calm-down routine before sleep",
                "Teach feeling words during daily activities",
            ],
        },
        "BPS_AUT": {
            "anganwadi_actions": [
                "Joint attention and imitation games",
                "Eye-contact and response-to-name drills",
                "Structured social play with peer model",
            ],
            "home_actions": [
                "Name call + reward response practice",
                "Shared play for 15 minutes daily",
                "Gesture imitation and pointing game",
            ],
        },
        "BPS_ADHD": {
            "anganwadi_actions": [
                "Short structured tasks with movement breaks",
                "Single-step instruction practice",
                "Positive reinforcement behavior chart",
            ],
            "home_actions": [
                "5-minute focused play blocks with breaks",
                "Reduce distractions during activity time",
                "Use clear one-step caregiver instructions",
            ],
        },
        "BPS_BEH": {
            "anganwadi_actions": [
                "Emotion regulation circle time",
                "Predictable routine and transition cues",
                "Conflict-free peer interaction support",
            ],
            "home_actions": [
                "Daily calm routine and consistent boundaries",
                "Praise positive behavior immediately",
                "Use visual routine reminders",
            ],
        },
    }


def _domain_entry(
    domain: str,
    risk_level: str,
    age_months: int,
) -> Dict[str, object]:
    templates = _domain_templates(age_months)
    template = templates.get(domain, {"anganwadi_actions": [], "home_actions": []})
    return {
        "domain": domain,
        "domain_label": DOMAIN_LABELS.get(domain, domain),
        "risk_level": risk_level,
        "intensity": _domain_level_to_intensity(risk_level),
        "anganwadi_actions": template["anganwadi_actions"],
        "home_actions": template["home_actions"],
    }


def _dynamic_adjustment_rule(baseline: Dict[str, int], follow_up: Dict[str, int]) -> Dict[str, object]:
    baseline_sum = sum(int(v) for v in baseline.values())
    follow_sum = sum(int(v) for v in follow_up.values())
    reduction = baseline_sum - follow_sum

    if reduction >= 2:
        action = "decrease_intensity"
        recommendation = "Reduce intervention frequency by one session per week and continue monitoring."
        trend = "Improving"
    elif reduction < 0:
        action = "increase_intensity"
        recommendation = "Increase intervention frequency and prioritize home visit within 7 days."
        trend = "Regressing"
    else:
        action = "maintain_or_increase"
        recommendation = "No meaningful gain. Increase caregiver coaching and maintain high-intensity activities."
        trend = "Needs attention"

    return {
        "delay_reduction": reduction,
        "trend": trend,
        "action": action,
        "recommendation": recommendation,
        "rule": "if delay_reduction >= 2 then decrease intensity else increase intervention frequency",
    }


def generate_intervention_plan(payload: dict) -> dict:
    child_id = str(payload.get("child_id", ""))
    age_months = int(payload.get("age_months", 0))
    overall_risk = _normalize_risk(str(payload.get("risk_category", payload.get("overall_risk", "low"))))
    domain_risk_levels = payload.get("domain_risk_levels", {}) or {}
    delay_summary = payload.get("delay_summary", {}) or {}

    baseline_flags = {
        "GM_delay": int(delay_summary.get("GM_delay", 0)),
        "FM_delay": int(delay_summary.get("FM_delay", 0)),
        "LC_delay": int(delay_summary.get("LC_delay", 0)),
        "COG_delay": int(delay_summary.get("COG_delay", 0)),
        "SE_delay": int(delay_summary.get("SE_delay", 0)),
    }

    follow_up_flags = payload.get("follow_up_delay_summary", {}) or {}
    follow_up = {
        "GM_delay": int(follow_up_flags.get("GM_delay", baseline_flags["GM_delay"])),
        "FM_delay": int(follow_up_flags.get("FM_delay", baseline_flags["FM_delay"])),
        "LC_delay": int(follow_up_flags.get("LC_delay", baseline_flags["LC_delay"])),
        "COG_delay": int(follow_up_flags.get("COG_delay", baseline_flags["COG_delay"])),
        "SE_delay": int(follow_up_flags.get("SE_delay", baseline_flags["SE_delay"])),
    }

    domains_for_plan = []
    key_map = {
        "GM_delay": "GM",
        "FM_delay": "FM",
        "LC_delay": "LC",
        "COG_delay": "COG",
        "SE_delay": "SE",
    }
    for delay_key, domain_key in key_map.items():
        if baseline_flags[delay_key] == 1:
            domains_for_plan.append(domain_key)

    for extra in ["BPS_AUT", "BPS_ADHD", "BPS_BEH"]:
        lvl = _normalize_risk(str(domain_risk_levels.get(extra, "low")))
        if lvl in {"medium", "high", "critical"}:
            domains_for_plan.append(extra)

    if not domains_for_plan:
        domains_for_plan = ["GM", "LC"]

    domain_plan = []
    for domain in domains_for_plan:
        level = _normalize_risk(str(domain_risk_levels.get(domain, overall_risk)))
        domain_plan.append(_domain_entry(domain, level, age_months))

    dynamic_adjustment = _dynamic_adjustment_rule(baseline_flags, follow_up)
    high_load = sum(baseline_flags.values()) >= 2 or overall_risk in {"high", "critical"}

    return {
        "child_id": child_id,
        "age_months": age_months,
        "risk_category": overall_risk,
        "review_days": 30,
        "home_visit_priority": "YES" if high_load else "NO",
        "referral_required": "YES" if overall_risk in {"high", "critical"} else "NO",
        "anganwadi_plan": domain_plan,
        "aww_action_plan": [
            "Conduct 15-minute structured intervention session daily for active domains.",
            "Demonstrate at least 2 home activities to caregiver during visit.",
            "Record child response and caregiver adherence in app.",
            "Review progress in 30 days and update plan dynamically.",
        ],
        "caregiver_support": {
            "smartphone": [
                "Short video activity demo in local language",
                "WhatsApp nudges 3 times per week",
                "Weekly progress reminder message",
            ],
            "feature_phone": [
                "IVR guidance call in local language",
                "Missed-call callback for activity tips",
            ],
            "offline": [
                "Pictorial activity card shared by AWW",
                "In-person demonstration during home visit",
            ],
        },
        "dynamic_adjustment": dynamic_adjustment,
        "impact_tracking": {
            "baseline_delay_flags": baseline_flags,
            "current_delay_flags": follow_up,
            "target_metrics": [
                "Reduction in number of delayed domains",
                "Improvement in domain-wise risk levels",
                "Follow-up compliance rate",
                "Exit from high/critical risk category",
            ],
        },
        "compliance_notes": [
            "Screening support only; not a clinical diagnosis.",
            "Use with informed caregiver consent.",
            "Role-based access and secure storage required.",
            "DPDP Act 2023 data-protection controls must be followed.",
        ],
    }
