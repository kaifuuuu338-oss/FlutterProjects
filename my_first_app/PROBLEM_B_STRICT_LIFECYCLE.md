# Problem B Implementation: Strict Intervention Lifecycle

## Overview
This document describes the complete Problem B implementation following the **strict 7-phase intervention lifecycle** architecture as specified.

## Architecture: 7-Phase Lifecycle

```
Risk Assessment 
        ↓
[PHASE 1] Create Intervention Phase
        ↓
[PHASE 2] Auto-Generate Activities (by domain/severity/age)
        ↓
[PHASE 3] Track Compliance Weekly (completed tasks / total tasks * 100)
        ↓
[PHASE 4] Calculate Improvement (baseline_delay - current_delay)
        ↓
[PHASE 5] Review Engine (automatic decision at 42-day interval, using 2-cycle logic)
        ↓
[PHASE 6] Auto-Intensify Plan (increase frequency if compliance < 40%)
        ↓
[PHASE 7] Auto-Create Referral (CONDITIONAL - only on escalation trigger)
```

## Fixed Thresholds (Non-Negotiable)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| ADHERENCE_THRESHOLD | 60% | Minimum compliance for "sufficient progress" |
| ESCALATION_THRESHOLD | 40% | Below this = INTENSIFY |
| REVIEW_INTERVAL_DAYS | 42 (6 weeks) | How often reviews happen automatically |
| IMPROVEMENT_THRESHOLD | 1.0 month | Minimum delay reduction considered improvement |

## Decision Engine Logic

The review engine implements **strict 2-cycle decision logic**:

### Rule 1: Low Adherence
```
If compliance < 40% → INTENSIFY
Action: Auto-increase activity frequency by 1/week
```

### Rule 2: No Improvement After Consecutive Reviews
```
If improvement ≤ 0 AND review_count ≥ 2 → ESCALATE
Action: Auto-create referral with IMMEDIATE urgency
```

### Rule 3: Worsening Trend
```
If improvement < 0 → ESCALATE
Action: Auto-create referral for specialist intervention
```

### Rule 4: Default
```
Else → CONTINUE
Action: Keep current plan, schedule next review
```

## Database Schema (5 Core Tables)

### Table 1: intervention_phase
```sql
CREATE TABLE intervention_phase (
    phase_id TEXT PRIMARY KEY,
    child_id TEXT NOT NULL,
    domain TEXT,              -- FM, GM, LC, COG, SE
    severity TEXT,            -- LOW, MEDIUM, HIGH, CRITICAL
    baseline_delay REAL,      -- Delay in months at start
    start_date TEXT,          -- ISO format
    review_date TEXT,         -- Next scheduled review
    status TEXT,              -- ACTIVE, COMPLETED, ESCALATED
    created_at TEXT
);
```

### Table 2: activities
```sql
CREATE TABLE activities (
    activity_id TEXT PRIMARY KEY,
    phase_id TEXT,
    domain TEXT,
    role TEXT,                -- AWW or Caregiver
    name TEXT,                -- Activity description
    frequency_per_week INTEGER,
    created_at TEXT
);
```

### Table 3: task_logs
```sql
CREATE TABLE task_logs (
    task_id TEXT PRIMARY KEY,
    activity_id TEXT,
    date_logged TEXT,
    completed INTEGER,        -- 0 or 1
    created_at TEXT
);
```

### Table 4: review_log
```sql
CREATE TABLE review_log (
    review_id TEXT PRIMARY KEY,
    phase_id TEXT,
    review_date TEXT,
    compliance REAL,          -- 0-100
    improvement REAL,         -- baseline - current
    decision_action TEXT,     -- CONTINUE, INTENSIFY, ESCALATE
    decision_reason TEXT,
    created_at TEXT
);
```

### Table 5: referral
```sql
CREATE TABLE referral (
    referral_id TEXT PRIMARY KEY,
    child_id TEXT,
    domain TEXT,
    urgency TEXT,             -- LOW, MEDIUM, HIGH, IMMEDIATE
    status TEXT,              -- PENDING, SPECIALIST_IDENTIFIED, REFERRED, COMPLETED
    created_on TEXT,
    created_at TEXT
);
```

## Backend Service: problem_b_service.py

### Key Methods

#### 1. create_intervention_phase()
**Entry point for the lifecycle**
- Triggered: When referral marked for intervention
- Does: 
  - Creates phase record
  - Auto-generates activities based on domain/severity/age
  - Sets first review date (42 days out)
- Returns: phase_id and activity count

#### 2. _generate_activities_auto() [AUTOMATIC]
**Templates-based activity generation**
- Runs: Automatically when phase created (NOT manual)
- Inputs: domain, severity, age_band
- Output: Activities with role (AWW/Caregiver) and frequency

**Activity Templates** (by domain):
- FM (Fine Motor): Grip strengthening, Play dough manipulation
- GM (Gross Motor): Core strength, Walking/climbing
- LC (Language): Vocabulary, Story/rhyme practice
- COG (Cognitive): Object recognition, Problem solving
- SE (Social-Emotional): Emotion recognition, Bonding activities

**Frequency Rules**:
- CRITICAL: AWW=5x/week, Caregiver=5x/week
- HIGH: AWW=5x/week, Caregiver=4x/week
- MEDIUM/LOW: AWW=3x/week, Caregiver=3x/week

#### 3. calculate_compliance() [AUTOMATIC]
**Weekly compliance calculation**
- Called: Every week or on-demand
- Formula: `(completed_tasks / total_tasks) * 100`
- Returns: Decimal (0.75 = 75%)

#### 4. calculate_improvement() [AUTOMATIC]
**Delay reduction measurement**
- Called: At review time
- Formula: `baseline_delay - current_delay`
- Returns: Improvement in months (positive = good, negative = worse)

#### 5. run_review_engine() [AUTOMATIC]
**Core decision logic - called every 42 days**
- Calculates: compliance, improvement, review history
- Applies: Decision rules (2-cycle logic)
- Actions: 
  - CONTINUE → next review in 42 days
  - INTENSIFY → calls _intensify_plan(), next review in 42 days
  - ESCALATE → calls _create_referral(), sets phase status to ESCALATED
- Returns: decision object with reason

#### 6. _intensify_plan() [AUTOMATIC]
**Auto-increase activity frequency**
- Triggered: By review engine when compliance < 40%
- Does: frequency_per_week += 1 for all activities
- Goal: Increase compliance through more frequent intervention

#### 7. _create_referral() [AUTOMATIC]
**Conditional referral creation**
- Triggered: ONLY by review engine on escalation
- Does: Creates referral record with IMMEDIATE urgency
- Updates: Phase status → ESCALATED
- **Critical**: Referral is NOT always visible; only created on escalation

## API Endpoints

### 1. POST /intervention/plan/create
**Create new intervention phase**
```json
{
  "child_id": "C123",
  "domain": "FM",
  "risk_level": "HIGH",
  "baseline_delay_months": 4,
  "age_months": 24
}
```
Returns: `{ phase_id, status, activities_generated, review_date }`

### 2. POST /intervention/{phase_id}/progress/log
**Log compliance and trigger review if needed**
```json
{
  "phase_id": "phase_abc123",
  "current_delay_months": 3.2,
  "notes": "Showed improvement in grip"
}
```
Returns: `{ compliance, review_decision }`

### 3. GET /intervention/{phase_id}/status
**Get current phase status with metrics**
Returns: `{ phase_id, compliance, latest_review, activities_count, status }`

### 4. POST /intervention/{phase_id}/review
**Manually trigger review engine**
```json
{
  "current_delay_months": 3.2,
  "notes": ""
}
```
Returns: `{ review_id, compliance, improvement, decision, reason }`

### 5. POST /intervention/{phase_id}/complete
**Mark phase as completed**
```json
{
  "closure_status": "success",
  "final_notes": ""
}
```
Returns: `{ phase_id, status: COMPLETED }`

## Flutter Integration

### Riverpod Providers (in `lib/providers/intervention_provider.dart`)

**Services**:
- `interventionServiceProvider` - REST client for backend
- `dioProvider` - HTTP client

**State**:
- `activePhaseProvider` - Currently active phase
- `phaseStatusProvider` - Real-time phase status
- `reviewDecisionProvider` - Latest review decision

**Models**:
- `InterventionPhase` - Phase data with status
- `ReviewDecision` - Review engine result

### UI Components

#### intervention_plan_dashboard.dart
**Displays**:
- Current phase status
- Compliance percentage
- Latest review decision
- "Log Weekly Progress" button

**Functionality**:
- Shows ONLY what user needs to see
- Hides escalation/referral details from normal view
- Loads phase status on demand

#### weekly_progress_screen.dart
**Displays**:
- Current delay input field
- Progress notes
- Submit button

**Functionality**:
- Takes current delay measurements
- Sends to /intervention/{phase_id}/progress/log
- Shows compliance result
- Triggers review if at review date

## What's Automatic vs Manual

### Automatic (Backend-Driven)
✅ Activity generation (triggered on phase creation)
✅ Compliance calculation (weekly)
✅ Review decision logic (every 42 days)
✅ Plan intensification (auto on low adherence)
✅ Referral creation (auto on escalation)
✅ Phase status updates

### Manual (User/AWW-Driven)
- Mark activities as completed (AWW or Caregiver)
- Enter current delay at review time (AWW or Caregiver)
- View dashboard (AWW or Caregiver)
- Request referral if escalated (Specialist coordinator)

## Integration with Problem A

**NO CHANGES to Problem A**:
- Risk screening screens untouched
- Referral generation from risk untouched
- Existing database tables untouched
- Problem A workflow completely independent

**Connection**:
- When referral marked for intervention → calls POST /intervention/plan/create
- Creates Phase in Problem B system
- Problem B lifecycle runs independently

## Lifecycle Flow Example

```
Child: Ravi, Age 24 months, GM delay = 4 months

1. Risk Assessment → HIGH severity GM delay
2. Generate Referral (Problem A)
3. Mark referral for intervention → Call /intervention/plan/create
   ├─ Phase created: phase_xyz123
   ├─ Activities auto-generated: 4 activities (2 AWW, 2 Caregiver)
   └─ Review scheduled: 42 days later

4. Week 1-6: AWW/Caregiver log completed activities
   ├─ Compliance tracked daily
   └─ Logs stored in task_logs table

5. Day 42: Review Engine Triggers (automatic)
   ├─ Compliance calculated: 65% (sufficient)
   ├─ Improvement: Child now 2.5 mo delay (was 4) → +1.5 mo improvement
   ├─ Decision: CONTINUE (good progress)
   └─ Next review: Day 84

6. Day 84: Review Engine Triggers again
   ├─ Compliance: 35% (poor)
   ├─ Improvement: Only 0.1 mo more (stalled)
   ├─ Decision: INTENSIFY (low compliance)
   ├─ Action: Increase frequency (AWW: 5→6x/week)
   └─ Next review: Day 126

7. Day 126: Review Engine Triggers third time
   ├─ Compliance: 30% (still poor, no improvement)
   ├─ Improvement: Negative (-0.2) → worsening
   ├─ Decision: ESCALATE (failed 2 reviews + worsening)
   ├─ Action: Auto-create referral to specialist
   ├─ Phase status: ESCALATED
   └─ Next: Specialist coordinator reviews referral
```

## Testing Checklist

- [ ] Phase creates successfully
- [ ] Activities auto-generate with correct template
- [ ] Compliance calculated correctly
- [ ] Review engine runs on 42-day interval
- [ ] INTENSIFY decision triggers on compliance < 40%
- [ ] ESCALATE decision triggers after failed reviews
- [ ] Referral creates ONLY on escalation
- [ ] Phase status updates correctly
- [ ] Problem A untouched

## Key Files

- `backend/app/problem_b_service.py` - Core lifecycle engine
- `backend/app/problem_b_schema.sql` - Database schema
- `backend/app/main.py` - API endpoints
- `lib/providers/intervention_provider.dart` - Flutter state management
- `lib/screens/intervention_plan_dashboard.dart` - Main UI
- `lib/screens/weekly_progress_screen.dart` - Progress logging
