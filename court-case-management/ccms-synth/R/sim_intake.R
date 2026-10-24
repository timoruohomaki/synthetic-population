# Intake handlers: filing, registration, first appearance, service ---------

DISP <- c(JUDGMENT = 1L, WRITTEN_DECISION = 2L, DEFAULT_JUDGMENT = 3L, SETTLED = 4L,
          WITHDRAWN = 5L, GUILTY_PLEA = 6L)

on_file <- function(st, i, d) {
  set_status(st, i, d, "FILED")
  log_event(st, i, d, "CASE_FILED", detail = st$cs$filing_channel[i])
  if (isTRUE(st$cs$in_custody_at_filing[i])) {
    sput(st$cv, "custody_row", i, rec_push(st$R$custody, case_id = i, from_day = as.integer(d)))
    data.table::set(st$cs, i = i, j = "in_custody_now", value = TRUE)
  }
  reg_day <- next_working_day(st$cal, d + ceiling(st$truth$reg_lag_days[i]))
  schedule_event(st, reg_day, i, EV[["REGISTER"]])
}

on_register <- function(st, i, d) {
  data.table::set(st$cs, i = i, j = "registration_day", value = as.integer(d))
  log_event(st, i, d, "CASE_REGISTERED")
  assign_judge(st, i, d, "INITIAL")
  if (st$cs$category[i] == "CRIMINAL") {
    set_status(st, i, d, "AWAITING_FIRST_APPEAR")
    fa <- book_first_appearance(st, i, d + if (st$cs$in_custody_now[i]) 1L else 7L)
    schedule_event(st, fa, i, EV[["FIRST_APPEAR"]])
    return(invisible())
  }
  set_status(st, i, d, "SERVICE")
  log_event(st, i, d, "SERVICE_ISSUED")
  if (st$cs$early_resolution[i]) {
    schedule_event(st, d + sample(5:40, 1), i, EV[["DISPOSE"]], DISP[["WITHDRAWN"]])
    return(invisible())
  }
  s <- st$cfg$effects$service
  base <- if (st$cs$filing_channel[i] == "EFILING") s$days_efiling else s$days_paper
  p_fail <- s$unreachable_prob * if (is.na(st$cs$respondent_counsel_id[i])) 1 else s$unreachable_counsel_mult
  fails <- 0L
  while (fails < s$max_retries && stats::runif(1) < p_fail) fails <- fails + 1L
  for (k in seq_len(fails)) log_event(st, i, d + base + (k - 1) * s$retry_days, "SERVICE_FAILED")
  served <- d + base + fails * s$retry_days + stats::rpois(1, 2)
  record_delay(st, i, d + base, d + base + fails * s$retry_days, "RESPONDENT", "SERVICE_EVASION")
  put_truth(st, i, "unreachable_attempts", fails)
  put_truth(st, i, "service_days", served - d)
  schedule_event(st, served, i, EV[["SERVED"]])
}

on_first_appearance <- function(st, i, d) {
  data.table::set(st$cs, i = i, j = "first_appearance_day", value = as.integer(d))
  log_event(st, i, d, "FIRST_APPEARANCE")
  e <- st$cfg$effects$first_appearance
  if (!is.na(st$cv$custody_row[i]) && stats::runif(1) < e$custody_release_prob) {
    end_custody(st, i, d, "RELEASED")
    data.table::set(st$cs, i = i, j = "in_custody_now", value = FALSE)
    log_event(st, i, d, "CUSTODY_RELEASED")
  }
  if (st$cs$early_resolution[i]) {
    disp <- if (stats::runif(1) < e$early_plea_share) "GUILTY_PLEA" else "WITHDRAWN"
    return(close_case(st, i, d, disp))
  }
  on_prep_start(st, i, d)
}

on_served <- function(st, i, d) {
  log_event(st, i, d, "SERVED")
  set_status(st, i, d, "AWAITING_RESPONSE")
  tp <- st$cfg$case_types[[st$cs$case_type_code[i]]]
  ext_e <- if (st$cs$filing_channel[i] == "EFILING") st$cfg$effects$service$electronic_act_extension_days else 0
  due <- d + tp$response_days + ext_e
  if (!st$cs$contested[i]) {
    rec_push(st$R$deadline, case_id = i, deadline_type = "RESPONSE", set_day = as.integer(d),
             due_day = as.integer(due), extended_days = 0L, responsible = "RESPONDENT")
    log_event(st, i, due + 1L, "NO_RESPONSE")
    return(schedule_event(st, due + 1L, i, EV[["DELIB_START"]], DISP[["DEFAULT_JUDGMENT"]]))
  }
  r <- st$cfg$effects$response
  ext <- if (stats::runif(1) < r$extension_prob) r$extension_days else 0L
  if (ext > 0) {
    log_event(st, i, due - 2L, "RESPONSE_EXTENDED")
    record_delay(st, i, due, due + ext, "RESPONDENT", "RESPONSE_EXTENSION")
  }
  filed <- d + round(stats::runif(1, 0.6, 1) * (due + ext - d))
  rec_push(st$R$deadline, case_id = i, deadline_type = "RESPONSE", set_day = as.integer(d),
           due_day = as.integer(due + ext), met_day = as.integer(filed), extended_days = as.integer(ext),
           responsible = "RESPONDENT")
  log_event(st, i, filed, "RESPONSE_FILED")
  schedule_event(st, filed, i, EV[["PREP_START"]])
}
