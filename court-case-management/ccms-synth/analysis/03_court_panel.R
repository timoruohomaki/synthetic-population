#!/usr/bin/env Rscript
# Court x month panel: replicate the Rocha et al. design (efficiency indicators on
# e-filing rate + resource controls, court and year fixed effects) and check
# Little's Law (pending = arrival rate x time in system) as in Clarke & Metzler.
source(file.path("analysis", "common.R"))

panel_regressions <- function(con) {
  p <- q(con, "SELECT * FROM v_court_month_indicators")
  # Drop the first 6 months (system filling up) and the post-filing tail.
  p <- p[period_month >= "2023-07" & period_month <= "2025-12" & !is.na(efiling_rate)]
  p[, `:=`(court = factor(court_id), year = factor(substr(period_month, 1, 4)),
           budget_meur = budget_eur / 1e6, efiling_pct = 100 * efiling_rate)]
  outcomes <- c(mean_duration_resolved = "Length of proceedings (days)",
                clearance_rate = "Clearance rate", pending_end = "Pending cases (end of month)")
  cat("== Fixed-effects panel (court + year FE), coefficient of e-filing rate (per 1 pp) ==\n")
  res <- rbindlist(lapply(names(outcomes), function(y) {
    f <- as.formula(paste(y, "~ efiling_pct + judges_fte + clerks_fte + budget_meur +",
                          "litigation_per_100k_annualised + court + year"))
    fit <- lm(f, data = p)
    s <- coef(summary(fit))
    data.table(outcome = outcomes[[y]], efiling_coef = fmt_fi(s["efiling_pct", 1], 4),
               std_error = fmt_fi(s["efiling_pct", 2], 4), p_value = fmt_fi(s["efiling_pct", 4], 3),
               clerks_coef = fmt_fi(s["clerks_fte", 1], 3), judges_coef = fmt_fi(s["judges_fte", 1], 3),
               n = nrow(p), r2 = fmt_fi(summary(fit)$r.squared, 3))
  }))
  print(res)
  cat("Note: in the generator e-filing only shortens registration/service (and adds an\n",
      "electronic-act extension to response deadlines); hearing and drafting queues are unaffected.\n",
      "Non-zero coefficients here are confounding: adoption and backlog both trend upward within\n",
      "courts, which year dummies absorb only partly - the same identification issue as in panel studies.\n\n")
}

littles_law <- function(con) {
  lc <- q(con, "SELECT court_id, filing_date, disposition_date, duration_days, event_observed
                FROM v_case_lifecycle")
  k <- q(con, "SELECT court_id, period_month, pending_end FROM v_court_month_kpi")
  lc[, year := substr(filing_date, 1, 4)]
  k[, year := substr(period_month, 1, 4)]
  arr <- lc[year %in% c("2024", "2025"), .(lambda_per_day = .N / 365,
            mean_time_in_system = mean(duration_days)), by = .(court_id, year)]
  pend <- k[year %in% c("2024", "2025"), .(mean_pending = mean(pending_end)), by = .(court_id, year)]
  x <- merge(arr, pend, by = c("court_id", "year"))
  x[, implied_time_in_system := mean_pending / lambda_per_day]
  cat("== Little's Law check: L = lambda x W ==\n")
  print(x[, .(court_id, year, lambda_per_day = fmt_fi(lambda_per_day, 2), mean_pending = fmt_fi(mean_pending, 0),
              W_observed = fmt_fi(mean_time_in_system, 1), W_implied = fmt_fi(implied_time_in_system, 1))])
  cat("W_observed uses cases filed in the year (open ones censored at cutoff), so it is a lower bound.\n")
}

main <- function() {
  con <- open_db(); on.exit(dbDisconnect(con))
  panel_regressions(con)
  littles_law(con)
}

run_analysis(main)
