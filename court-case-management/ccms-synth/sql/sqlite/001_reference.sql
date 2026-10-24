-- ccms-synth schema (SQLite) - 001 reference / master data
-- Dates are ISO 8601 TEXT 'YYYY-MM-DD'; timestamps RFC 3339 UTC 'YYYY-MM-DDTHH:MM:SSZ'.
PRAGMA foreign_keys = ON;

CREATE TABLE sim_run (
  run_id        TEXT PRIMARY KEY,
  generated_at  TEXT NOT NULL CHECK (generated_at GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'),
  seed          INTEGER NOT NULL,
  start_date    TEXT NOT NULL CHECK (start_date = date(start_date)),
  end_date      TEXT NOT NULL CHECK (end_date = date(end_date)),
  cutoff_date   TEXT NOT NULL CHECK (cutoff_date = date(cutoff_date)),
  generator     TEXT NOT NULL,
  config_yaml   TEXT NOT NULL
);

CREATE TABLE calendar_day (
  calendar_date   TEXT PRIMARY KEY CHECK (calendar_date = date(calendar_date)),
  iso_weekday     INTEGER NOT NULL CHECK (iso_weekday BETWEEN 1 AND 7),
  is_working_day  INTEGER NOT NULL CHECK (is_working_day IN (0, 1)),
  is_holiday      INTEGER NOT NULL CHECK (is_holiday IN (0, 1)),
  holiday_name    TEXT,
  capacity_factor REAL NOT NULL CHECK (capacity_factor BETWEEN 0 AND 1)
);

CREATE TABLE court (
  court_id                   INTEGER PRIMARY KEY,
  court_code                 TEXT NOT NULL UNIQUE,
  court_name                 TEXT NOT NULL,
  court_level                TEXT NOT NULL CHECK (court_level IN ('ORDINARY', 'SMALL_CLAIMS')),
  population                 INTEGER NOT NULL CHECK (population > 0),
  judges_establishment       INTEGER NOT NULL CHECK (judges_establishment > 0),
  clerks_establishment       INTEGER NOT NULL CHECK (clerks_establishment > 0),
  hearing_weekdays_per_judge INTEGER NOT NULL CHECK (hearing_weekdays_per_judge BETWEEN 1 AND 5)
);

CREATE TABLE courtroom (
  courtroom_id  INTEGER PRIMARY KEY,
  court_id      INTEGER NOT NULL REFERENCES court (court_id),
  room_name     TEXT NOT NULL UNIQUE,
  video_enabled INTEGER NOT NULL CHECK (video_enabled IN (0, 1))
);

CREATE TABLE judge (
  judge_id                 INTEGER PRIMARY KEY,
  court_id                 INTEGER NOT NULL REFERENCES court (court_id),
  judge_code               TEXT NOT NULL UNIQUE,
  experience_years_at_start INTEGER NOT NULL CHECK (experience_years_at_start >= 0),
  hearing_weekdays         TEXT NOT NULL  -- ISO weekdays, comma separated
);

CREATE TABLE judge_absence (
  absence_id           INTEGER PRIMARY KEY,
  judge_id             INTEGER NOT NULL REFERENCES judge (judge_id),
  absence_type         TEXT NOT NULL CHECK (absence_type IN ('SHORT_ILLNESS', 'LONG_LEAVE')),
  start_date           TEXT NOT NULL CHECK (start_date = date(start_date)),
  end_date             TEXT NOT NULL CHECK (end_date = date(end_date) AND end_date >= start_date),
  is_ongoing_at_cutoff INTEGER NOT NULL CHECK (is_ongoing_at_cutoff IN (0, 1))
);

CREATE TABLE counsel (
  counsel_id    INTEGER PRIMARY KEY,
  home_court_id INTEGER NOT NULL REFERENCES court (court_id),
  counsel_code  TEXT NOT NULL UNIQUE,
  counsel_type  TEXT NOT NULL CHECK (counsel_type IN ('PRIVATE', 'PUBLIC_DEFENDER'))
);

CREATE TABLE litigant (
  litigant_id   INTEGER PRIMARY KEY,
  litigant_name TEXT NOT NULL,
  litigant_type TEXT NOT NULL CHECK (litigant_type IN ('ORGANISATION', 'PUBLIC_AUTHORITY')),
  is_bulk_filer INTEGER NOT NULL CHECK (is_bulk_filer IN (0, 1))
);

CREATE TABLE case_type (
  case_type_code           TEXT PRIMARY KEY,
  description              TEXT NOT NULL,
  category                 TEXT NOT NULL CHECK (category IN ('CRIMINAL', 'NON_CRIMINAL')),
  court_levels             TEXT NOT NULL,
  response_days            INTEGER NOT NULL CHECK (response_days >= 0),
  presumptive_ceiling_days INTEGER NOT NULL CHECK (presumptive_ceiling_days > 0)
);

CREATE TABLE attribution_code (attribution_code TEXT PRIMARY KEY, description TEXT NOT NULL);
CREATE TABLE disposition_type (disposition_code TEXT PRIMARY KEY, description TEXT NOT NULL);
CREATE TABLE event_type       (event_code       TEXT PRIMARY KEY, description TEXT NOT NULL);
CREATE TABLE status_code (
  status_code TEXT PRIMARY KEY,
  phase       TEXT NOT NULL,
  description TEXT NOT NULL
);
CREATE TABLE adjournment_reason (
  reason_code      TEXT PRIMARY KEY,
  description      TEXT NOT NULL,
  attribution_code TEXT NOT NULL REFERENCES attribution_code (attribution_code),
  applies_to       TEXT NOT NULL CHECK (applies_to IN ('CRIMINAL', 'NON_CRIMINAL', 'BOTH'))
);
