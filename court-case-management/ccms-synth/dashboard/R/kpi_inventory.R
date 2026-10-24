# Caseload inventory and flow KPIs (NCSC Model Reports 7-10, 14; CEPEJ) ----

#' Logical vector: case pending at the end of date `d`.
is_pending <- function(cases, d) {
  cases$filing_date <= d & (is.na(cases$disposition_date) | cases$disposition_date > d)
}

#' Report 7/9/10: begin pending, filed, disposed, end pending, change and clearance
#' for [from, to], grouped by `by` (character vector of column names, may be empty).
caseload_inventory <- function(cases, from, to, by = "case_type_code") {
  cs <- data.table::copy(cases)
  cs[, `:=`(begin = is_pending(cs, from - 1), end = is_pending(cs, to),
            filed = filing_date >= from & filing_date <= to,
            disposed = !is.na(disposition_date) & disposition_date >= from & disposition_date <= to)]
  out <- cs[, .(begin_pending = sum(begin), filed = sum(filed), disposed = sum(disposed),
                end_pending = sum(end)), by = by]
  out[, `:=`(change = end_pending - begin_pending,
             change_pct = data.table::fifelse(begin_pending > 0, (end_pending - begin_pending) / begin_pending, NA_real_),
             clearance_rate = data.table::fifelse(filed > 0, disposed / filed, NA_real_),
             share_of_filings = filed / sum(filed))]
  out[]
}

#' Monthly flow per group: incoming, resolved, end-of-month pending, clearance and
#' CEPEJ disposition time (pending / resolved x days in month).
monthly_flow <- function(cases, from, to, by = "court_code") {
  months <- seq(as.Date(format(from, "%Y-%m-01")), as.Date(format(to, "%Y-%m-01")), by = "month")
  ends <- c(months[-1] - 1, seq(months[length(months)], by = "month", length.out = 2)[2] - 1)
  rows <- lapply(seq_along(months), function(k) {
    m0 <- months[k]; m1 <- ends[k]
    cases[, .(incoming = sum(filing_date >= m0 & filing_date <= m1),
              resolved = sum(!is.na(disposition_date) & disposition_date >= m0 & disposition_date <= m1),
              pending_end = sum(filing_date <= m1 & (is.na(disposition_date) | disposition_date > m1))),
          by = by][, `:=`(month = m0, days = as.integer(m1 - m0) + 1L)]
  })
  out <- data.table::rbindlist(rows)
  out[, `:=`(clearance_rate = data.table::fifelse(incoming > 0, resolved / incoming, NA_real_),
             disposition_time = data.table::fifelse(resolved > 0, pending_end / resolved * days, NA_real_))]
  out[]
}

#' Headline KPIs for the overview tiles.
headline_kpis <- function(cases, from, to, as_of, standards) {
  inv <- caseload_inventory(cases, from, to, by = character(0))
  pend <- cases[is_pending(cases, as_of)]
  pend[, age := as.integer(as_of - filing_date)]
  pend[, std := unlist(standards)[case_type_code]]
  days <- as.integer(to - from) + 1L
  list(incoming = inv$filed, resolved = inv$disposed, clearance = inv$clearance_rate,
       pending = nrow(pend), pending_change = inv$change_pct,
       disposition_time = if (inv$disposed > 0) inv$end_pending / inv$disposed * days else NA_real_,
       over_standard = if (nrow(pend)) mean(pend$age > pend$std, na.rm = TRUE) else NA_real_,
       median_age = if (nrow(pend)) stats::median(pend$age) else NA_real_)
}

#' Report 14: number and percent change versus the same-length preceding period.
period_comparison <- function(cases, from, to, by = "case_type_code") {
  len <- as.integer(to - from) + 1L
  cur <- caseload_inventory(cases, from, to, by)[, c(by, "filed", "disposed"), with = FALSE]
  prev <- caseload_inventory(cases, from - len, from - 1, by)[, c(by, "filed", "disposed"), with = FALSE]
  out <- merge(cur, prev, by = by, suffixes = c("", "_prev"), all = TRUE)
  out[, `:=`(filed_change_pct = (filed - filed_prev) / filed_prev,
             disposed_change_pct = (disposed - disposed_prev) / disposed_prev)]
  out[]
}
