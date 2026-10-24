# Small state-changing actions shared by event handlers ---------------------

log_event <- function(st, i, day, code, hearing_id = NA_integer_, detail = NA_character_) {
  rec_push(st$R$event, case_id = i, day = as.integer(day), event_code = code,
           judge_id = st$cv$judge[i], hearing_id = hearing_id, detail = detail)
}

set_status <- function(st, i, day, status) {
  if (!identical(st$cv$status[i], status)) {
    rec_push(st$R$status, case_id = i, day = as.integer(day), status_code = status)
    sput(st$cv, "status", i, status)
  }
}

add_truth <- function(st, i, field, value) {
  old <- st$truth[[field]][i]
  data.table::set(st$truth, i = i, j = field, value = if (is.na(old)) value else old + value)
}

put_truth <- function(st, i, field, value) data.table::set(st$truth, i = i, j = field, value = value)

record_delay <- function(st, i, from, to, attribution, cause) {
  if (!is.na(from) && !is.na(to) && to > from) {
    rec_push(st$R$delay, case_id = i, from_day = as.integer(from), to_day = as.integer(to),
             attribution = attribution, cause_code = cause)
  }
}

#' Assign (or reassign) the least-loaded present judge of the case's court.
assign_judge <- function(st, i, day, reason) {
  court <- st$cs$court_id[i]
  cand <- st$ref$judges$judge_id[st$ref$judges$court_id == court]
  old <- st$cv$judge[i]
  present <- cand[!st$absent[cand, day + 1L] & cand != ifelse(is.na(old), -1L, old)]
  if (length(present) == 0) present <- cand
  load <- st$jv$active[present]
  pick <- present[load == min(load)]
  j <- if (length(pick) == 1) pick else sample(pick, 1)
  if (!is.na(old)) {
    rec_set(st$R$assign, st$cv$assign_row[i], "to_day", as.integer(day))
    sadd(st$jv, "active", old, -1L)
    put_truth(st, i, "reassigned", TRUE)
  }
  sadd(st$jv, "active", j, +1L)
  sput(st$cv, "judge", i, j)
  row <- rec_push(st$R$assign, case_id = i, judge_id = j, from_day = as.integer(day),
                  to_day = NA_integer_, reason = reason)
  sput(st$cv, "assign_row", i, row)
  log_event(st, i, day, if (is.na(old)) "JUDGE_ASSIGNED" else "JUDGE_REASSIGNED", detail = reason)
  j
}

#' Reassign when the judge is on a long absence at `day`; returns extra lead days.
maybe_reassign <- function(st, i, day) {
  j <- st$cv$judge[i]
  until <- st$absent_until[j, day + 1L]
  if (until >= 0 && until - day >= st$cfg$absence$reassign_if_remaining_days) {
    assign_judge(st, i, day, "JUDGE_LONG_ABSENCE")
    return(st$cfg$absence$familiarisation_days)
  }
  0L
}

#' Close the case: free judge load, end custody, vacate any scheduled hearing.
close_case <- function(st, i, day, disposition) {
  if (st$cv$disposed[i]) return(invisible(FALSE))
  sput(st$cv, "disposed", i, TRUE)
  j <- st$cv$judge[i]
  if (!is.na(j)) sadd(st$jv, "active", j, -1L)
  if (!is.na(st$cv$assign_row[i])) rec_set(st$R$assign, st$cv$assign_row[i], "to_day", as.integer(day))
  if (!is.na(st$cv$custody_row[i])) end_custody(st, i, day, "DISPOSITION")
  h <- st$cv$hrow[i]
  if (!is.na(h) && rec_get(st$R$hearing, "hearing_day", h) > day) release_hearing(st, i, h, day)
  log_event(st, i, day, "CASE_DISPOSED", detail = disposition)
  set_status(st, i, day, "DISPOSED")
  data.table::set(st$cs, i = i, j = "disposition_code", value = disposition)
  data.table::set(st$cs, i = i, j = "disposition_day", value = as.integer(day))
  invisible(TRUE)
}

end_custody <- function(st, i, day, reason) {
  r <- st$cv$custody_row[i]
  rec_set(st$R$custody, r, "to_day", as.integer(day))
  rec_set(st$R$custody, r, "end_reason", reason)
  sput(st$cv, "custody_row", i, NA_integer_)
}
