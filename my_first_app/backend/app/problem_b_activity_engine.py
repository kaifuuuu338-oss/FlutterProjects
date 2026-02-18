from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Dict, List, Tuple


AGE_BANDS = [
    (0, 6, "Infant 1"),
    (6, 12, "Infant 2"),
    (12, 24, "Toddler 1"),
    (24, 36, "Toddler 2"),
    (36, 48, "Preschool 1"),
    (48, 60, "Preschool 2"),
    (60, 72, "Preschool 3"),
]

SEVERITY_TO_WEIGHT = {
    "Mild": 1,
    "Moderate": 2,
    "Severe": 3,
    "Critical": 4,
}

SEVERITY_TO_REVIEW = {
    "Mild": 60,
    "Moderate": 30,
    "Severe": 15,
    "Critical": 15,
}

SEVERITY_TO_PHASE_WEEKS = {
    "Mild": 6,
    "Moderate": 8,
    "Severe": 12,
    "Critical": 16,
}

IMPROVEMENT_THRESHOLD = 1  # months reduction
ADHERENCE_THRESHOLD = 0.6  # 60%
ESCALATION_THRESHOLD = 0.4  # 40%
MAX_PHASE_WEEKS = 8


@dataclass(frozen=True)
class ActivityTemplate:
    title: str
    description: str
    duration_minutes: int


_DOMAIN_LIBRARY: Dict[str, Dict[str, Dict[str, List[ActivityTemplate]]]] = {
    "LC": {
        "caregiver": {
            "daily": [
                ActivityTemplate("Name 5 household objects", "Point to objects and label them clearly.", 10),
                ActivityTemplate("Ask 'What is this?'", "Encourage response with word/phrase.", 8),
                ActivityTemplate("2-word sentence prompting", "Model and expand short responses.", 10),
                ActivityTemplate("Read picture book", "Read and ask one simple question per page.", 12),
                ActivityTemplate("Action rhymes", "Use gesture+word repetition.", 10),
            ],
            "weekly": [
                ActivityTemplate("Storytelling family circle", "One short story and discussion.", 20),
                ActivityTemplate("Pretend-play conversation", "Role play shop/doctor/home.", 18),
                ActivityTemplate("Introduce 3 new words", "Practice new vocabulary in context.", 15),
                ActivityTemplate("Picture narration game", "Describe sequence in 3-4 steps.", 18),
                ActivityTemplate("Audio story listening", "Play story then ask recall question.", 15),
            ],
        },
        "aww": {
            "daily": [
                ActivityTemplate("Group rhyme session", "Conduct repetition-based rhyme circle.", 15),
                ActivityTemplate("Speech clarity check", "Observe and note articulation.", 8),
                ActivityTemplate("Ask 3 direct questions", "Prompt expressive responses.", 10),
                ActivityTemplate("Model 2-word responses", "Expand child speech with examples.", 10),
                ActivityTemplate("Peer talk facilitation", "Pair child with peer for talk turn.", 12),
            ],
            "weekly": [
                ActivityTemplate("Structured language circle", "Small group language stimulation.", 20),
                ActivityTemplate("Parent guidance session", "Demonstrate home language techniques.", 20),
                ActivityTemplate("Home visit follow-up", "Review caregiver activity quality.", 25),
                ActivityTemplate("Milestone mini re-check", "Quick language progression check.", 15),
                ActivityTemplate("Compliance record update", "Score adherence and update plan.", 10),
            ],
        },
    },
    "GM": {
        "caregiver": {
            "daily": [
                ActivityTemplate("Step climbing with support", "Assist step-up/down safely.", 10),
                ActivityTemplate("Ball rolling and kick", "Practice bilateral coordination.", 12),
                ActivityTemplate("Jumping imitation game", "Jump and land with cues.", 10),
                ActivityTemplate("Movement imitation", "Copy body movements.", 8),
                ActivityTemplate("Outdoor active play", "Free motor play with supervision.", 15),
            ],
            "weekly": [
                ActivityTemplate("Obstacle mini-course", "Create simple safe obstacle path.", 20),
                ActivityTemplate("Balance practice", "Heel-to-toe or line walking.", 15),
                ActivityTemplate("Throw-catch challenge", "Increase distance gradually.", 18),
                ActivityTemplate("Stair endurance session", "Progressive step repetitions.", 15),
                ActivityTemplate("Family movement game", "Group movement routine.", 20),
            ],
        },
        "aww": {
            "daily": [
                ActivityTemplate("Balance beam walk", "Supervised narrow path walking.", 12),
                ActivityTemplate("Ball catch/throw", "Structured catch drills.", 12),
                ActivityTemplate("Step-climb supervision", "Motor confidence building.", 10),
                ActivityTemplate("Jump sequence game", "Patterned jump sets.", 10),
                ActivityTemplate("Movement circuit", "Station-based gross motor routine.", 15),
            ],
            "weekly": [
                ActivityTemplate("Motor group session", "Peer gross motor play session.", 20),
                ActivityTemplate("AWW demo to caregiver", "Teach home GM exercise set.", 20),
                ActivityTemplate("Home movement audit", "Check safety and adherence.", 20),
                ActivityTemplate("Motor milestone quick-check", "Short reassessment routine.", 15),
                ActivityTemplate("Weekly progress logging", "Record completion and response.", 10),
            ],
        },
    },
    "FM": {
        "caregiver": {
            "daily": [
                ActivityTemplate("Line drawing practice", "Straight/curve tracing.", 10),
                ActivityTemplate("Sort 5 objects", "Sort by color/shape/size.", 10),
                ActivityTemplate("Block stacking", "Tower building progression.", 10),
                ActivityTemplate("Spoon transfer", "Transfer grains/water safely.", 8),
                ActivityTemplate("Grip squeeze toy", "Hand strength and dexterity.", 8),
            ],
            "weekly": [
                ActivityTemplate("Clay/paper craft", "Fine motor creative activity.", 18),
                ActivityTemplate("Bead thread session", "Large to medium beads.", 15),
                ActivityTemplate("Sticker placement game", "Precision finger control.", 12),
                ActivityTemplate("Puzzle hand task", "Small-piece manipulation.", 15),
                ActivityTemplate("Button/zip practice", "Self-help fine motor routine.", 15),
            ],
        },
        "aww": {
            "daily": [
                ActivityTemplate("Bead/peg activity", "Structured fine motor station.", 12),
                ActivityTemplate("Grip-tracing practice", "Pencil/crayon control.", 10),
                ActivityTemplate("Block challenge", "Hand-eye coordination set.", 10),
                ActivityTemplate("Object transfer task", "Precision finger movement.", 10),
                ActivityTemplate("Hand coordination game", "Targeted dexterity play.", 12),
            ],
            "weekly": [
                ActivityTemplate("Fine motor group lab", "Stations with graded tools.", 20),
                ActivityTemplate("Caregiver demo session", "Show home fine-motor routine.", 20),
                ActivityTemplate("Home practice review", "Check caregiver technique.", 20),
                ActivityTemplate("FM milestone quick-check", "Short progression test.", 15),
                ActivityTemplate("Weekly compliance update", "Record completion trend.", 10),
            ],
        },
    },
    "COG": {
        "caregiver": {
            "daily": [
                ActivityTemplate("Color-shape sorting", "Sort and name categories.", 10),
                ActivityTemplate("Memory card game", "Pair recall exercise.", 10),
                ActivityTemplate("Find hidden object", "Object permanence and attention.", 10),
                ActivityTemplate("Matching pairs", "Association building.", 8),
                ActivityTemplate("Simple problem game", "Choose-correct item task.", 10),
            ],
            "weekly": [
                ActivityTemplate("Story sequencing", "Arrange story cards in order.", 18),
                ActivityTemplate("Pattern building game", "Build and extend pattern.", 15),
                ActivityTemplate("Counting object play", "Number concept reinforcement.", 15),
                ActivityTemplate("Cause-effect activity", "Predict and observe outcomes.", 12),
                ActivityTemplate("Family quiz round", "Simple recall and categorization.", 18),
            ],
        },
        "aww": {
            "daily": [
                ActivityTemplate("Shape sorting tasks", "Guided concept sorting.", 12),
                ActivityTemplate("Pattern completion", "Cognitive pattern fill-in.", 10),
                ActivityTemplate("Memory recall rounds", "Quick recall prompts.", 10),
                ActivityTemplate("Puzzle corner", "Graded puzzle support.", 12),
                ActivityTemplate("Concept matching drill", "Name + classify routine.", 10),
            ],
            "weekly": [
                ActivityTemplate("Cognitive group circuit", "Multi-station cognition set.", 20),
                ActivityTemplate("Parent cognition demo", "Home cognitive stimulation demo.", 20),
                ActivityTemplate("Home cognition review", "Observe and coach caregiver.", 20),
                ActivityTemplate("COG milestone mini-check", "Structured review.", 15),
                ActivityTemplate("Weekly cognition scoring", "Update trend and notes.", 10),
            ],
        },
    },
    "SE": {
        "caregiver": {
            "daily": [
                ActivityTemplate("Turn-taking game", "Use toy/pass routine.", 10),
                ActivityTemplate("Emotion word practice", "Name happy/sad/angry etc.", 10),
                ActivityTemplate("Greeting practice", "Social greeting drills.", 8),
                ActivityTemplate("Shared toy activity", "Cooperative interaction.", 10),
                ActivityTemplate("Calm response routine", "Simple regulation steps.", 10),
            ],
            "weekly": [
                ActivityTemplate("Family social game", "Structured social participation.", 20),
                ActivityTemplate("Emotion story session", "Discuss characters' feelings.", 15),
                ActivityTemplate("Peer play meetup", "Supervised small-group play.", 20),
                ActivityTemplate("Reward chart review", "Positive reinforcement review.", 12),
                ActivityTemplate("Conflict-resolution roleplay", "Practice sharing/fair turns.", 18),
            ],
        },
        "aww": {
            "daily": [
                ActivityTemplate("Peer turn-taking session", "Facilitate shared play turns.", 12),
                ActivityTemplate("Emotion naming circle", "Group emotion vocabulary.", 10),
                ActivityTemplate("Cooperative play group", "Joint play with support.", 12),
                ActivityTemplate("Social greeting routine", "Start/end social scripts.", 8),
                ActivityTemplate("Behavior cue practice", "Use visual/verbal cues.", 10),
            ],
            "weekly": [
                ActivityTemplate("SE group circle", "Social-emotional group routine.", 20),
                ActivityTemplate("Parent social coaching", "Teach home SE strategies.", 20),
                ActivityTemplate("Home SE observation", "Follow-up on behavior context.", 20),
                ActivityTemplate("SE milestone quick-check", "Review social indicators.", 15),
                ActivityTemplate("Weekly SE compliance log", "Record adherence + outcomes.", 10),
            ],
        },
    },
}


def classify_age_band(age_months: int) -> str:
    age = int(age_months)
    for start, end, label in AGE_BANDS:
        if start <= age < end:
            return label
    return "Preschool 3"


def derive_severity(
    delayed_domains: List[str],
    autism_risk: str = "Low",
    baseline_risk_category: str = "Low",
) -> str:
    autism_high = str(autism_risk).strip().lower() == "high"
    if autism_high:
        return "Critical"
    delay_count = len(delayed_domains)
    if delay_count > 3:
        return "Severe"
    if delay_count >= 2:
        return "Moderate"
    return "Mild"


def build_activity_master_rows(
    age_band: str,
    delayed_domains: List[str],
    severity_level: str,
) -> List[Dict]:
    rows: List[Dict] = []
    weight = SEVERITY_TO_WEIGHT.get(severity_level, 1)
    for domain in delayed_domains:
        library = _DOMAIN_LIBRARY.get(domain, {})
        for stakeholder in ["aww", "caregiver"]:
            for frequency_type in ["daily", "weekly"]:
                for idx, template in enumerate(library.get(stakeholder, {}).get(frequency_type, []), start=1):
                    rows.append({
                        "activity_id": f"master_{domain}_{stakeholder}_{frequency_type}_{idx}",
                        "domain": domain,
                        "age_band": age_band,
                        "severity_level": severity_level,
                        "stakeholder": stakeholder,
                        "frequency_type": frequency_type,
                        "activity_type": "daily_core" if frequency_type == "daily" else "weekly_target",
                        "title": template.title,
                        "description": template.description,
                        "duration_minutes": template.duration_minutes,
                        "intensity_weight": weight,
                        "required_per_week": 7 if frequency_type == "daily" else 5,
                        "required_per_day": 1 if frequency_type == "daily" else 0,
                    })
    return rows


def _target_milestone(delayed_domains: List[str]) -> str:
    if "LC" in delayed_domains:
        return "Use 2-word meaningful phrases consistently"
    if "GM" in delayed_domains:
        return "Climb stairs with minimal support"
    if "FM" in delayed_domains:
        return "Improve grasp and controlled hand movement"
    if "SE" in delayed_domains:
        return "Participate in turn-taking social play"
    if "COG" in delayed_domains:
        return "Complete age-appropriate sorting and memory tasks"
    return "Maintain age-appropriate developmental trajectory"


def _expected_improvement(severity_level: str) -> str:
    severity = str(severity_level).strip().title()
    if severity == "Critical":
        return "Referral + 15-day monitoring"
    if severity == "Severe":
        return "3-4 months"
    if severity == "Moderate":
        return "2-3 months"
    return "1-2 months"


def assign_activities_for_child(
    child_id: str,
    age_months: int,
    delayed_domains: List[str],
    severity_level: str,
) -> Tuple[List[Dict], Dict]:
    age_band = classify_age_band(age_months)
    master_rows = build_activity_master_rows(age_band, delayed_domains, severity_level)
    now = datetime.utcnow().isoformat()
    today = date.today()
    phase_weeks = SEVERITY_TO_PHASE_WEEKS.get(severity_level, 8)
    review_cycle_days = SEVERITY_TO_REVIEW.get(severity_level, 30)
    phase_end = today + timedelta(weeks=phase_weeks)
    assigned = []
    for week_number in range(1, phase_weeks + 1):
        for row in master_rows:
            required_count = int(row["required_per_week"])
            assignment_id = f"{child_id}_{row['activity_id']}_w{week_number}"
            assigned.append({
                "tracking_id": assignment_id,
                "assignment_id": assignment_id,
                "child_id": child_id,
                "activity_id": assignment_id,
                "base_activity_id": row["activity_id"],
                "assigned_date": now,
                "frequency_type": row["frequency_type"],
                "activity_type": row["activity_type"],
                "stakeholder": row["stakeholder"],
                "domain": row["domain"],
                "title": row["title"],
                "description": row["description"],
                "duration_minutes": row["duration_minutes"],
                "required_per_week": required_count,
                "required_per_day": int(row["required_per_day"]),
                "required_count": required_count,
                "completed_count": 0,
                "week_number": week_number,
                "status": "pending",
                "completion_date": None,
                "compliance_score": 0,
                "age_band": age_band,
                "severity_level": severity_level,
                "review_cycle_days": review_cycle_days,
            })
    summary = {
        "child_id": child_id,
        "age_band": age_band,
        "severity_level": severity_level,
        "review_cycle_days": review_cycle_days,
        "phase_duration_weeks": phase_weeks,
        "phase_start_date": today.isoformat(),
        "phase_end_date": phase_end.isoformat(),
        "expected_improvement_window": _expected_improvement(severity_level),
        "target_milestone": _target_milestone(delayed_domains),
        "domains": delayed_domains,
        "total_activities": len(assigned),
        "daily_count": sum(1 for a in assigned if a["activity_type"] == "daily_core"),
        "weekly_count": sum(1 for a in assigned if a["activity_type"] == "weekly_target"),
    }
    return assigned, summary


def compute_compliance(tracking_rows: List[Dict]) -> Dict:
    if not tracking_rows:
        return {
            "completion_percent": 0,
            "completed": 0,
            "total": 0,
            "action": "Reinforce",
        }
    total_required = sum(max(int(row.get("required_count", 1)), 1) for row in tracking_rows)
    total_done = sum(
        min(
            int(row.get("completed_count", 0)),
            max(int(row.get("required_count", 1)), 1),
        )
        for row in tracking_rows
    )
    percent = round((total_done / max(total_required, 1)) * 100)
    if percent > 80:
        action = "Maintain"
    elif percent >= 50:
        action = "Reinforce"
    elif percent >= 30:
        action = "Increase supervision"
    else:
        action = "Consider referral"
    return {
        "completion_percent": percent,
        "completed": total_done,
        "total": total_required,
        "action": action,
    }


def weekly_progress_rows(tracking_rows: List[Dict], phase_weeks: int) -> List[Dict]:
    rows: List[Dict] = []
    for week in range(1, max(phase_weeks, 1) + 1):
        bucket = [r for r in tracking_rows if int(r.get("week_number", 1)) == week]
        if not bucket:
            rows.append({
                "week_number": week,
                "completion_percentage": 0,
                "review_notes": "Planned",
            })
            continue
        required = sum(max(int(r.get("required_count", 1)), 1) for r in bucket)
        done = sum(min(int(r.get("completed_count", 0)), max(int(r.get("required_count", 1)), 1)) for r in bucket)
        completion = round((done / max(required, 1)) * 100)
        if completion >= 80:
            note = "Good progress"
        elif completion >= 50:
            note = "Improving"
        else:
            note = "Needs reinforcement"
        rows.append({
            "week_number": week,
            "completion_percentage": completion,
            "review_notes": note,
        })
    return rows


def projection_from_compliance(completion_percent: int) -> str:
    if completion_percent > 80:
        return "High"
    if completion_percent >= 50:
        return "Moderate"
    return "Low"


def determine_next_action(
    improvement: int,
    adherence_percent: int,
    weeks_completed: int,
) -> str:
    adherence = adherence_percent / 100.0
    if adherence < ESCALATION_THRESHOLD:
        return "Intensify_AWW_Caregiver_Coaching"
    if weeks_completed >= MAX_PHASE_WEEKS and improvement < IMPROVEMENT_THRESHOLD:
        return "Refer_To_Specialist"
    if improvement >= IMPROVEMENT_THRESHOLD and adherence >= ADHERENCE_THRESHOLD:
        return "Reduce_Intensity"
    return "Continue_Current_Plan"


def plan_regeneration_summary(
    current_activity_count: int,
    action: str,
    delayed_domains: List[str],
) -> Dict:
    extra_activities = 0
    review_interval_delta_days = 0
    if action == "Intensify_AWW_Caregiver_Coaching":
        extra_activities = max(2, len(delayed_domains) * 2)
        review_interval_delta_days = -7
    elif action == "Refer_To_Specialist":
        extra_activities = 0
        review_interval_delta_days = -15
    updated_count = current_activity_count + extra_activities
    return {
        "current_activity_count": current_activity_count,
        "updated_activity_count": updated_count,
        "extra_activities_added": extra_activities,
        "review_interval_delta_days": review_interval_delta_days,
        "action": action,
    }


def escalation_decision(weekly_rows: List[Dict]) -> str:
    if not weekly_rows:
        return "Continue"
    observed = [r for r in weekly_rows if int(r.get("completion_percentage", 0)) > 0]
    recent = observed[-2:] if len(observed) >= 2 else observed
    if not recent:
        return "Continue"
    avg = sum(int(r.get("completion_percentage", 0)) for r in recent) / len(recent)
    if avg < 40:
        return "Escalate"
    if avg < 60:
        return "Reinforce"
    return "Continue"


def reset_frequency_status(tracking_rows: List[Dict], frequency_type: str) -> int:
    updated = 0
    for row in tracking_rows:
        if row.get("frequency_type") == frequency_type:
            row["status"] = "pending"
            row["completion_date"] = None
            updated += 1
    return updated
