# Age, dispositions, status and exception KPIs (NCSC Model Reports 11, 20-27)

#' Bucket labels from upper bounds, e.g. c(90, 180) -> "0-90", "91-180", ">180".
age_labels <- function(breaks) {
  lo <- c(0, head(breaks, -1) + 1)
  c(paste0(lo, "–", breaks), paste0(">", tail(breaks, 1)))
}

age_bucket <- function(age, breaks) {
  factor(findInterval(age, breaks + 1e-9, left.open = FALSE) + 1L,
         levels = seq_len(length(breaks) + 1L), labels = age_labels(breaks))
}

#' Report 20: age of pending cases at `as_of` by group and bucket, with median age.
age_of_pending <- function(cases, as_of, breaks, by = "case_type_code") {
  p <- cases[is_pending(cases, as_of)]
  if (nrow(p) == 0) return(data.table::data.table())
  p[, `:=`(age = as.integer(as_of - filing_date))]
  p[, bucket := age_bucket(age, breaks)]
  out <- p[, .N, by = c(by, "bucket")]
  out[, share := N / sum(N), by = by]
  med <- p[, .(total = .N, median_age = as.numeric(stats::median(age))), by = by]
  merge(out, med, by = by)[order(get(by[1]), bucket)]
}

#' Reports 21/22: age of cases at disposition by manner of disposition.
age_at_disposition <- function(cases, from, to, by = c("case_type_code", "disposition_code")) {
  d <- cases[!is.na(disposition_date) & disposition_date >= from & disposition_date <= to]
  d[, age := as.integer(disposition_date - filing_date)]
  d[, .(n = .N, mean = mean(age), median = as.numeric(stats::median(age)),
        p90 = as.numeric(stats::quantile(age, 0.9))), by = by][order(get(by[1]), -n)]
}

#' Reports 11/17: manner of disposition per month.
disposition_mix <- function(cases, from, to) {
  d <- cases[!is.na(disposition_date) & disposition_date >= from & disposition_date <= to]
  d[, month := as.Date(format(disposition_date, "%Y-%m-01"))]
  d[, .N, by = .(month, disposition_code)][order(month)]
}

#' Share of cases disposed within the time standard (performance measure).
standard_compliance <- function(cases, from, to, standards, by = "case_type_code") {
  d <- cases[!is.na(disposition_date) & disposition_date >= from & disposition_date <= to]
  d[, within := as.integer(disposition_date - filing_date) <= unlist(standards)[case_type_code]]
  d[, .(disposed = .N, within_standard = mean(within)), by = by][order(get(by[1]))]
}

#' Status of every pending case at `as_of` from the status history (Reports 23/26).
status_at <- function(status_hist, case_ids, as_of) {
  s <- status_hist[case_id %in% case_ids & valid_from <= as_of & (is.na(valid_to) | valid_to > as_of)]
  s[order(case_id, -status_history_id)][, .SD[1], by = case_id][, .(case_id, status_code)]
}

#' Reports 25/27: pending cases older than their time standard, case by case,
#' with current status and the next scheduled hearing after `as_of`.
exception_list <- function(cases, status_hist, hearings, judges, as_of, standards) {
  p <- cases[is_pending(cases, as_of)]
  p[, `:=`(age = as.integer(as_of - filing_date), standard = unlist(standards)[case_type_code])]
  p <- p[!is.na(standard) & age > standard]
  if (nrow(p) == 0) return(data.table::data.table())
  p <- merge(p, status_at(status_hist, p$case_id, as_of), by = "case_id", all.x = TRUE)
  nxt <- hearings[case_id %in% p$case_id & scheduled_on_date <= as_of & hearing_date > as_of &
                  outcome != "VACATED"][, .(next_hearing = min(hearing_date)), by = case_id]
  p <- merge(p, nxt, by = "case_id", all.x = TRUE)
  p <- merge(p, judges[, .(judge_id, judge_code)], by = "judge_id", all.x = TRUE)
  p[, over_by := age - standard]
  p[order(-over_by), .(case_number, court_code, case_type_code, filing_date, age, standard, over_by,
                       status_code, next_hearing, judge_code)]
}
