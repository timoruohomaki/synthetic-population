-- ccms-synth schema (SQLite) - 004 ground truth (for model validation only)
-- These tables hold latent variables and the true parameters of the generator.
-- Exclude them from feature sets; use them to check whether a model recovers the truth.
CREATE TABLE truth_parameter (
  parameter TEXT PRIMARY KEY,
  value     REAL NOT NULL
);

CREATE TABLE truth_case (
  case_id                 INTEGER PRIMARY KEY REFERENCES court_case (case_id),
  latent_complexity       REAL NOT NULL,
  contested               INTEGER NOT NULL,
  early_resolution        INTEGER NOT NULL,
  will_settle             INTEGER NOT NULL,
  needs_main_hearing      INTEGER NOT NULL,
  expert_needed           INTEGER NOT NULL,
  bulk_surge_month        INTEGER NOT NULL,
  reg_lag_days            REAL,   -- registration lag before rounding to a working day
  clerk_load              REAL,   -- filings last 30 d / (clerk FTE x capacity)
  service_days            REAL,
  unreachable_attempts    INTEGER,
  prep_days               REAL,
  motion_delay_days       REAL,
  expert_days             REAL,
  hearing_queue_days      REAL,   -- sum over bookings of (hearing date - earliest possible)
  adjournment_delay_days  REAL,
  deliberation_work_days  REAL,
  backlog_at_deliberation INTEGER, -- judge's pending judgments when drafting started
  reassigned              INTEGER,
  trend_factor            REAL
);

CREATE TABLE truth_hearing (
  hearing_id       INTEGER PRIMARY KEY REFERENCES hearing (hearing_id),
  counsel_load     INTEGER NOT NULL,
  linear_predictor REAL NOT NULL,
  p_adjourn        REAL NOT NULL CHECK (p_adjourn BETWEEN 0 AND 1)
);

CREATE TABLE truth_counsel (
  counsel_id      INTEGER PRIMARY KEY REFERENCES counsel (counsel_id),
  activity_weight REAL NOT NULL
);
