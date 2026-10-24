-- ccms-synth schema (PostgreSQL) - 006 hearing and court-level analytical views
SET search_path = ccms;

CREATE VIEW v_hearing_features AS
SELECT h.hearing_id, h.case_id, h.hearing_type, h.hearing_date, h.judge_id, h.courtroom_id,
       c.court_id, c.case_type_code, c.category, c.n_respondents,
       (c.interpreter_language IS NOT NULL) AS needs_interpreter,
       EXISTS (SELECT 1 FROM case_party p WHERE p.case_id = c.case_id
               AND p.party_role IN ('RESPONDENT', 'DEFENDANT') AND p.self_represented) AS self_represented,
       EXISTS (SELECT 1 FROM custody_period k WHERE k.case_id = c.case_id AND k.start_date <= h.hearing_date
               AND (k.end_date IS NULL OR k.end_date > h.hearing_date)) AS in_custody,
       h.video_enabled, h.prior_adjournments, h.planned_hours,
       (SELECT count(*) FROM case_party p
          JOIN case_party p2 ON p2.counsel_id = p.counsel_id AND p2.case_id <> p.case_id
          JOIN hearing h2 ON h2.case_id = p2.case_id AND h2.outcome IN ('HELD', 'ADJOURNED')
         WHERE p.case_id = h.case_id AND p.counsel_id IS NOT NULL
           AND abs(h2.hearing_date - h.hearing_date) <= 3) AS counsel_other_hearings_pm3d,
       (h.outcome = 'ADJOURNED') AS adjourned, h.adjournment_reason_code,
       CASE WHEN ar.attribution_code = 'DEFENCE' AND c.category = 'NON_CRIMINAL' THEN 'RESPONDENT'
            ELSE ar.attribution_code END AS attribution_code
FROM hearing h
JOIN court_case c ON c.case_id = h.case_id
LEFT JOIN adjournment_reason ar ON ar.reason_code = h.adjournment_reason_code
WHERE h.outcome IN ('HELD', 'ADJOURNED');

CREATE VIEW v_court_month_kpi AS
WITH m AS (
  SELECT court_id, period_month, month_start_date,
         (month_start_date + interval '1 month' - interval '1 day')::date AS month_end_date
  FROM court_resource_month
)
SELECT m.court_id, m.period_month,
       (SELECT count(*) FROM court_case c WHERE c.court_id = m.court_id
          AND to_char(c.filing_date, 'YYYY-MM') = m.period_month) AS incoming,
       (SELECT count(*) FROM court_case c WHERE c.court_id = m.court_id
          AND to_char(c.disposition_date, 'YYYY-MM') = m.period_month) AS resolved,
       (SELECT count(*) FROM court_case c WHERE c.court_id = m.court_id AND c.filing_date <= m.month_end_date
          AND (c.disposition_date IS NULL OR c.disposition_date > m.month_end_date)) AS pending_end,
       (SELECT avg(c.disposition_date - c.filing_date) FROM court_case c
         WHERE c.court_id = m.court_id AND to_char(c.disposition_date, 'YYYY-MM') = m.period_month)
         AS mean_duration_resolved,
       r.judges_fte, r.clerks_fte, r.budget_eur, r.it_budget_share, r.efiling_rate, r.population
FROM m
JOIN court_resource_month r ON r.court_id = m.court_id AND r.period_month = m.period_month;

CREATE VIEW v_court_month_indicators AS
SELECT k.*,
       CASE WHEN incoming > 0 THEN resolved::numeric / incoming END AS clearance_rate,
       CASE WHEN resolved > 0 THEN 30.4 * pending_end / resolved END AS disposition_time_days,
       12.0 * incoming / population * 100000 AS litigation_per_100k_annualised
FROM v_court_month_kpi k;

CREATE VIEW v_judge_month_load AS
WITH m AS (SELECT DISTINCT period_month,
                  (month_start_date + interval '1 month' - interval '1 day')::date AS month_end_date
           FROM court_resource_month)
SELECT j.judge_id, j.court_id, m.period_month,
       (SELECT count(*) FROM case_assignment a WHERE a.judge_id = j.judge_id AND a.start_date <= m.month_end_date
          AND (a.end_date IS NULL OR a.end_date > m.month_end_date)) AS open_cases_end,
       (SELECT count(*) FROM hearing h WHERE h.judge_id = j.judge_id AND h.outcome = 'HELD'
          AND to_char(h.hearing_date, 'YYYY-MM') = m.period_month) AS hearings_held,
       (SELECT count(*) FROM case_event e WHERE e.judge_id = j.judge_id AND e.event_code = 'CASE_DISPOSED'
          AND e.detail IN ('JUDGMENT', 'WRITTEN_DECISION', 'DEFAULT_JUDGMENT')
          AND to_char(e.event_date, 'YYYY-MM') = m.period_month) AS decisions_issued
FROM judge j CROSS JOIN m;
