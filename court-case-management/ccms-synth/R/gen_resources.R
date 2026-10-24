# Court-month resource inputs (staffing, budget, e-filing adoption) --------

#' Monthly resource drivers per court. Clerk vacancy follows a bounded random walk;
#' e-filing adoption follows a logistic curve between efiling_start and efiling_end.
gen_resource_months <- function(ref, cal, cfg) {
  months <- seq(cfg$run$start, cfg$run$cutoff, by = "month")
  n_m <- length(months)
  sd_v <- cfg$capacity$clerk_vacancy_sd
  out <- lapply(seq_len(nrow(ref$courts)), function(i) {
    ct <- ref$courts[i]
    vac <- numeric(n_m)
    vac[1] <- 0.05
    for (m in seq_len(n_m)[-1]) vac[m] <- min(0.35, max(0, vac[m - 1] + stats::rnorm(1, 0, sd_v)))
    x <- seq(-4, 4, length.out = n_m)
    adopt <- ct$efiling_start + (ct$efiling_end - ct$efiling_start) / (1 + exp(-x))
    budget <- ct$budget_eur_month * cumprod(c(1, rep(1 + 0.02 / 12, n_m - 1))) *
      stats::rnorm(n_m, 1, 0.01)
    data.table::data.table(court_id = ct$court_id, month_start = months, month_index = seq_len(n_m) - 1L,
      clerks_fte = round(ct$clerks * (1 - vac), 2), clerk_vacancy_rate = round(vac, 3),
      efiling_target_rate = adopt, budget_eur = round(budget, 2), it_budget_share = ct$it_share,
      population = ct$population)
  })
  rm <- data.table::rbindlist(out)
  rm[, month_key := format(month_start, "%Y-%m")]
  rm[]
}

#' Average judge FTE per court-month after absences (computed once absences exist).
judge_fte_by_month <- function(ref, cal) {
  absent <- ref$absences[, .(day = seq(start_day, end_day)), by = .(absence_id, judge_id)]
  absent <- unique(absent[, .(judge_id, day)])
  base <- data.table::CJ(judge_id = ref$judges$judge_id, day = cal[is_working_day == TRUE, day])
  base[absent, on = .(judge_id, day), absent := TRUE]
  base[is.na(absent), absent := FALSE]
  base[cal, on = "day", month_key := format(i.date, "%Y-%m")]
  base <- merge(base, ref$judges[, .(judge_id, court_id)], by = "judge_id")
  base[, .(judges_fte = round(sum(!absent) / data.table::uniqueN(day), 2)),
       by = .(court_id, month_key)]
}
