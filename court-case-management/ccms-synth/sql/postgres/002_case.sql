-- ccms-synth schema (PostgreSQL) - 002 case core
SET search_path = ccms;

CREATE TABLE court_case (
  case_id                integer PRIMARY KEY,
  case_number            text NOT NULL UNIQUE,
  court_id               integer NOT NULL REFERENCES court,
  case_type_code         text NOT NULL REFERENCES case_type,
  category               text NOT NULL CHECK (category IN ('CRIMINAL', 'NON_CRIMINAL')),
  filing_date            date NOT NULL,
  filing_channel         text NOT NULL CHECK (filing_channel IN ('EFILING', 'PAPER')),
  registration_date      date CHECK (registration_date >= filing_date),
  first_appearance_date  date,
  initiating_litigant_id integer REFERENCES litigant,
  claim_amount_eur       numeric(14, 2) CHECK (claim_amount_eur >= 0),
  n_charges              integer CHECK (n_charges >= 1),
  n_respondents          integer NOT NULL CHECK (n_respondents >= 1),
  interpreter_language   text,
  in_custody_at_filing   boolean NOT NULL,
  disposition_code       text REFERENCES disposition_type,
  disposition_date       date CHECK (disposition_date >= filing_date),
  case_status            text REFERENCES status_code,
  is_open_at_cutoff      boolean NOT NULL,
  CHECK ((disposition_code IS NULL) = (disposition_date IS NULL))
);
CREATE INDEX ix_case_court_type ON court_case (court_id, case_type_code);
CREATE INDEX ix_case_filing ON court_case (filing_date);

CREATE TABLE case_party (
  party_id             integer PRIMARY KEY,
  case_id              integer NOT NULL REFERENCES court_case,
  party_seq            integer NOT NULL,
  party_role           text NOT NULL CHECK (party_role IN ('CLAIMANT', 'RESPONDENT', 'PROSECUTOR', 'DEFENDANT')),
  party_type           text NOT NULL CHECK (party_type IN ('PERSON', 'ORGANISATION', 'PUBLIC_AUTHORITY')),
  litigant_id          integer REFERENCES litigant,
  counsel_id           integer REFERENCES counsel,
  self_represented     boolean NOT NULL,
  interpreter_language text,
  in_custody_at_filing boolean NOT NULL,
  UNIQUE (case_id, party_seq)
);
CREATE INDEX ix_party_counsel ON case_party (counsel_id);

CREATE TABLE case_assignment (
  assignment_id     integer PRIMARY KEY,
  case_id           integer NOT NULL REFERENCES court_case,
  judge_id          integer NOT NULL REFERENCES judge,
  start_date        date NOT NULL,
  end_date          date CHECK (end_date >= start_date),
  assignment_reason text NOT NULL CHECK (assignment_reason IN ('INITIAL', 'JUDGE_LONG_ABSENCE'))
);
CREATE INDEX ix_assign_case ON case_assignment (case_id);
CREATE INDEX ix_assign_judge ON case_assignment (judge_id, start_date);

CREATE TABLE case_status_history (
  status_history_id integer PRIMARY KEY,
  case_id           integer NOT NULL REFERENCES court_case,
  status_code       text NOT NULL REFERENCES status_code,
  valid_from        date NOT NULL,
  valid_to          date CHECK (valid_to >= valid_from)
);
CREATE INDEX ix_status_case ON case_status_history (case_id, valid_from);

CREATE TABLE case_event (
  event_id   integer PRIMARY KEY,
  case_id    integer NOT NULL REFERENCES court_case,
  event_code text NOT NULL REFERENCES event_type,
  event_date date NOT NULL,
  event_ts   timestamptz NOT NULL,
  judge_id   integer REFERENCES judge,
  hearing_id integer,
  detail     text
);
CREATE INDEX ix_event_case ON case_event (case_id, event_ts);
CREATE INDEX ix_event_code ON case_event (event_code, event_date);

CREATE TABLE document (
  document_id   integer PRIMARY KEY,
  case_id       integer NOT NULL REFERENCES court_case,
  event_id      integer NOT NULL REFERENCES case_event,
  document_type text NOT NULL,
  filed_ts      timestamptz NOT NULL,
  page_count    integer NOT NULL CHECK (page_count >= 1)
);
CREATE INDEX ix_document_case ON document (case_id);
