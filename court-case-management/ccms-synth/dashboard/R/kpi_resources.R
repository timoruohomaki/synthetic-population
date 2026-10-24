# Judge workload, resources and projections (NCSC Model Reports 13 and 19) --

#' Report 13: caseload per judge - open cases at `as_of`, hearings held and
#' decisions issued in [from, to] (by the judge holding the case at disposition).
judge_caseload <- function(cases, assignments, hearings, judges, courts, from, to, as_of) {
  open <- assignments[case_id %in% cases$case_id & start_date <= as_of & (is.na(end_date) | end_date > as_of),
                      .(open_cases = .N), by = judge_id]
  held <- hearings[case_id %in% cases$case_id & outcome == "HELD" & hearing_date >= from & hearing_date <= to,
                   .(hearings_held = .N), by = judge_id]
  dec <- cases[!is.na(disposition_date) & disposition_date >= from & disposition_date <= to &
               disposition_code %in% c("JUDGMENT", "WRITTEN_DECISION", "DEFAULT_JUDGMENT"),
               .(decisions = .N), by = judge_id]
  out <- merge(judges[, .(judge_id, court_id, judge_code)], courts[, .(court_id, court_code)], by = "court_id")
  for (x in list(open, held, dec)) out <- merge(out, x, by = "judge_id", all.x = TRUE)
  for (cl in c("open_cases", "hearings_held", "decisions")) out[is.na(get(cl)), (cl) := 0L]
  out[order(court_code, -open_cases)]
}

#' Resource panel for the selected courts and months.
resource_panel <- function(panel, courts, court_codes, from, to) {
  p <- merge(panel, courts[, .(court_id, court_code)], by = "court_id")
  p[court_code %in% court_codes & month_start_date >= as.Date(format(from, "%Y-%m-01")) & month_start_date <= to]
}

#' Report 19: project end-of-month pending caseload per group with a linear trend
#' fitted on the last `fit_months` complete months, with a prediction interval.
project_pending <- function(flow, by = "court_code", fit_months = 12, horizon = 12, level = 0.8) {
  groups <- unique(flow[[by]])
  data.table::rbindlist(lapply(groups, function(g) {
    h <- flow[get(by) == g][order(month)]
    fit_data <- tail(h, fit_months)
    if (nrow(fit_data) < 3) return(NULL)
    fit_data[, t := seq_len(.N)]
    fit <- stats::lm(pending_end ~ t, data = fit_data)
    fut <- data.table::data.table(t = nrow(fit_data) + seq_len(horizon))
    pr <- stats::predict(fit, newdata = fut, interval = "prediction", level = level)
    last <- max(h$month)
    proj <- data.table::data.table(month = seq(last, by = "month", length.out = horizon + 1)[-1],
      pending_end = pr[, "fit"], lower = pmax(0, pr[, "lwr"]), upper = pr[, "upr"], type = "projection")
    hist <- h[, .(month, pending_end, lower = NA_real_, upper = NA_real_, type = "actual")]
    out <- rbind(hist, proj)
    out[, (by) := g]
    out[, slope_per_month := stats::coef(fit)[["t"]]]
    out[]
  }))
}
