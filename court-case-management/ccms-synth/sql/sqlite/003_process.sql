-- ccms-synth schema (SQLite) - 003 process, delay attribution and resource panel
CREATE TABLE hearing (
  hearing_id              INTEGER PRIMARY KEY,
  case_id                 INTEGER NOT NULL REFERENCES court_case (case_id),
  hearing_type            TEXT NOT NULL CHECK (hearing_type IN ('PREPARATORY', 'MAIN')),
  judge_id                INTEGER NOT NULL REFERENCES judge (judge_id),
  courtroom_id            INTEGER NOT NULL REFERENCES courtroom (courtroom_id),
  scheduled_on_date       TEXT NOT NULL CHECK (scheduled_on_date = date(scheduled_on_date)),
  earliest_possible_date  TEXT NOT NULL CHECK (earliest_possible_date = date(earliest_possible_date)),
  hearing_date            TEXT NOT NULL CHECK (hearing_date = date(hearing_date) AND hearing_date >= earliest_possible_date),
  start_ts                TEXT NOT NULL,
  planned_hours           REAL NOT NULL CHECK (planned_hours > 0),
  outcome                 TEXT NOT NULL CHECK (outcome IN ('HELD', 'ADJOURNED', 'VACATED', 'SCHEDULED')),
  adjournment_reason_code TEXT REFERENCES adjournment_reason (reason_code),
  prior_adjournments      INTEGER NOT NULL CHECK (prior_adjournments >= 0),
  video_enabled           INTEGER NOT NULL CHECK (video_enabled IN (0, 1)),
  CHECK ((outcome = 'ADJOURNED') = (adjournment_reason_code IS NOT NULL))
);
CREATE INDEX ix_hearing_case ON hearing (case_id);
CREATE INDEX ix_hearing_judge_date ON hearing (judge_id, hearing_date);

CREATE TABLE procedural_deadline (
  deadline_id             INTEGER PRIMARY KEY,
  case_id                 INTEGER NOT NULL REFERENCES court_case (case_id),
  deadline_type           TEXT NOT NULL CHECK (deadline_type IN ('RESPONSE', 'EXPERT_REPORT', 'JUDGMENT_TARGET')),
  set_date                TEXT NOT NULL CHECK (set_date = date(set_date)),
  due_date                TEXT NOT NULL CHECK (due_date = date(due_date) AND due_date >= set_date),
  met_date                TEXT CHECK (met_date = date(met_date)),  -- NULL = not met by cutoff
  extended_days           INTEGER NOT NULL DEFAULT 0 CHECK (extended_days >= 0),
  responsible_attribution TEXT NOT NULL REFERENCES attribution_code (attribution_code)
);
CREATE INDEX ix_deadline_case ON procedural_deadline (case_id);

CREATE TABLE motion (
  motion_id            INTEGER PRIMARY KEY,
  case_id              INTEGER NOT NULL REFERENCES court_case (case_id),
  motion_type          TEXT NOT NULL CHECK (motion_type IN ('PROCEDURAL_OBJECTION', 'INTERLOCUTORY_APPEAL')),
  filed_by_attribution TEXT NOT NULL REFERENCES attribution_code (attribution_code),
  filed_date           TEXT NOT NULL CHECK (filed_date = date(filed_date)),
  decided_date         TEXT CHECK (decided_date = date(decided_date) AND decided_date >= filed_date),
  outcome              TEXT
);

CREATE TABLE expert_report (
  expert_report_id INTEGER PRIMARY KEY,
  case_id          INTEGER NOT NULL REFERENCES court_case (case_id),
  ordered_date     TEXT NOT NULL CHECK (ordered_date = date(ordered_date)),
  due_date         TEXT NOT NULL CHECK (due_date = date(due_date)),
  delivered_date   TEXT CHECK (delivered_date = date(delivered_date))
);

CREATE TABLE custody_period (
  custody_id INTEGER PRIMARY KEY,
  case_id    INTEGER NOT NULL REFERENCES court_case (case_id),
  start_date TEXT NOT NULL CHECK (start_date = date(start_date)),
  end_date   TEXT CHECK (end_date = date(end_date) AND end_date >= start_date),
  end_reason TEXT CHECK (end_reason IN ('RELEASED', 'DISPOSITION'))
);

-- Periods of delay with responsibility, as recorded by the registry.
CREATE TABLE delay_period (
  delay_period_id      INTEGER PRIMARY KEY,
  case_id              INTEGER NOT NULL REFERENCES court_case (case_id),
  start_date           TEXT NOT NULL CHECK (start_date = date(start_date)),
  end_date             TEXT NOT NULL CHECK (end_date = date(end_date) AND end_date >= start_date),
  attribution_code     TEXT NOT NULL REFERENCES attribution_code (attribution_code),
  cause_code           TEXT NOT NULL,
  delay_days           INTEGER NOT NULL CHECK (delay_days >= 0),
  is_ongoing_at_cutoff INTEGER NOT NULL CHECK (is_ongoing_at_cutoff IN (0, 1))
);
CREATE INDEX ix_delay_case ON delay_period (case_id);

-- Court x month panel of resources (Rocha et al. style controls).
CREATE TABLE court_resource_month (
  court_id             INTEGER NOT NULL REFERENCES court (court_id),
  period_month         TEXT NOT NULL CHECK (period_month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]'),
  month_start_date     TEXT NOT NULL CHECK (month_start_date = date(month_start_date)),
  judges_establishment INTEGER NOT NULL,
  judges_fte           REAL,
  clerks_fte           REAL NOT NULL CHECK (clerks_fte >= 0),
  clerk_vacancy_rate   REAL NOT NULL CHECK (clerk_vacancy_rate BETWEEN 0 AND 1),
  budget_eur           REAL NOT NULL CHECK (budget_eur >= 0),
  it_budget_share      REAL NOT NULL CHECK (it_budget_share BETWEEN 0 AND 1),
  efiling_rate         REAL CHECK (efiling_rate BETWEEN 0 AND 1),
  population           INTEGER NOT NULL,
  PRIMARY KEY (court_id, period_month)
);
