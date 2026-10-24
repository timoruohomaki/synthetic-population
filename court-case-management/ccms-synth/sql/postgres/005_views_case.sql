-- ccms-synth schema (PostgreSQL) - 005 case-level analytical views
SET search_path = ccms;

CREATE VIEW v_case_lifecycle AS
SELECT c.case_id, c.case_number, c.court_id, c.case_type_code, c.category, c.filing_channel,
       c.filing_date, c.registration_date, c.first_appearance_date, c.disposition_date, c.disposition_code,
       c.is_open_at_cutoff, c.claim_amount_eur, c.n_charges, c.n_respondents,
       (c.interpreter_language IS NOT NULL) AS needs_interpreter, c.in_custody_at_filing,
       COALESCE(l.is_bulk_filer, false) AS bulk_filed,
       c.registration_date - c.filing_date AS registration_lag_days,
       c.first_appearance_date - c.filing_date AS queue_time_days,
       c.disposition_date - c.first_appearance_date AS service_time_days,
       COALESCE(c.disposition_date, r.cutoff_date) - c.filing_date AS duration_days,
       (c.disposition_date IS NOT NULL)::int AS event_observed,
       (SELECT count(*) FROM hearing h WHERE h.case_id = c.case_id AND h.outcome IN ('HELD', 'ADJOURNED')) AS n_hearings,
       (SELECT count(*) FROM hearing h WHERE h.case_id = c.case_id AND h.outcome = 'ADJOURNED') AS n_adjournments,
       (SELECT count(*) FROM case_assignment a WHERE a.case_id = c.case_id) - 1 AS n_reassignments,
       (SELECT count(*) FROM motion m WHERE m.case_id = c.case_id) AS n_motions,
       (SELECT count(*) FROM expert_report e WHERE e.case_id = c.case_id) AS n_expert_reports,
       (SELECT sum(d.page_count) FROM document d WHERE d.case_id = c.case_id) AS total_pages,
       (SELECT sum(COALESCE(p.end_date, r.cutoff_date) - p.start_date)
          FROM custody_period p WHERE p.case_id = c.case_id) AS custody_days
FROM court_case c
CROSS JOIN sim_run r
LEFT JOIN litigant l ON l.litigant_id = c.initiating_litigant_id;

CREATE VIEW v_case_status_duration AS
SELECT s.case_id, s.status_code, sc.phase,
       sum(COALESCE(s.valid_to, r.cutoff_date) - s.valid_from) AS days_in_status
FROM case_status_history s
JOIN status_code sc ON sc.status_code = s.status_code
CROSS JOIN sim_run r
WHERE s.status_code <> 'DISPOSED'
GROUP BY s.case_id, s.status_code, sc.phase;

CREATE VIEW v_case_phase_duration AS
SELECT case_id, phase, sum(days_in_status) AS days_in_phase
FROM v_case_status_duration
GROUP BY case_id, phase;

CREATE VIEW v_delay_attribution AS
WITH d AS (
  SELECT case_id,
         sum(delay_days) FILTER (WHERE attribution_code = 'DEFENCE')     AS defence_days,
         sum(delay_days) FILTER (WHERE attribution_code = 'RESPONDENT')  AS respondent_days,
         sum(delay_days) FILTER (WHERE attribution_code = 'PROSECUTION') AS prosecution_days,
         sum(delay_days) FILTER (WHERE attribution_code = 'CLAIMANT')    AS claimant_days,
         sum(delay_days) FILTER (WHERE attribution_code = 'COURT')       AS court_days,
         sum(delay_days) FILTER (WHERE attribution_code = 'THIRD_PARTY') AS third_party_days,
         sum(delay_days) FILTER (WHERE attribution_code = 'JOINT')       AS joint_days
  FROM delay_period GROUP BY case_id
), x AS (
  SELECT lc.case_id, lc.court_id, lc.case_type_code, lc.category, lc.duration_days, lc.event_observed,
         COALESCE(d.defence_days, 0) AS defence_days, COALESCE(d.respondent_days, 0) AS respondent_days,
         COALESCE(d.prosecution_days, 0) AS prosecution_days, COALESCE(d.claimant_days, 0) AS claimant_days,
         COALESCE(d.court_days, 0) AS court_days, COALESCE(d.third_party_days, 0) AS third_party_days,
         COALESCE(d.joint_days, 0) AS joint_days, ct.presumptive_ceiling_days
  FROM v_case_lifecycle lc
  JOIN case_type ct ON ct.case_type_code = lc.case_type_code
  LEFT JOIN d ON d.case_id = lc.case_id
)
SELECT x.*,
       duration_days - defence_days - respondent_days - joint_days AS net_delay_days,
       (duration_days - defence_days - respondent_days - joint_days) > presumptive_ceiling_days AS exceeds_ceiling
FROM x;
