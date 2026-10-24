# Caseflow and delay KPIs (NCSC Figure 10; Clarke & Metzler; Jordan attribution)

PHASE_ORDER <- c("INTAKE", "SERVICE", "PREPARATION", "HEARING", "DECISION")
ATTR_ORDER <- c("COURT", "DEFENCE", "RESPONDENT", "PROSECUTION", "CLAIMANT", "THIRD_PARTY", "JOINT")

#' Mean days per phase for cases disposed in [from, to] (where did the time go?).
phase_profile <- function(cases, phase, from, to, by = "court_code") {
  ids <- cases[!is.na(disposition_date) & disposition_date >= from & disposition_date <= to, case_id]
  if (length(ids) == 0) return(data.table::data.table())
  ph <- phase[case_id %in% ids]
  full <- data.table::CJ(case_id = ids, phase = PHASE_ORDER)
  full <- merge(full, ph, by = c("case_id", "phase"), all.x = TRUE)
  full[is.na(days_in_phase), days_in_phase := 0]
  full <- merge(full, cases[, c("case_id", by), with = FALSE], by = "case_id")
  out <- full[, .(mean_days = mean(days_in_phase)), by = c(by, "phase")]
  out[, phase := factor(phase, levels = PHASE_ORDER)][order(get(by[1]), phase)]
}

#' Delay days by responsible party for delay periods starting in [from, to].
delay_attribution <- function(delays, case_ids, from, to, by = "court_code") {
  x <- delays[case_id %in% case_ids & start_date >= from & start_date <= to]
  if (nrow(x) == 0) return(data.table::data.table())
  out <- x[, .(delay_days = sum(delay_days), periods = .N), by = c(by, "attribution_code")]
  out[, attribution_code := factor(attribution_code, levels = ATTR_ORDER)][order(get(by[1]), attribution_code)]
}

#' Monthly hearing outcomes: adjournment rate and mean calendar-queue wait.
hearing_monthly <- function(hearings, case_ids, from, to, by = "court_code") {
  h <- hearings[case_id %in% case_ids & hearing_date >= from & hearing_date <= to &
                outcome %in% c("HELD", "ADJOURNED")]
  h[, month := as.Date(format(hearing_date, "%Y-%m-01"))]
  h[, .(hearings = .N, adjournment_rate = mean(outcome == "ADJOURNED"),
        mean_wait = mean(as.numeric(hearing_date - earliest_possible_date))), by = c(by, "month")][order(month)]
}

adjournment_reasons <- function(hearings, case_ids, from, to, reasons) {
  h <- hearings[case_id %in% case_ids & hearing_date >= from & hearing_date <= to & outcome == "ADJOURNED"]
  if (nrow(h) == 0) return(data.table::data.table())
  out <- h[, .N, by = .(reason_code = adjournment_reason_code)]
  out <- merge(out, reasons[, .(reason_code, description, attribution_code)], by = "reason_code")
  out[, share := N / sum(N)][order(-N)]
}

#' Median / p90 time intervals between key events for cases disposed in [from, to].
event_intervals <- function(cases, hearings, from, to) {
  d <- cases[!is.na(disposition_date) & disposition_date >= from & disposition_date <= to]
  first_h <- hearings[outcome %in% c("HELD", "ADJOURNED"), .(first_hearing = min(hearing_date),
                      last_held = suppressWarnings(max(hearing_date[outcome == "HELD"]))), by = case_id]
  d <- merge(d, first_h, by = "case_id", all.x = TRUE)
  d[is.infinite(last_held), last_held := NA]
  iv <- list(
    "Filing → registration" = d$registration_date - d$filing_date,
    "Filing → first appearance (queue time)" = d$first_appearance_date - d$filing_date,
    "Registration → first hearing" = d$first_hearing - d$registration_date,
    "Last hearing held → disposition (drafting)" = d$disposition_date - d$last_held,
    "Filing → disposition" = d$disposition_date - d$filing_date)
  data.table::rbindlist(lapply(names(iv), function(nm) {
    x <- as.numeric(iv[[nm]]); x <- x[!is.na(x)]
    data.table::data.table(interval = nm, cases = length(x),
      median = if (length(x)) stats::median(x) else NA_real_,
      p90 = if (length(x)) as.numeric(stats::quantile(x, 0.9)) else NA_real_)
  }))
}
