-- ccms-synth schema (PostgreSQL >= 13) - 001 reference / master data
CREATE SCHEMA IF NOT EXISTS ccms;
SET search_path = ccms;

CREATE TABLE sim_run (
  run_id       text PRIMARY KEY,
  generated_at timestamptz NOT NULL,
  seed         integer NOT NULL,
  start_date   date NOT NULL,
  end_date     date NOT NULL,
  cutoff_date  date NOT NULL CHECK (cutoff_date >= end_date),
  generator    text NOT NULL,
  config_yaml  text NOT NULL
);

CREATE TABLE calendar_day (
  calendar_date   date PRIMARY KEY,
  iso_weekday     smallint NOT NULL CHECK (iso_weekday BETWEEN 1 AND 7),
  is_working_day  boolean NOT NULL,
  is_holiday      boolean NOT NULL,
  holiday_name    text,
  capacity_factor numeric(5, 3) NOT NULL CHECK (capacity_factor BETWEEN 0 AND 1)
);

CREATE TABLE court (
  court_id                   integer PRIMARY KEY,
  court_code                 text NOT NULL UNIQUE,
  court_name                 text NOT NULL,
  court_level                text NOT NULL CHECK (court_level IN ('ORDINARY', 'SMALL_CLAIMS')),
  population                 integer NOT NULL CHECK (population > 0),
  judges_establishment       integer NOT NULL CHECK (judges_establishment > 0),
  clerks_establishment       integer NOT NULL CHECK (clerks_establishment > 0),
  hearing_weekdays_per_judge smallint NOT NULL CHECK (hearing_weekdays_per_judge BETWEEN 1 AND 5)
);

CREATE TABLE courtroom (
  courtroom_id  integer PRIMARY KEY,
  court_id      integer NOT NULL REFERENCES court,
  room_name     text NOT NULL UNIQUE,
  video_enabled boolean NOT NULL
);

CREATE TABLE judge (
  judge_id                  integer PRIMARY KEY,
  court_id                  integer NOT NULL REFERENCES court,
  judge_code                text NOT NULL UNIQUE,
  experience_years_at_start integer NOT NULL CHECK (experience_years_at_start >= 0),
  hearing_weekdays          text NOT NULL
);

CREATE TABLE judge_absence (
  absence_id           integer PRIMARY KEY,
  judge_id             integer NOT NULL REFERENCES judge,
  absence_type         text NOT NULL CHECK (absence_type IN ('SHORT_ILLNESS', 'LONG_LEAVE')),
  start_date           date NOT NULL,
  end_date             date NOT NULL CHECK (end_date >= start_date),
  is_ongoing_at_cutoff boolean NOT NULL
);

CREATE TABLE counsel (
  counsel_id    integer PRIMARY KEY,
  home_court_id integer NOT NULL REFERENCES court,
  counsel_code  text NOT NULL UNIQUE,
  counsel_type  text NOT NULL CHECK (counsel_type IN ('PRIVATE', 'PUBLIC_DEFENDER'))
);

CREATE TABLE litigant (
  litigant_id   integer PRIMARY KEY,
  litigant_name text NOT NULL,
  litigant_type text NOT NULL CHECK (litigant_type IN ('ORGANISATION', 'PUBLIC_AUTHORITY')),
  is_bulk_filer boolean NOT NULL
);

CREATE TABLE case_type (
  case_type_code           text PRIMARY KEY,
  description              text NOT NULL,
  category                 text NOT NULL CHECK (category IN ('CRIMINAL', 'NON_CRIMINAL')),
  court_levels             text NOT NULL,
  response_days            integer NOT NULL CHECK (response_days >= 0),
  presumptive_ceiling_days integer NOT NULL CHECK (presumptive_ceiling_days > 0)
);

CREATE TABLE attribution_code (attribution_code text PRIMARY KEY, description text NOT NULL);
CREATE TABLE disposition_type (disposition_code text PRIMARY KEY, description text NOT NULL);
CREATE TABLE event_type       (event_code       text PRIMARY KEY, description text NOT NULL);
CREATE TABLE status_code      (status_code text PRIMARY KEY, phase text NOT NULL, description text NOT NULL);
CREATE TABLE adjournment_reason (
  reason_code      text PRIMARY KEY,
  description      text NOT NULL,
  attribution_code text NOT NULL REFERENCES attribution_code,
  applies_to       text NOT NULL CHECK (applies_to IN ('CRIMINAL', 'NON_CRIMINAL', 'BOTH'))
);
