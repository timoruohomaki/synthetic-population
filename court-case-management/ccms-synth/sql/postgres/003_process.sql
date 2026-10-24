-- ccms-synth schema (PostgreSQL) - 003 process, delay attribution and resource panel
SET search_path = ccms;

CREATE TABLE hearing (
  hearing_id              integer PRIMARY KEY,
  case_id                 integer NOT NULL REFERENCES court_case,
  hearing_type            text NOT NULL CHECK (hearing_type IN ('PREPARATORY', 'MAIN')),
  judge_id                integer NOT NULL REFERENCES judge,
  courtroom_id            integer NOT NULL REFERENCES courtroom,
  scheduled_on_date       date NOT NULL,
  earliest_possible_date  date NOT NULL,
  hearing_date            date NOT NULL CHECK (hearing_date >= earliest_possible_date),
  start_ts                timestamptz NOT NULL,
  planned_hours           numeric(4, 1) NOT NULL CHECK (planned_hours > 0),
  outcome                 text NOT NULL CHECK (outcome IN ('HELD', 'ADJOURNED', 'VACATED', 'SCHEDULED')),
  adjournment_reason_code text REFERENCES adjournment_reason,
  prior_adjournments      integer NOT NULL CHECK (prior_adjournments >= 0),
  video_enabled           boolean NOT NULL,
  CHECK ((outcome = 'ADJOURNED') = (adjournment_reason_code IS NOT NULL))
);
CREATE INDEX ix_hearing_case ON hearing (case_id);
CREATE INDEX ix_hearing_judge_date ON hearing (judge_id, hearing_date);

CREATE TABLE procedural_deadline (
  deadline_id             integer PRIMARY KEY,
  case_id                 integer NOT NULL REFERENCES court_case,
  deadline_type           text NOT NULL CHECK (deadline_type IN ('RESPONSE', 'EXPERT_REPORT', 'JUDGMENT_TARGET')),
  set_date                date NOT NULL,
  due_date                date NOT NULL CHECK (due_date >= set_date),
  met_date                date,
  extended_days           integer NOT NULL DEFAULT 0 CHECK (extended_days >= 0),
  responsible_attribution text NOT NULL REFERENCES attribution_code
);
CREATE INDEX ix_deadline_case ON procedural_deadline (case_id);

CREATE TABLE motion (
  motion_id            integer PRIMARY KEY,
  case_id              integer NOT NULL REFERENCES court_case,
  motion_type          text NOT NULL CHECK (motion_type IN ('PROCEDURAL_OBJECTION', 'INTERLOCUTORY_APPEAL')),
  filed_by_attribution text NOT NULL REFERENCES attribution_code,
  filed_date           date NOT NULL,
  decided_date         date CHECK (decided_date >= filed_date),
  outcome              text
);

CREATE TABLE expert_report (
  expert_report_id integer PRIMARY KEY,
  case_id          integer NOT NULL REFERENCES court_case,
  ordered_date     date NOT NULL,
  due_date         date NOT NULL,
  delivered_date   date
);

CREATE TABLE custody_period (
  custody_id integer PRIMARY KEY,
  case_id    integer NOT NULL REFERENCES court_case,
  start_date date NOT NULL,
  end_date   date CHECK (end_date >= start_date),
  end_reason text CHECK (end_reason IN ('RELEASED', 'DISPOSITION'))
);

CREATE TABLE delay_period (
  delay_period_id      integer PRIMARY KEY,
  case_id              integer NOT NULL REFERENCES court_case,
  start_date           date NOT NULL,
  end_date             date NOT NULL CHECK (end_date >= start_date),
  attribution_code     text NOT NULL REFERENCES attribution_code,
  cause_code           text NOT NULL,
  delay_days           integer NOT NULL CHECK (delay_days >= 0),
  is_ongoing_at_cutoff boolean NOT NULL
);
CREATE INDEX ix_delay_case ON delay_period (case_id);

CREATE TABLE court_resource_month (
  court_id             integer NOT NULL REFERENCES court,
  period_month         text NOT NULL CHECK (period_month ~ '^[0-9]{4}-[0-9]{2}$'),
  month_start_date     date NOT NULL,
  judges_establishment integer NOT NULL,
  judges_fte           numeric(6, 2),
  clerks_fte           numeric(6, 2) NOT NULL CHECK (clerks_fte >= 0),
  clerk_vacancy_rate   numeric(5, 3) NOT NULL CHECK (clerk_vacancy_rate BETWEEN 0 AND 1),
  budget_eur           numeric(14, 2) NOT NULL CHECK (budget_eur >= 0),
  it_budget_share      numeric(5, 3) NOT NULL CHECK (it_budget_share BETWEEN 0 AND 1),
  efiling_rate         numeric(6, 4) CHECK (efiling_rate BETWEEN 0 AND 1),
  population           integer NOT NULL,
  PRIMARY KEY (court_id, period_month)
);
