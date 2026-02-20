# Problem B: Step-by-Step Implementation Guide

## STEP 1: Understand the Complete Flow (YOU ARE HERE)

**What you have:**
- ✅ Referral generation (already built & working)
- ✅ Referral batch summary screen
- ⚠️  Manual intervention plan creation

**What you need:**
- 🔄 Automated intervention plan generation
- 📊 Weekly progress tracking
- 🤖 Auto-adjustment decision logic
- 🎯 Phase transition automation
- 📱 Frontend screens for all above

---

## STEP 2: Backend - Problem B Service Implementation

### File: `backend/app/problem_b_service.py`

This is the CORE of Problem B. It handles:
1. Intervention plan creation from referral
2. Activity selection based on domain/severity/age
3. Weekly progress evaluation
4. Auto-adjustment decisions

**Implementation priority:**
```
PHASE 1 (This week):
├─ 1. Create plan from referral
├─ 2. Select activities based on criteria
└─ 3. Store plan in DB

PHASE 2 (Next week):
├─ 1. Log weekly progress
├─ 2. Calculate adherence
└─ 3. Evaluate improvement

PHASE 3 (Week 3):
├─ 1. Auto-adjustment decision logic
├─ 2. Phase transitions (Week 4)
└─ 3. Final review (Week 8)
```

### Pseudocode Template

```python
# backend/app/problem_b_service.py

class ProblemBService:
    """
    Core service for intervention plan generation and management
    """
    
    def __init__(self):
        self.db_path = "problem_b.db"
    
    # ════════════════════════════════════════════════════════════════
    # PHASE 1: Plan Creation
    # ════════════════════════════════════════════════════════════════
    
    def create_intervention_plan(self, referral_data):
        """
        Input: Referral data (domain, risk_level, child_id, age_months, delay_months)
        Output: Plan with activities assigned
        
        Steps:
        1. Generate plan_id
        2. Set plan parameters (duration, phase, review_date)
        3. Generate activities based on domain/age/severity
        4. Save to DB
        5. Return plan details
        """
        pass
    
    def generate_activities(self, domain, severity, age_months):
        """
        Input: domain (FM/GM/etc), severity (LOW/MED/HIGH/CRIT), age_months
        Output: List of activities for AWW and Caregiver
        
        Logic:
        - Get age_band from age_months (12-24, 24-36, 36+)
        - Query activity_master for matching domain, severity, age_band
        - Split into:
          * AWW activities (daily_core type)
          * Caregiver activities (weekly_target type)
        - Return structured activity list
        """
        pass
    
    # ════════════════════════════════════════════════════════════════
    # PHASE 2: Weekly Progress Tracking
    # ════════════════════════════════════════════════════════════════
    
    def log_weekly_progress(self, plan_id, week_data):
        """
        Input: plan_id, week_data (aww_completed, caregiver_completed, current_delay, notes)
        Output: Weekly progress record + decision
        
        Steps:
        1. Validate inputs
        2. Calculate adherence: (aww_completed / total) + (caregiver_completed / total) / 2
        3. Calculate improvement: baseline_delay - current_delay
        4. Get decision by calling evaluate_progress()
        5. Store in weekly_progress table
        6. Apply any auto-adjustments
        7. Return response with decision
        """
        pass
    
    def evaluate_progress(self, plan_id, adherence, improvement, week_num):
        """
        Input: adherence (0-1), improvement (months), week_num (1-8)
        Output: decision object {action, reason, next_steps}
        
        Decision Logic (PSEUDOCODE):
        
        IF adherence < 0.4:
            → Action: "Intensify_Activities"
            → Reason: "Adherence below critical threshold"
            → Next: Add more activities, extend plan
        
        ELIF week_num == 4:
            → Action: "Move_to_Skill_Expansion"
            → Reason: "Foundation phase complete"
            → Next: Generate new activities, increase complexity
        
        ELIF week_num == 8:
            IF improvement >= 1 AND adherence >= 0.6:
                → Action: "Close_Plan_Success"
                → Reason: "Target improvement achieved with good adherence"
                → Next: Close plan, generate report
            ELIF improvement < 1:
                → Action: "Refer_To_Specialist"
                → Reason: "No adequate improvement after 8 weeks"
                → Next: Create referral to specialist, close plan
            ELSE:
                → Action: "Extend_Plan"
                → Reason: "Continue monitoring"
                → Next: Extend for another 4 weeks
        
        ELSE (weeks 1-3, 5-7):
            IF improvement >= 1 AND adherence >= 0.6:
                → Action: "Can_Reduce_Intensity"
                → Reason: "Progress on track"
                → Next: Optional intensity reduction
            ELSE:
                → Action: "Continue_Current_Plan"
                → Reason: "Monitor progress"
                → Next: Continue next week
        """
        pass
    
    # ════════════════════════════════════════════════════════════════
    # PHASE 3: Auto-Adjustment & Phase Transitions
    # ════════════════════════════════════════════════════════════════
    
    def intensify_plan(self, plan_id):
        """
        Input: plan_id
        Task: Add more activities, increase frequency
        
        Steps:
        1. Get current plan
        2. Get activities for higher difficulty/frequency
        3. Update plan intensity_level
        4. Add new activities to intervention_activities
        5. Extend plan_end_date by 2 weeks
        6. Log action to decision_log
        """
        pass
    
    def transition_phase(self, plan_id, new_phase):
        """
        Input: plan_id, new_phase ("Skill Expansion")
        Task: Auto-transition at Week 4
        
        Steps:
        1. Update plan 'current_phase'
        2. Get current domain/severity
        3. Generate new activities for new_phase
        4. Replace old activities with new ones
        5. Maintain same frequency initially
        6. Log transition
        """
        pass
    
    def close_plan(self, plan_id, reason):
        """
        Input: plan_id, reason (success/referral/other)
        Task: Close intervention plan
        
        Steps:
        1. Update plan status to 'inactive'
        2. Set plan_end_date to today
        3. Generate final report
        4. Log decision
        5. Send notification
        """
        pass

# ════════════════════════════════════════════════════════════════
# DATABASE HELPER FUNCTIONS
# ════════════════════════════════════════════════════════════════

def get_baseline_delay(plan_id):
    """Get the baseline delay for a plan"""
    pass

def get_activity_master(domain, severity, age_band, stakeholder):
    """Query activity_master for matching activities"""
    pass

def save_weekly_record(plan_id, week_data):
    """Save weekly progress to DB"""
    pass

def save_decision(plan_id, week, decision):
    """Save decision to decision_log"""
    pass
```

---

## STEP 3: API Endpoints to Add

### File: `backend/app/main.py`

Add these endpoints:

```python
# ════════════════════════════════════════════════════════════════
# NEW ENDPOINTS FOR PROBLEM B
# ════════════════════════════════════════════════════════════════

@app.post("/intervention/plan/create")
def create_intervention_plan(payload: InterventionPlanRequest) -> InterventionPlanResponse:
    """
    Create intervention plan from referral
    
    Input:
    {
      "child_id": "child_123",
      "referral_id": "ref_123_FM",
      "domain": "FM",
      "risk_level": "high",
      "baseline_delay_months": 3,
      "age_months": 24
    }
    
    Output:
    {
      "plan_id": "plan_123_FM",
      "status": "active",
      "phase": "Foundation",
      "start_date": "2026-02-19",
      "end_date": "2026-04-16",
      "activities": [
        {"provider": "AWW", "week": 1, "activity": "..."},
        {"provider": "Caregiver", "week": 1, "activity": "..."}
      ]
    }
    """
    pass

@app.post("/intervention/{plan_id}/progress/log")
def log_weekly_progress(plan_id: str, payload: WeeklyProgressRequest) -> WeeklyProgressResponse:
    """
    Log weekly progress and get decision
    
    Input:
    {
      "week_number": 1,
      "aww_completed": 5,
      "aww_total": 5,
      "caregiver_completed": 3,
      "caregiver_total": 5,
      "current_delay_months": 3,
      "notes": "Good progress, child engaged"
    }
    
    Output:
    {
      "week": 1,
      "adherence": 0.80,
      "improvement": 0.0,
      "decision": "Continue_Current_Plan",
      "reason": "Adherence good, continue monitoring",
      "next_review": "2026-02-26"
    }
    """
    pass

@app.get("/intervention/{plan_id}/decision")
def get_plan_decision(plan_id: str) -> PlanDecisionResponse:
    """
    Get latest decision for a plan
    
    Returns:
    {
      "week": 1,
      "decision": "Continue_Current_Plan",
      "reason": "...",
      "next_action": "Monitor progress"
    }
    """
    pass

@app.get("/intervention/{plan_id}/progress")
def get_plan_progress(plan_id: str) -> PlanProgressResponse:
    """
    Get full progress history for a plan
    
    Returns: List of all weekly progress records
    """
    pass

@app.post("/intervention/{plan_id}/close")
def close_intervention_plan(plan_id: str, reason: str) -> CloseResponse:
    """
    Close an intervention plan
    
    Reason options: "success", "referral", "admin"
    """
    pass
```

---

## STEP 4: Frontend - Screens to Build

### Screen 1: Intervention Plan Dashboard
```
File: lib/screens/intervention_plan_dashboard.dart

Shows:
├─ Child info
├─ Current plan (domain, phase, progress %)
├─ This week's activities
│  ├─ AWW activities (with checkboxes)
│  └─ Caregiver activities (with checkboxes)
├─ Progress graph (delay vs time)
├─ Latest decision
└─ Next review date

User actions:
├─ Check off completed activities
├─ Log notes
└─ View detailed progress
```

### Screen 2: Weekly Progress Entry
```
File: lib/screens/weekly_progress_screen.dart

Shows:
├─ Week number (e.g., "Week 3 of 8")
├─ Form:
│  ├─ AWW: How many activities completed? (0-5)
│  ├─ Caregiver: How many activities completed? (0-5)
│  ├─ Current delay in months? (numeric input)
│  └─ Notes (text area)
├─ Calculate button
└─ Shows:
   ├─ Adherence %
   ├─ Improvement
   └─ Decision with recommendation

Result:
└─ "Week 3: Adherence 80%, Decision: Continue Current Plan"
```

### Screen 3: Intervention History
```
File: lib/screens/intervention_history_screen.dart

Shows:
├─ List of all plans for child
│  ├─ Plan 1: FM - Foundation (Week 1-3) → Success ✓
│  ├─ Plan 2: GM - Foundation (Week 1-5) → In Progress
│  └─ Plan 3: LC - Foundation (Week 1-8) → Referred
├─ Click to view details
└─ Reports per plan
```

---

## STEP 5: Database Setup

### Already Created: `backend/app/problem_b_schema.sql`

Just need to run:
```sql
-- Execute in your database
sqlite3 problem_b.db < backend/app/problem_b_schema.sql

-- Verify tables created
.tables
```

---

## STEP 6: Testing Checklist

### Unit Tests
```python
# backend/tests/test_problem_b_service.py

def test_create_intervention_plan():
    # Test plan creation from referral
    pass

def test_generate_activities():
    # Test activity selection algorithm
    pass

def test_calculate_adherence():
    # Test adherence calculation
    pass

def test_evaluate_progress_continue():
    # Test decision: Continue_Current_Plan
    pass

def test_evaluate_progress_intensify():
    # Test decision: Intensify_Activities
    pass

def test_evaluate_progress_referral():
    # Test decision: Refer_To_Specialist
    pass

def test_phase_transition_week_4():
    # Test auto-transition at Week 4
    pass
```

### Integration Tests
```
1. Referral → Plan creation → Activities assigned
2. Weekly logging → Decision generated → Plan updated
3. Week 4 → Phase transition → New activities generated
4. Week 8 → Final review → Plan closed + status updated
5. Low adherence → Intensification → Plan extended
```

---

## STEP 7: Deployment Order

### Day 1: Backend Foundation
```
1. Create problem_b_service.py with all methods (stub implementation)
2. Add API endpoints to main.py
3. Test endpoints with Postman
```

### Day 2: Backend Logic
```
1. Implement plan creation logic
2. Implement activity selection
3. Implement weekly progress evaluation
4. Implement auto-adjustment logic
```

### Day 3: Frontend Screens
```
1. Build intervention plan dashboard
2. Build weekly progress entry screen
3. Build intervention history screen
4. Wire up to backend APIs
```

### Day 4: Integration & Testing
```
1. Test end-to-end flow
2. Test auto-adjustments
3. Test phase transitions
4. Generate sample data
```

---

## STEP 8: Key Implementation Notes

### Thresholds (FIXED - Don't Change)
```
IMPROVEMENT_THRESHOLD = 1  # month
ADHERENCE_THRESHOLD = 0.6  # 60%
ESCALATION_THRESHOLD = 0.4  # 40%
MAX_PHASE_WEEKS = 8
```

### Activities Strategy
```
Foundation Phase (Week 1-4):
├─ Basic skills
├─ Daily frequency
└─ Simple activities

Skill Expansion (Week 5-8):
├─ Advanced skills
├─ Varied activities
└─ Application-based
```

### Decision Frequency
```
Weekly: End of each week (Friday)
Phase Transition: Automatically at Week 4
Final Review: Automatically at Week 8
```

---

## STEP 9: Example Scenario (End-to-End)

### Scenario: Fine Motor Intervention for 24-month-old

```
Day 1:
├─ Screening shows: FM delay 3 months, Risk HIGH
├─ Create referral_FM
└─ → System automatically creates plan_FM

Week 1:
├─ AWW completes: 5/5 activities (100%)
├─ Caregiver completes: 3/5 activities (60%)
├─ Adherence: 80%
├─ Current FM delay: 3 months (no change)
└─ Decision: "Continue Current Plan"

Week 2-3:
├─ Same monitoring
├─ Adherence remains ~75%
└─ Still 3 month delay

Week 4:
├─ System auto-detects Week 4
├─ Transitions to "Skill Expansion"
├─ Generates new activities (more complex)
└─ Notifies AWW & Caregiver

Week 5-7:
├─ Continue with new activities
├─ Week 7 shows: FM delay now 2 months ✓ (1 month improvement)
└─ Adherence: 70%

Week 8 (Final Review):
├─ Final delay: 2 months
├─ Improvement: 1 month ✓ (MEETS THRESHOLD)
├─ Adherence: 75% ✓ (MEETS THRESHOLD)
├─ Decision: "SUCCESS - Close Plan"
└─ Action: Plan closed, report generated, new activities: NOT NEEDED

Result: ✅ SUCCESSFUL INTERVENTION
└─ Child reduced FM delay by 1 month through structured activities
```

---

## STEP 10: Current Status Summary

```
✅ COMPLETED:
├─ Referral generation (Problem A → B transition)
├─ Referral batch summary screen
└─ Database schema design

🔄 IN PROGRESS:
├─ Backend service implementation
└─ Auto-adjustment logic

📋 TODO:
├─ Weekly progress tracking UI
├─ Plan decision display
├─ Phase transition automation
├─ Integration testing
└─ Production deployment
```

---

## Next Immediate Actions

1. **TODAY**: Implement `problem_b_service.py` with all method stubs
2. **TOMORROW**: Fill in the logic for plan creation & activity selection
3. **DAY 3**: Build frontend screens
4. **DAY 4**: Test full flow
5. **DAY 5**: Deploy

**Let me help you implement the first file: problem_b_service.py**

Would you like me to:
- [ ] Generate the complete `problem_b_service.py` now?
- [ ] Create the Flutter screens next?
- [ ] Set up the API endpoints first?

**Choose and I'll code it completely!** 🚀
