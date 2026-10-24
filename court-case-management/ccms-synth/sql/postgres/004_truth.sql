-- ccms-synth schema (PostgreSQL) - 004 ground truth (model validation only)
-- Kept in a separate schema so analysts can be granted access to ccms only.
CREATE SCHEMA IF NOT EXISTS ccms_truth;
SET search_path = ccms_truth, ccms;

CREATE TABLE truth_parameter (
  parameter text PRIMARY KEY,
  value     double precision NOT NULL
);

CREATE TABLE truth_case (
  case_id                 integer PRIMARY KEY REFERENCES ccms.court_case,
  latent_complexity       double precision NOT NULL,
  contested               boolean NOT NULL,
  early_resolution        boolean NOT NULL,
  will_settle             boolean NOT NULL,
  needs_main_hearing      boolean NOT NULL,
  expert_needed           boolean NOT NULL,
  bulk_surge_month        boolean NOT NULL,
  reg_lag_days            double precision,
  clerk_load              double precision,
  service_days            double precision,
  unreachable_attempts    integer,
  prep_days               double precision,
  motion_delay_days       double precision,
  expert_days             double precision,
  hearing_queue_days      double precision,
  adjournment_delay_days  double precision,
  deliberation_work_days  double precision,
  backlog_at_deliberation integer,
  reassigned              boolean,
  trend_factor            double precision
);

CREATE TABLE truth_hearing (
  hearing_id       integer PRIMARY KEY REFERENCES ccms.hearing,
  counsel_load     integer NOT NULL,
  linear_predictor double precision NOT NULL,
  p_adjourn        double precision NOT NULL CHECK (p_adjourn BETWEEN 0 AND 1)
);

CREATE TABLE truth_counsel (
  counsel_id      integer PRIMARY KEY REFERENCES ccms.counsel,
  activity_weight double precision NOT NULL
);
