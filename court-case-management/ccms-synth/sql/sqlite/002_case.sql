-- ccms-synth schema (SQLite) - 002 case core
CREATE TABLE court_case (
  case_id                INTEGER PRIMARY KEY,
  case_number            TEXT NOT NULL UNIQUE,
  court_id               INTEGER NOT NULL REFERENCES court (court_id),
  case_type_code         TEXT NOT NULL REFERENCES case_type (case_type_code),
  category               TEXT NOT NULL CHECK (category IN ('CRIMINAL', 'NON_CRIMINAL')),
  filing_date            TEXT NOT NULL CHECK (filing_date = date(filing_date)),
  filing_channel         TEXT NOT NULL CHECK (filing_channel IN ('EFILING', 'PAPER')),
  registration_date      TEXT CHECK (registration_date = date(registration_date) AND registration_date >= filing_date),
  first_appearance_date  TEXT CHECK (first_appearance_date = date(first_appearance_date)),
  initiating_litigant_id INTEGER REFERENCES litigant (litigant_id),
  claim_amount_eur       REAL CHECK (claim_amount_eur >= 0),
  n_charges              INTEGER CHECK (n_charges >= 1),
  n_respondents          INTEGER NOT NULL CHECK (n_respondents >= 1),
  interpreter_language   TEXT,                 -- ISO 639-1
  in_custody_at_filing   INTEGER NOT NULL CHECK (in_custody_at_filing IN (0, 1)),
  disposition_code       TEXT REFERENCES disposition_type (disposition_code),
  disposition_date       TEXT CHECK (disposition_date = date(disposition_date) AND disposition_date >= filing_date),
  case_status            TEXT REFERENCES status_code (status_code),  -- status at cutoff
  is_open_at_cutoff      INTEGER NOT NULL CHECK (is_open_at_cutoff IN (0, 1)),
  CHECK ((disposition_code IS NULL) = (disposition_date IS NULL))
);
CREATE INDEX ix_case_court_type ON court_case (court_id, case_type_code);
CREATE INDEX ix_case_filing ON court_case (filing_date);

CREATE TABLE case_party (
  party_id             INTEGER PRIMARY KEY,
  case_id              INTEGER NOT NULL REFERENCES court_case (case_id),
  party_seq            INTEGER NOT NULL,
  party_role           TEXT NOT NULL CHECK (party_role IN ('CLAIMANT', 'RESPONDENT', 'PROSECUTOR', 'DEFENDANT')),
  party_type           TEXT NOT NULL CHECK (party_type IN ('PERSON', 'ORGANISATION', 'PUBLIC_AUTHORITY')),
  litigant_id          INTEGER REFERENCES litigant (litigant_id),
  counsel_id           INTEGER REFERENCES counsel (counsel_id),
  self_represented     INTEGER NOT NULL CHECK (self_represented IN (0, 1)),
  interpreter_language TEXT,
  in_custody_at_filing INTEGER NOT NULL CHECK (in_custody_at_filing IN (0, 1)),
  UNIQUE (case_id, party_seq)
);
CREATE INDEX ix_party_counsel ON case_party (counsel_id);

CREATE TABLE case_assignment (
  assignment_id     INTEGER PRIMARY KEY,
  case_id           INTEGER NOT NULL REFERENCES court_case (case_id),
  judge_id          INTEGER NOT NULL REFERENCES judge (judge_id),
  start_date        TEXT NOT NULL CHECK (start_date = date(start_date)),
  end_date          TEXT CHECK (end_date = date(end_date) AND end_date >= start_date),
  assignment_reason TEXT NOT NULL CHECK (assignment_reason IN ('INITIAL', 'JUDGE_LONG_ABSENCE'))
);
CREATE INDEX ix_assign_case ON case_assignment (case_id);
CREATE INDEX ix_assign_judge ON case_assignment (judge_id, start_date);

CREATE TABLE case_status_history (
  status_history_id INTEGER PRIMARY KEY,
  case_id           INTEGER NOT NULL REFERENCES court_case (case_id),
  status_code       TEXT NOT NULL REFERENCES status_code (status_code),
  valid_from        TEXT NOT NULL CHECK (valid_from = date(valid_from)),
  valid_to          TEXT CHECK (valid_to = date(valid_to) AND valid_to >= valid_from)  -- NULL = current
);
CREATE INDEX ix_status_case ON case_status_history (case_id, valid_from);

CREATE TABLE case_event (
  event_id   INTEGER PRIMARY KEY,
  case_id    INTEGER NOT NULL REFERENCES court_case (case_id),
  event_code TEXT NOT NULL REFERENCES event_type (event_code),
  event_date TEXT NOT NULL CHECK (event_date = date(event_date)),
  event_ts   TEXT NOT NULL CHECK (event_ts GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'),
  judge_id   INTEGER REFERENCES judge (judge_id),
  hearing_id INTEGER,  -- logical reference to hearing (created in 003)
  detail     TEXT
);
CREATE INDEX ix_event_case ON case_event (case_id, event_ts);
CREATE INDEX ix_event_code ON case_event (event_code, event_date);

CREATE TABLE document (
  document_id   INTEGER PRIMARY KEY,
  case_id       INTEGER NOT NULL REFERENCES court_case (case_id),
  event_id      INTEGER NOT NULL REFERENCES case_event (event_id),
  document_type TEXT NOT NULL,
  filed_ts      TEXT NOT NULL,
  page_count    INTEGER NOT NULL CHECK (page_count >= 1)
);
CREATE INDEX ix_document_case ON document (case_id);
