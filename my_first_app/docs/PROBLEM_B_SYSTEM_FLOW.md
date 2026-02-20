# Problem B: Complete System Flow & Implementation Guide

## 1. SYSTEM ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────┐
│                   PROBLEM B FLOW (End-to-End)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  PROBLEM A OUTPUT                                                 │
│  ↓                                                                │
│  ┌─────────────────────────┐                                     │
│  │ Screening Results       │                                     │
│  │ (Delays per domain)     │                                     │
│  │ (Risk Level)            │                                     │
│  └────────────┬────────────┘                                     │
│               │                                                  │
│  PROBLEM B STEP 1: REFERRAL GENERATION                            │
│  ↓                                                                │
│  ┌─────────────────────────┐                                     │
│  │ Create Referral         │                                     │
│  │ (For each domain)       │                                     │
│  │ (Medium/High/Critical)  │                                     │
│  └────────────┬────────────┘                                     │
│               │                                                  │
│  PROBLEM B STEP 2: INTERVENTION PLAN GENERATION                   │
│  ↓                                                                │
│  ┌─────────────────────────┐                                     │
│  │ Create Plan ID          │                                     │
│  │ Set phase: Foundation   │                                     │
│  │ Duration: 8 weeks       │                                     │
│  │ Review: 30 days         │                                     │
│  └────────────┬────────────┘                                     │
│               │                                                  │
│  PROBLEM B STEP 3: ACTIVITY ASSIGNMENT                            │
│  ↓                                                                │
│  ┌──────────────────────────────────┐                            │
│  │ Generate Activities              │                            │
│  │ - Age-appropriate (12-36 months) │                            │
│  │ - Domain-specific                │                            │
│  │ - Severity-matched               │                            │
│  │ - Split: AWW + Caregiver         │                            │
│  └────────────┬─────────────────────┘                            │
│               │                                                  │
│  PROBLEM B STEP 4: WEEKLY TRACKING                                │
│  ↓                                                                │
│  ┌────────────────────────────────────┐                          │
│  │ Weekly Progress Monitoring          │                          │
│  │ - AWW completion %                 │                          │
│  │ - Caregiver completion %           │                          │
│  │ - Combined adherence               │                          │
│  │ - Delay improvement tracking       │                          │
│  └────────────┬─────────────────────────┘                          │
│               │                                                  │
│  PROBLEM B STEP 5: AUTO-ADJUSTMENT LOGIC                          │
│  ↓                                                                │
│  ┌────────────────────────────────────────┐                      │
│  │ Rule Engine Decision:                  │                      │
│  │                                        │                      │
│  │ IF adherence < 40%:                    │                      │
│  │   → Intensify (increase activities)    │                      │
│  │                                        │                      │
│  │ IF weeks >= 8 & improvement < 1 month:│                      │
│  │   → Refer to Specialist                │                      │
│  │                                        │                      │
│  │ IF improvement >= 1 month & adh >= 60%:│                      │
│  │   → Reduce Intensity / Move Phase      │                      │
│  │                                        │                      │
│  │ ELSE:                                  │                      │
│  │   → Continue Current Plan              │                      │
│  └────────────┬─────────────────────────────┘                      │
│               │                                                  │
│  PROBLEM B STEP 6: PHASE TRANSITION (Week 4)                      │
│  ↓                                                                │
│  ┌────────────────────────────────┐                              │
│  │ Foundation Phase Complete      │                              │
│  │ → Move to Skill Expansion      │                              │
│  │ → Enhanced activities for Week 5-8 │                          │
│  └────────────┬─────────────────────┘                              │
│               │                                                  │
│  OUTPUT: Decision & Next Steps                                    │
│  ├─ Continue with current intensity                              │
│  ├─ Intensify intervention                                       │
│  ├─ Reduce intensity                                             │
│  └─ Refer to Specialist + Close Plan                             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. DATA FLOW BY DOMAIN

### Per Domain Example: Fine Motor (FM)

```
Screening Result
├─ FM Delay: 3 months
├─ FM Risk: HIGH
└─ Age: 24 months
           ↓
Create Referral
├─ referral_id: ref_xxxxx_FM
├─ risk_level: high
├─ domain: FM
└─ urgency: Priority
           ↓
Intervention Plan
├─ plan_id: plan_xxxxx_FM
├─ domain: FM
├─ severity: HIGH
├─ phase: Foundation
├─ duration: 8 weeks
├─ review_date: +30 days
└─ target_milestone: Reduce FM delay by 1 month
           ↓
Activities Selection
├─ Age Band: 24-36 months (1 year)
├─ Severity: HIGH
├─ For AWW:
│  ├─ Week 1-2: Basic grip activities (daily)
│  ├─ Week 3-4: Simple threading (5x/week)
│  ├─ Week 5-8: Pattern tracing (5x/week)
└─ For Caregiver:
   ├─ Week 1-2: Play dough (2x/day)
   ├─ Week 3-4: Scissors practice (3x/week)
   ├─ Week 5-8: Craft work (3x/week)
           ↓
Weekly Tracking (Week 1 Example)
├─ AWW Completed: 5/5 activities (100%)
├─ Caregiver Completed: 2/5 activities (40%)
├─ Combined Adherence: (100 + 40) / 2 = 70%
├─ Current FM Delay: 3 months (no change yet)
└─ Status: Continue Current Plan (adherence OK)
           ↓
Week 4 - Phase Transition
├─ Foundation Phase Ends
├─ Move to Skill Expansion
├─ New activities for Week 5-8
└─ Continue same intensity (adherence stable)
           ↓
Week 8 Review (End of Plan)
├─ Improvement: 3 months → 2 months (1 month improvement ✓)
├─ Final Adherence: 75%
├─ Decision: SUCCESS
│  - Improvement >= 1 month ✓
│  - Adherence >= 60% ✓
└─ Action: Reduce intensity OR Close plan
```

---

## 3. CONDITIONS & DECISION THRESHOLDS

### A. Adherence Thresholds
```
Combined Adherence = (AWW % + Caregiver %) / 2

- Excellent: >= 85%  → Continue / Can reduce intensity
- Good:      70-84%  → Continue current plan
- Adequate:  60-69%  → Continue, monitor closely
- Poor:      40-59%  → Consider intensification discussions
- Critical:  < 40%   → INTENSIFY immediately
```

### B. Improvement Thresholds
```
Improvement = Baseline Delay - Current Delay

- No Improvement:        < 0.5 months
- Minimal Improvement:   0.5-0.9 months
- Adequate Improvement:  1-1.5 months ✓ (TARGET)
- Excellent Improvement: > 1.5 months
```

### C. Time-Based Rules
```
Week 4:  Phase transition (Foundation → Skill Expansion)
Week 8:  Plan review
         - If improvement >= 1 month: SUCCESS
         - If improvement <  1 month: ESCALATE to referral
         - If adherence <  40%: INTENSIFY before escalation
```

### D. Decision Tree
```
EVERY WEEK CHECK:

┌─ Is adherence < 40%?
│  └─ YES: INTENSIFY (add more activities/frequency)
│  └─ NO: continue to next check
│
├─ Is it Week 4?
│  └─ YES: Move phase to "Skill Expansion"
│  └─ NO: continue to next check
│
├─ Is it Week 8?
│  └─ YES: Final review
│     ├─ If improvement >= 1 month: Close (SUCCESS)
│     └─ If improvement < 1 month: Refer (ESCALATE)
│  └─ NO: continue to next check
│
└─ Week 1-3, 5-7: Continue Current Plan
```

---

## 4. DATABASE SCHEMA STRUCTURE

```
child_profile
├─ child_id (PRIMARY KEY)
├─ name
├─ dob
├─ age_months
├─ gender
├─ awc_code
└─ location info

developmental_risk
├─ risk_id
├─ child_id (FOREIGN KEY)
├─ gm_delay_months
├─ fm_delay_months
├─ lc_delay_months
├─ cog_delay_months
├─ se_delay_months
├─ num_delays
├─ risk_score
├─ risk_category
└─ assessment_date

intervention_plan
├─ plan_id (PRIMARY KEY)
├─ child_id (FOREIGN KEY)
├─ domain (GM/FM/LC/COG/SE)
├─ severity (LOW/MEDIUM/HIGH/CRITICAL)
├─ phase_duration_weeks (8)
├─ phase_start_date
├─ phase_end_date
├─ review_interval_days (30)
├─ target_milestone
├─ intensity_level
├─ active_status
└─ current_phase (Foundation/Skill Expansion)

intervention_activities
├─ activity_id
├─ plan_id (FOREIGN KEY)
├─ domain
├─ age_band
├─ severity
├─ stakeholder (AWW/Caregiver)
├─ activity_type
├─ title
├─ description
├─ required_per_week
└─ frequency

weekly_progress
├─ progress_id
├─ plan_id (FOREIGN KEY)
├─ week_number
├─ aww_completion_count
├─ aww_completion_percentage
├─ caregiver_completion_count
├─ caregiver_completion_percentage
├─ combined_adherence
├─ current_delay_months (per domain)
├─ improvement
├─ decision
├─ decision_reason
└─ review_notes

referral_action
├─ referral_id (PRIMARY KEY)
├─ child_id (FOREIGN KEY)
├─ domain
├─ risk_level
├─ referral_date
├─ urgency
├─ referral_status
└─ completion_date
```

---

## 5. API ENDPOINTS (Backend)

### Referral Creation
```
POST /referral/create
{
  "child_id": "child_1",
  "domain": "FM",
  "risk_level": "high",
  "age_months": 24,
  "delay_months": 3
}
Response:
{
  "referral_id": "ref_12345_FM",
  "status": "Pending"
}
```

### Create Intervention Plan
```
POST /intervention/plan/create
{
  "child_id": "child_1",
  "domain": "FM",
  "risk_level": "high",
  "baseline_delay_months": 3,
  "age_months": 24
}
Response:
{
  "plan_id": "plan_12345_FM",
  "phase": "Foundation",
  "start_date": "2026-02-19",
  "end_date": "2026-04-16",
  "activities": [...]
}
```

### Log Weekly Progress
```
POST /intervention/progress/log
{
  "plan_id": "plan_12345_FM",
  "week_number": 1,
  "aww_completed": 5,
  "aww_total": 5,
  "caregiver_completed": 2,
  "caregiver_total": 5,
  "current_delay_months": 3
}
Response:
{
  "adherence": 0.70,
  "improvement": 0,
  "decision": "Continue",
  "reason": "Adherence acceptable, continue current plan"
}
```

### Get Decision & Next Steps
```
GET /intervention/plan/{plan_id}/decision
Response:
{
  "week": 1,
  "decision": "Continue",
  "action": "Continue_Current_Plan",
  "next_review": "2026-02-26"
}
```

---

## 6. WEEKLY WORKFLOW

### Week 1-3: Foundation Phase (Early Activities)
```
Monday-Friday:
  AWW:
  ├─ 10 min: Basic fine motor activity (daily)
  └─ Log completion each day
  
  Caregiver:
  ├─ 10 min: Play dough activity (daily)
  └─ Log completion each day

Friday Evening:
  Weekly Review:
  ├─ Calculate adherence
  ├─ Get system decision
  └─ Adjust plan if needed
```

### Week 4: Phase Transition
```
Monday:
  System automatically:
  ├─ Completes Foundation Phase
  ├─ Moves to "Skill Expansion"
  ├─ Generates new activities for Week 5-8
  └─ Sends notification to AWW/Caregiver

Activities now include:
  - Pattern tracing (complexity increase)
  - Threading with beads (progression)
  - Craft activities (application)
```

### Week 5-8: Skill Expansion Phase
```
Monday-Friday:
  AWW:
  ├─ 15 min: Advanced activity (daily)
  └─ Log completion
  
  Caregiver:
  ├─ 10 min: Practice activity (3x/week)
  └─ Log completion

Friday:
  Review & check improvement
  └─ If improvement seen → SUCCESS path
```

### Week 8: Final Review & Decision
```
Final Assessment:
├─ Total Adherence over 8 weeks
├─ Total Improvement in delay
├─ Compare: improvement vs threshold (1 month)
└─ Decision:
   ├─ SUCCESS: Reduce intensity or Close plan
   ├─ PARTIAL: Continue with modified plan
   └─ FAILURE: Refer to Specialist

Generate Report:
├─ Weekly progress chart
├─ Cumulative improvement
├─ Adherence breakdown (AWW vs Caregiver)
└─ Next steps
```

---

## 7. AUTO-ADJUSTMENT ALGORITHM (Python Logic)

```python
def evaluate_week_progress(plan_id, week_data):
    """
    Evaluates weekly progress and applies auto-adjustment logic
    """
    # 1. Calculate adherence
    aww_adherence = week_data['aww_completed'] / week_data['aww_total']
    caregiver_adherence = week_data['caregiver_completed'] / week_data['caregiver_total']
    combined_adherence = (aww_adherence + caregiver_adherence) / 2
    
    # 2. Calculate improvement
    baseline_delay = get_baseline_delay(plan_id)
    current_delay = week_data['current_delay_months']
    improvement = baseline_delay - current_delay
    
    # 3. Get week number
    week_num = week_data['week_number']
    
    # 4. Apply decision rules
    IMPROVEMENT_THRESHOLD = 1  # months
    ADHERENCE_THRESHOLD = 0.6  # 60%
    ESCALATION_THRESHOLD = 0.4  # 40%
    MAX_PHASE_WEEKS = 8
    
    # Rule 1: Critical adherence issue
    if combined_adherence < ESCALATION_THRESHOLD:
        action = "Intensify_AWW_Caregiver_Coaching"
        reason = f"Adherence {combined_adherence*100:.1f}% below critical threshold"
    
    # Rule 2: Week 4 - Phase transition
    elif week_num == 4:
        action = "Move_to_Skill_Expansion"
        reason = "Foundation phase complete, transitioning to skill expansion"
    
    # Rule 3: Week 8 - Final review
    elif week_num == MAX_PHASE_WEEKS:
        if improvement >= IMPROVEMENT_THRESHOLD and combined_adherence >= ADHERENCE_THRESHOLD:
            action = "Close_Plan_Success"
            reason = f"Improvement {improvement:.1f}mo >= threshold, adherence {combined_adherence*100:.1f}%"
        elif improvement < IMPROVEMENT_THRESHOLD:
            action = "Refer_To_Specialist"
            reason = f"Improvement {improvement:.1f}mo < threshold after 8 weeks"
        else:
            action = "Extend_Plan"
            reason = "Continue with monitoring"
    
    # Rule 4: Weeks 1-3, 5-7 - Routine check
    else:
        if improvement >= IMPROVEMENT_THRESHOLD and combined_adherence >= ADHERENCE_THRESHOLD:
            action = "Can_Reduce_Intensity"
            reason = "Progress on track, consider reducing intensity"
        else:
            action = "Continue_Current_Plan"
            reason = "Monitor progress, maintain current intensity"
    
    # 5. Store decision
    store_decision({
        'plan_id': plan_id,
        'week': week_num,
        'adherence': combined_adherence,
        'improvement': improvement,
        'action': action,
        'reason': reason,
        'timestamp': datetime.now()
    })
    
    # 6. Apply action if needed
    if action == "Intensify_AWW_Caregiver_Coaching":
        intensify_plan(plan_id)
    elif action == "Move_to_Skill_Expansion":
        update_phase(plan_id, "Skill Expansion")
        generate_new_activities(plan_id, phase="Skill Expansion")
    
    return {
        'action': action,
        'reason': reason,
        'next_review': datetime.now() + timedelta(days=7)
    }
```

---

## 8. IMPLEMENTATION CHECKLIST

### Phase 1: Backend Setup ✓
- [x] Database schema created
- [x] API endpoints designed
- [ ] Python service implementation
- [ ] Auto-adjustment logic implementation

### Phase 2: Frontend Integration ✓
- [x] Referral screen built
- [x] Referral batch summary built
- [ ] Intervention plan dashboard
- [ ] Weekly progress input screen
- [ ] Decision display screen

### Phase 3: Business Logic
- [ ] Weekly progress tracking
- [ ] Auto-adjustment triggers
- [ ] Phase transitions
- [ ] Notification system

### Phase 4: Testing & Deployment
- [ ] Unit tests
- [ ] Integration tests
- [ ] End-to-end testing
- [ ] Production deployment

---

## 9. KEY FILES TO IMPLEMENT

```
Backend:
├─ backend/app/problem_b_service.py (MAIN LOGIC)
├─ backend/app/model_service.py (Activity generation)
├─ backend/app/problem_b_schema.sql (DB schema - ready)
└─ backend/app/main.py (API endpoints to add)

Frontend:
├─ lib/screens/intervention_plan_screen.dart (NEW)
├─ lib/screens/weekly_progress_screen.dart (NEW)
├─ lib/screens/intervention_dashboard.dart (NEW)
└─ lib/models/intervention_model.dart (NEW)
```

---

## 10. NEXT STEPS

1. **Today**: Implement Python backend service
2. **Tomorrow**: Create frontend screens
3. **Day 3**: Integrate & test
4. **Day 4**: Deploy & monitor
