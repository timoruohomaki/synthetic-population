# Output case tables (everything censored at the cutoff date) --------------

build_status_history <- function(st, cfg) {
  s <- rec_to_dt(st$R$status)[day <= cutoff_day(cfg)]
  s[, seq := seq_len(.N)]
  data.table::setorder(s, case_id, day, seq)
  s[, next_day := data.table::shift(day, type = "lead"), by = case_id]
  s[, .(status_history_id = seq_len(.N), case_id, status_code,
        valid_from = iso_date(day, cfg), valid_to = iso_date(next_day, cfg))]
}

build_court_case <- function(st, cfg, status_hist) {
  cs <- st$cs; cut <- cutoff_day(cfg)
  last_status <- status_hist[, .(case_status = status_code[.N]), by = case_id]
  prosecution <- st$ref$litigants[litigant_type == "PUBLIC_AUTHORITY", litigant_id][1]
  out <- cs[, .(case_id, case_number = case_numbers(cs, st$ref$courts, cfg), court_id, case_type_code, category,
    filing_date = iso_date(filing_day, cfg), filing_channel,
    registration_date = iso_date(registration_day, cfg, TRUE),
    first_appearance_date = iso_date(first_appearance_day, cfg, TRUE),
    initiating_litigant_id = data.table::fifelse(category == "CRIMINAL", prosecution, bulk_litigant_id),
    claim_amount_eur, n_charges, n_respondents, interpreter_language, in_custody_at_filing,
    disposition_code = data.table::fifelse(!is.na(disposition_day) & disposition_day <= cut, disposition_code, NA_character_),
    disposition_date = iso_date(disposition_day, cfg, TRUE))]
  out <- merge(out, last_status, by = "case_id", all.x = TRUE)
  out[, is_open_at_cutoff := is.na(disposition_date)]
  out[]
}

build_parties <- function(st) {
  cs <- st$cs
  claim <- cs[, .(case_id, party_seq = 1L,
    party_role = data.table::fifelse(category == "CRIMINAL", "PROSECUTOR", "CLAIMANT"),
    party_type = data.table::fcase(category == "CRIMINAL", "PUBLIC_AUTHORITY", !is.na(bulk_litigant_id), "ORGANISATION",
                                   default = "PERSON"),
    litigant_id = data.table::fifelse(category == "CRIMINAL", max(st$ref$litigants$litigant_id), bulk_litigant_id),
    counsel_id = claimant_counsel_id, self_represented = category == "NON_CRIMINAL" & is.na(claimant_counsel_id) & is.na(bulk_litigant_id),
    interpreter_language = NA_character_, in_custody_at_filing = FALSE)]
  resp <- cs[rep(seq_len(.N), n_respondents)]
  resp[, party_seq := 1L + seq_len(.N), by = case_id]
  resp <- resp[, .(case_id, party_seq,
    party_role = data.table::fifelse(category == "CRIMINAL", "DEFENDANT", "RESPONDENT"),
    party_type = data.table::fifelse(category == "NON_CRIMINAL" & stats::runif(.N) < 0.3, "ORGANISATION", "PERSON"),
    litigant_id = NA_integer_, counsel_id = respondent_counsel_id, self_represented,
    interpreter_language = data.table::fifelse(party_seq == 2L, interpreter_language, NA_character_),
    in_custody_at_filing = party_seq == 2L & in_custody_at_filing)]
  p <- rbind(claim, resp)
  data.table::setorder(p, case_id, party_seq)
  p[, party_id := seq_len(.N)]
  data.table::setcolorder(p, "party_id")
  p[]
}

build_assignments <- function(st, cfg) {
  a <- rec_to_dt(st$R$assign)[from_day <= cutoff_day(cfg)]
  a[, .(assignment_id = seq_len(.N), case_id, judge_id, start_date = iso_date(from_day, cfg),
        end_date = iso_date(to_day, cfg, TRUE), assignment_reason = reason)]
}

#' Docket entries with RFC 3339 timestamps (local business hours, ordered within day).
build_events <- function(st, cfg) {
  e <- rec_to_dt(st$R$event)[day <= cutoff_day(cfg)]
  e[, seq := seq_len(.N)]
  data.table::setorder(e, case_id, day, seq)
  e[, rank := seq_len(.N), by = .(case_id, day)]
  e[, event_ts := rfc3339_utc(day, pmin(16.5, 8.5 + 0.25 * (rank - 1)), cfg)]
  e[, .(event_id = seq_len(.N), case_id, event_code, event_date = iso_date(day, cfg), event_ts,
        judge_id, hearing_id, detail)]
}

DOC_MAP <- c(CASE_FILED = "INITIATING_DOCUMENT", RESPONSE_FILED = "RESPONSE", EXPERT_REPORT_FILED = "EXPERT_REPORT",
             MOTION_FILED = "MOTION", APPEAL_FILED = "APPEAL_NOTICE", HEARING_HELD = "HEARING_MINUTES",
             CASE_DISPOSED = "DECISION")

build_documents <- function(events, st) {
  d <- events[event_code %in% names(DOC_MAP)]
  d <- d[!(event_code == "CASE_DISPOSED" & detail %in% c("SETTLED", "WITHDRAWN"))]
  cx <- st$cs$complexity[d$case_id]
  d[, .(document_id = seq_len(.N), case_id, event_id, document_type = DOC_MAP[event_code],
        filed_ts = event_ts, page_count = pmax(1L, as.integer(round(stats::rlnorm(.N, log(4 * cx), 0.6)))))]
}
