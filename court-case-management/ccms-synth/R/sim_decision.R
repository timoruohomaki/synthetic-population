# Deliberation (judgment drafting queue per judge) and disposition ----------

#' Drafting effort grows with the judge's pending judgments (bottleneck noted by
#' Rocha et al.), complexity, inexperience and the secular trend.
on_delib_start <- function(st, i, d, disp_code) {
  if (st$cv$disposed[i]) return(invisible())
  set_status(st, i, d, "DELIBERATION")
  log_event(st, i, d, "DELIBERATION_STARTED")
  j <- st$cv$judge[i]
  e <- st$cfg$effects$deliberation
  tp <- st$cfg$case_types[[st$cs$case_type_code[i]]]
  backlog <- st$jv$pending[j]
  exper <- st$ref$judges$experience_years[j]
  tf <- trend_factor(st, d, "deliberation")
  noise <- stats::rlnorm(1, -e$noise_sdlog^2 / 2, e$noise_sdlog)
  work <- if (disp_code == DISP[["DEFAULT_JUDGMENT"]]) {
    1 + stats::rexp(1, 1) * (1 + e$backlog_coef * backlog)
  } else {
    tp$delib_days * st$cs$complexity[i]^e$complexity_exp * (1 + e$backlog_coef * backlog) *
      exp(e$experience_coef * (exper - 15) / 10) * tf * noise
  }
  start <- d
  until <- st$absent_until[j, d + 1L]
  if (until >= 0) start <- until + 1L
  end <- add_work_days(st$cal, min(start, st$n_days - 1L), work)
  sadd(st$jv, "pending", j, +1L)
  put_truth(st, i, "deliberation_work_days", round(work, 2))
  put_truth(st, i, "backlog_at_deliberation", backlog)
  if (start > d) record_delay(st, i, d, start, "COURT", "JUDGE_ABSENT_DRAFTING")
  target <- if (st$cs$category[i] == "CRIMINAL") 14L else 30L
  rec_push(st$R$deadline, case_id = i, deadline_type = "JUDGMENT_TARGET", set_day = as.integer(d),
           due_day = as.integer(d + target), met_day = as.integer(end), extended_days = 0L,
           responsible = "COURT")
  record_delay(st, i, d + target, end, "COURT", "JUDGMENT_OVERDUE")
  schedule_event(st, end, i, EV[["JUDGMENT"]], disp_code)
}

on_judgment <- function(st, i, d, disp_code) {
  j <- st$cv$judge[i]
  sadd(st$jv, "pending", j, -1L)
  close_case(st, i, d, names(DISP)[disp_code])
}

on_dispose <- function(st, i, d, disp_code) {
  if (st$cv$disposed[i]) return(invisible())
  close_case(st, i, d, names(DISP)[disp_code])
}
