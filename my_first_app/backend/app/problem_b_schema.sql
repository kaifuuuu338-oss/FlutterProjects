CREATE TABLE IF NOT EXISTS child_profile (
  child_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  dob TEXT NOT NULL,
  age_months INTEGER NOT NULL,
  gender TEXT,
  awc_code TEXT,
  sector TEXT,
  mandal TEXT,
  district TEXT,
  state TEXT
);

CREATE TABLE IF NOT EXISTS developmental_risk (
  risk_id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  gm_delay_months INTEGER DEFAULT 0,
  fm_delay_months INTEGER DEFAULT 0,
  lc_delay_months INTEGER DEFAULT 0,
  cog_delay_months INTEGER DEFAULT 0,
  se_delay_months INTEGER DEFAULT 0,
  num_delays INTEGER DEFAULT 0,
  risk_score REAL DEFAULT 0,
  risk_category TEXT,
  assessment_date TEXT,
  FOREIGN KEY(child_id) REFERENCES child_profile(child_id)
);

CREATE TABLE IF NOT EXISTS neuro_behavioral (
  child_id TEXT PRIMARY KEY,
  autism_risk TEXT,
  adhd_risk TEXT,
  behavioral_risk TEXT,
  FOREIGN KEY(child_id) REFERENCES child_profile(child_id)
);

CREATE TABLE IF NOT EXISTS intervention_plan (
  plan_id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  domain TEXT,
  severity TEXT,
  phase_duration_weeks INTEGER DEFAULT 8,
  phase_start_date TEXT,
  phase_end_date TEXT,
  review_interval_days INTEGER DEFAULT 30,
  target_milestone TEXT,
  intensity_level TEXT,
  start_date TEXT,
  review_date TEXT,
  active_status TEXT,
  FOREIGN KEY(child_id) REFERENCES child_profile(child_id)
);

CREATE TABLE IF NOT EXISTS intervention_activities (
  activity_id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL,
  domain TEXT,
  age_band TEXT,
  severity TEXT,
  stakeholder TEXT,
  activity_type TEXT,
  title TEXT,
  description TEXT,
  duration_minutes INTEGER DEFAULT 10,
  required_per_week INTEGER DEFAULT 5,
  frequency TEXT,
  FOREIGN KEY(plan_id) REFERENCES intervention_plan(plan_id)
);

CREATE TABLE IF NOT EXISTS activity_master (
  activity_id TEXT PRIMARY KEY,
  domain TEXT NOT NULL,
  age_band TEXT NOT NULL,
  severity TEXT NOT NULL,
  stakeholder TEXT NOT NULL,
  activity_type TEXT NOT NULL, -- daily_core / weekly_target
  title TEXT NOT NULL,
  description TEXT,
  duration_minutes INTEGER DEFAULT 10,
  required_per_week INTEGER DEFAULT 5
);

CREATE TABLE IF NOT EXISTS activity_assignment (
  assignment_id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL,
  activity_id TEXT NOT NULL,
  week_number INTEGER NOT NULL,
  required_count INTEGER DEFAULT 0,
  completed_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  FOREIGN KEY(plan_id) REFERENCES intervention_plan(plan_id),
  FOREIGN KEY(activity_id) REFERENCES activity_master(activity_id)
);

CREATE TABLE IF NOT EXISTS weekly_progress (
  progress_id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL,
  week_number INTEGER NOT NULL,
  completion_percentage REAL DEFAULT 0,
  review_notes TEXT,
  FOREIGN KEY(plan_id) REFERENCES intervention_plan(plan_id)
);

CREATE TABLE IF NOT EXISTS referral (
  referral_id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  referral_type TEXT,
  urgency TEXT,
  status TEXT,
  created_date TEXT,
  followup_date TEXT,
  reason TEXT,
  FOREIGN KEY(child_id) REFERENCES child_profile(child_id)
);

CREATE TABLE IF NOT EXISTS followup_assessment (
  followup_id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  gm_delay INTEGER DEFAULT 0,
  fm_delay INTEGER DEFAULT 0,
  lc_delay INTEGER DEFAULT 0,
  cog_delay INTEGER DEFAULT 0,
  se_delay INTEGER DEFAULT 0,
  assessment_date TEXT,
  trend_status TEXT,
  delay_reduction INTEGER DEFAULT 0,
  FOREIGN KEY(child_id) REFERENCES child_profile(child_id)
);

CREATE TABLE IF NOT EXISTS caregiver_engagement (
  engagement_id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL,
  mode TEXT,
  last_nudge_date TEXT,
  compliance_score REAL DEFAULT 0,
  FOREIGN KEY(child_id) REFERENCES child_profile(child_id)
);
