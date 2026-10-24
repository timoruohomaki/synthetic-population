-- ccms-synth schema (SQLite) - 005 case-level analytical views
-- Durations are calendar days. Open cases are right-censored at sim_run.cutoff_date.

CREATE VIEW v_case_lifecycle AS
SELECT c.case_id, c.case_number, c.court_id, c.case_type_code, c.category, c.filing_channel,
       c.filing_date, c.registration_date, c.first_appearance_date, c.disposition_date, c.disposition_code,
       c.is_open_at_cutoff, c.claim_amount_eur, c.n_charges, c.n_respondents,
       (c.interpreter_language IS NOT NULL) AS needs_interpreter, c.in_custody_at_filing,
       c.initiating_litigant_id IS NOT NULL AND l.is_bulk_filer = 1 AS bulk_filed,
       julianday(c.registration_date) - julianday(c.filing_date) AS registration_lag_days,
       julianday(c.first_appearance_date) - julianday(c.filing_date) AS queue_time_days,     -- Clarke & Metzler
       julianday(c.disposition_date) - julianday(c.first_appearance_date) AS service_time_days,
       julianday(COALESCE(c.disposition_date, r.cutoff_date)) - julianday(c.filing_date) AS duration_days,
       CASE WHEN c.disposition_date IS NULL THEN 0 ELSE 1 END AS event_observed,
       (SELECT COUNT(*) FROM hearing h WHERE h.case_id = c.case_id AND h.outcome IN ('HELD', 'ADJOURNED')) AS n_hearings,
       (SELECT COUNT(*) FROM hearing h WHERE h.case_id = c.case_id AND h.outcome = 'ADJOURNED') AS n_adjournments,
       (SELECT COUNT(*) FROM case_assignment a WHERE a.case_id = c.case_id) - 1 AS n_reassignments,
       (SELECT COUNT(*) FROM motion m WHERE m.case_id = c.case_id) AS n_motions,
       (SELECT COUNT(*) FROM expert_report e WHERE e.case_id = c.case_id) AS n_expert_reports,
       (SELECT SUM(d.page_count) FROM document d WHERE d.case_id = c.case_id) AS total_pages,
       (SELECT SUM(julianday(COALESCE(p.end_date, r.cutoff_date)) - julianday(p.start_date))
          FROM custody_period p WHERE p.case_id = c.case_id) AS custody_days
FROM court_case c
CROSS JOIN sim_run r
LEFT JOIN litigant l ON l.litigant_id = c.initiating_litigant_id;

-- Time spent in each status (process-mining style decomposition of duration).
CREATE VIEW v_case_status_duration AS
SELECT s.case_id, s.status_code, sc.phase,
       SUM(julianday(COALESCE(s.valid_to, r.cutoff_date)) - julianday(s.valid_from)) AS days_in_status
FROM case_status_history s
JOIN status_code sc ON sc.status_code = s.status_code
CROSS JOIN sim_run r
WHERE s.status_code <> 'DISPOSED'
GROUP BY s.case_id, s.status_code, sc.phase;

CREATE VIEW v_case_phase_duration AS
SELECT case_id, phase, SUM(days_in_status) AS days_in_phase
FROM v_case_status_duration
GROUP BY case_id, phase;

-- Delay attribution and Jordan-style net delay vs. presumptive ceiling.
-- Net delay = total duration minus delay attributable to the defence/respondent side.
CREATE VIEW v_delay_attribution AS
WITH d AS (
  SELECT case_id,
         SUM(CASE WHEN attribution_code = 'DEFENCE'     THEN delay_days ELSE 0 END) AS defence_days,
         SUM(CASE WHEN attribution_code = 'RESPONDENT'  THEN delay_days ELSE 0 END) AS respondent_days,
         SUM(CASE WHEN attribution_code = 'PROSECUTION' THEN delay_days ELSE 0 END) AS prosecution_days,
         SUM(CASE WHEN attribution_code = 'CLAIMANT'    THEN delay_days ELSE 0 END) AS claimant_days,
         SUM(CASE WHEN attribution_code = 'COURT'       THEN delay_days ELSE 0 END) AS court_days,
         SUM(CASE WHEN attribution_code = 'THIRD_PARTY' THEN delay_days ELSE 0 END) AS third_party_days,
         SUM(CASE WHEN attribution_code = 'JOINT'       THEN delay_days ELSE 0 END) AS joint_days
  FROM delay_period GROUP BY case_id
)
SELECT lc.case_id, lc.court_id, lc.case_type_code, lc.category, lc.duration_days, lc.event_observed,
       COALESCE(d.defence_days, 0) AS defence_days, COALESCE(d.respondent_days, 0) AS respondent_days,
       COALESCE(d.prosecution_days, 0) AS prosecution_days, COALESCE(d.claimant_days, 0) AS claimant_days,
       COALESCE(d.court_days, 0) AS court_days, COALESCE(d.third_party_days, 0) AS third_party_days,
       COALESCE(d.joint_days, 0) AS joint_days,
       lc.duration_days - COALESCE(d.defence_days, 0) - COALESCE(d.respondent_days, 0) - COALESCE(d.joint_days, 0)
         AS net_delay_days,
       ct.presumptive_ceiling_days,
       (lc.duration_days - COALESCE(d.defence_days, 0) - COALESCE(d.respondent_days, 0) - COALESCE(d.joint_days, 0))
         > ct.presumptive_ceiling_days AS exceeds_ceiling
FROM v_case_lifecycle lc
JOIN case_type ct ON ct.case_type_code = lc.case_type_code
LEFT JOIN d ON d.case_id = lc.case_id;
