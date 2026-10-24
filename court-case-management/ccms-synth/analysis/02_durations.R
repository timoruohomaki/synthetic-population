#!/usr/bin/env Rscript
# Case durations: censoring-aware survival model, phase decomposition by court,
# and recovery of the judgment-drafting backlog effect (Rocha et al.'s bottleneck).
source(file.path("analysis", "common.R"))
suppressPackageStartupMessages(library(survival))

survival_model <- function(con) {
  lc <- q(con, "SELECT l.*, d.page_count AS initial_pages FROM v_case_lifecycle l
                JOIN document d ON d.case_id = l.case_id AND d.document_type = 'INITIATING_DOCUMENT'")
  lc[, `:=`(court = factor(court_id), case_type = factor(case_type_code),
            efiling = as.integer(filing_channel == "EFILING"))]
  fit <- coxph(Surv(duration_days, event_observed) ~ court + case_type + efiling + needs_interpreter +
                 in_custody_at_filing + bulk_filed + log(initial_pages), data = lc)
  cat("== Cox model: time to disposition (HR > 1 = faster) ==\n")
  s <- summary(fit)$conf.int
  print(data.table(term = rownames(s), HR = fmt_fi(s[, 1]), lower95 = fmt_fi(s[, 3]), upper95 = fmt_fi(s[, 4])))
  cat(sprintf("Censored (open at cutoff): %s %%\n\n", fmt_fi(100 * mean(lc$event_observed == 0), 1)))
}

phase_profile <- function(con) {
  ph <- q(con, "SELECT p.case_id, p.phase, p.days_in_phase, l.court_id
                FROM v_case_phase_duration p JOIN v_case_lifecycle l ON l.case_id = p.case_id
                WHERE l.event_observed = 1 AND l.case_type_code IN ('CIV_DIS', 'CRIM_MH', 'FAM')")
  w <- dcast(ph, case_id + court_id ~ phase, value.var = "days_in_phase", fill = 0)
  cols <- setdiff(names(w), c("case_id", "court_id"))
  cat("== Mean days per phase, disposed CIV_DIS/CRIM_MH/FAM cases ==\n")
  print(w[, lapply(.SD, function(x) fmt_fi(mean(x), 1)), by = court_id, .SDcols = cols][order(court_id)])
}

#' Oracle recovery of deliberation parameters with nls on truth tables.
deliberation_recovery <- function(con) {
  d <- q(con, "
    SELECT tc.case_id, tc.deliberation_work_days AS work, tc.backlog_at_deliberation AS backlog,
           tc.latent_complexity AS cx, c.case_type_code, j.experience_years_at_start AS exper,
           (julianday(e.event_date) - julianday(r.start_date)) AS t_days
    FROM truth_case tc
    JOIN court_case c ON c.case_id = tc.case_id
    JOIN case_event e ON e.case_id = tc.case_id AND e.event_code = 'DELIBERATION_STARTED'
    JOIN judge j ON j.judge_id = e.judge_id
    CROSS JOIN sim_run r
    WHERE tc.deliberation_work_days IS NOT NULL
      AND COALESCE(c.disposition_code, '') <> 'DEFAULT_JUDGMENT'
      AND NOT EXISTS (SELECT 1 FROM case_event x WHERE x.case_id = tc.case_id AND x.event_code = 'NO_RESPONSE')")
  truth <- truth_param(con, "deliberation.")
  tr <- function(p) truth[parameter == p, value]
  d[, y := log(work) - (t_days / 365.25) * log(1 + tr("trend_per_year"))]
  d[, k := as.integer(factor(case_type_code))]
  start <- list(a = rep(1, max(d$k)), b = 0.5, cc = 0.01, e = 0)
  fit <- nls(y ~ a[k] + b * log(cx) + log(1 + cc * backlog) + e * (exper - 15) / 10, data = d, start = start)
  est <- coef(summary(fit))
  cat("\n== Deliberation drafting model (oracle nls) ==\n")
  print(data.table(parameter = c("complexity_exp", "backlog_coef", "experience_coef"),
                   truth = fmt_fi(c(tr("complexity_exp"), tr("backlog_coef"), tr("experience_coef"))),
                   estimate = fmt_fi(est[c("b", "cc", "e"), 1], 4),
                   std_error = fmt_fi(est[c("b", "cc", "e"), 2], 4)))
}

main <- function() {
  con <- open_db(); on.exit(dbDisconnect(con))
  survival_model(con)
  phase_profile(con)
  deliberation_recovery(con)
}

run_analysis(main)
