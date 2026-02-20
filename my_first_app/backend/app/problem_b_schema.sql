-- Problem B Database Schema: Strict Intervention Lifecycle
-- Flow: Risk → Phase → Activities → Logs → Compliance → Review → Decision → Referral

-- PHASE 1: Intervention Phase
CREATE TABLE IF NOT EXISTS intervention_phase (
    phase_id TEXT PRIMARY KEY,
    child_id TEXT NOT NULL,
    domain TEXT NOT NULL,
    severity TEXT NOT NULL,
    baseline_delay REAL NOT NULL,
    start_date TEXT NOT NULL,
    review_date TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- PHASE 2: Auto-generated Activities
CREATE TABLE IF NOT EXISTS activities (
    activity_id TEXT PRIMARY KEY,
    phase_id TEXT NOT NULL,
    domain TEXT NOT NULL,
    role TEXT NOT NULL,
    name TEXT NOT NULL,
    frequency_per_week INTEGER NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (phase_id) REFERENCES intervention_phase(phase_id)
);

-- PHASE 3: Task Logs (compliance tracking)
CREATE TABLE IF NOT EXISTS task_logs (
    task_id TEXT PRIMARY KEY,
    activity_id TEXT NOT NULL,
    date_logged TEXT NOT NULL,
    completed INTEGER NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (activity_id) REFERENCES activities(activity_id)
);

-- PHASE 5: Review Decision Log
CREATE TABLE IF NOT EXISTS review_log (
    review_id TEXT PRIMARY KEY,
    phase_id TEXT NOT NULL,
    review_date TEXT NOT NULL,
    compliance REAL NOT NULL,
    improvement REAL NOT NULL,
    decision_action TEXT NOT NULL,
    decision_reason TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (phase_id) REFERENCES intervention_phase(phase_id)
);

-- PHASE 7: Referral (conditional, created only on escalation)
CREATE TABLE IF NOT EXISTS referral (
    referral_id TEXT PRIMARY KEY,
    child_id TEXT NOT NULL,
    domain TEXT NOT NULL,
    urgency TEXT NOT NULL,
    status TEXT NOT NULL,
    created_on TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_intervention_child ON intervention_phase(child_id);
CREATE INDEX IF NOT EXISTS idx_intervention_status ON intervention_phase(status);
CREATE INDEX IF NOT EXISTS idx_activities_phase ON activities(phase_id);
CREATE INDEX IF NOT EXISTS idx_tasks_activity ON task_logs(activity_id);
CREATE INDEX IF NOT EXISTS idx_review_phase ON review_log(phase_id);
CREATE INDEX IF NOT EXISTS idx_referral_child ON referral(child_id);
