# Preparation: disclosure, motions/interlocutory appeals, expert reports ----

trend_factor <- function(st, d, which) {
  rate <- st$cfg$effects[[which]]$trend_per_year
  (1 + rate)^(d / 365.25)
}

on_prep_start <- function(st, i, d) {
  set_status(st, i, d, "PREPARATION")
  tp <- st$cfg$case_types[[st$cs$case_type_code[i]]]
  e <- st$cfg$effects$preparation
  tf <- trend_factor(st, d, "preparation")
  put_truth(st, i, "trend_factor", round(tf, 4))
  total <- tp$prep_days * st$cs$complexity[i] * tf * stats::rlnorm(1, -e$noise_sdlog^2 / 2, e$noise_sdlog)
  if (isTRUE(st$cs$prep_hearing[i]) && st$cs$needs_main_hearing[i]) {
    sput(st$cv, "prep_rest", i, total * 0.6)
    return(schedule_event(st, d + total * 0.4, i, EV[["REQ_HEARING"]], 1L))
  }
  continue_prep(st, i, d, total)
}

#' Run the remaining preparation sub-phases sequentially and decide what follows.
continue_prep <- function(st, i, d, days) {
  set_status(st, i, d, "PREPARATION")
  cs <- st$cs; cat <- cs$category[i]
  defence <- if (cat == "CRIMINAL") "DEFENCE" else "RESPONDENT"
  t <- d + max(1, round(days))
  add_truth(st, i, "prep_days", t - d)
  e <- st$cfg$effects
  if (cat == "CRIMINAL" && cs$needs_main_hearing[i] && stats::runif(1) < e$preparation$disclosure_late_prob) {
    late <- round(stats::rexp(1, 1 / e$preparation$disclosure_late_days))
    log_event(st, i, t, "DISCLOSURE_LATE")
    record_delay(st, i, t, t + late, "PROSECUTION", "DISCLOSURE_LATE")
    t <- t + late
  }
  m <- e$motion
  lp <- m$intercept + m$complexity_coef * log(cs$complexity[i]) +
    m$counsel_coef * (!is.na(cs$respondent_counsel_id[i])) + m$bulk_coef * (!is.na(cs$bulk_litigant_id[i]))
  if (cs$needs_main_hearing[i] && stats::runif(1) < stats::plogis(lp)) {
    t0 <- t
    set_status(st, i, t, "MOTION_PENDING"); log_event(st, i, t, "MOTION_FILED")
    t <- t + round(stats::rgamma(1, 3, 3 / m$decision_days))
    log_event(st, i, t, "MOTION_DECIDED")
    appeal <- stats::runif(1) < m$appeal_prob
    rec_push(st$R$motion, case_id = i, motion_type = "PROCEDURAL_OBJECTION", filed_by = defence,
             filed_day = as.integer(t0), decided_day = as.integer(t), outcome = "DISMISSED")
    if (appeal) {
      set_status(st, i, t, "STAYED_APPEAL"); log_event(st, i, t, "APPEAL_FILED")
      t1 <- t; t <- t + round(stats::rgamma(1, 4, 4 / m$appeal_stay_days))
      log_event(st, i, t, "APPEAL_DECIDED")
      rec_push(st$R$motion, case_id = i, motion_type = "INTERLOCUTORY_APPEAL", filed_by = defence,
               filed_day = as.integer(t1), decided_day = as.integer(t), outcome = "DISMISSED")
    }
    record_delay(st, i, t0, t, defence, if (appeal) "INTERLOCUTORY_APPEAL" else "PROCEDURAL_MOTION")
    add_truth(st, i, "motion_delay_days", t - t0)
  }
  if (cs$expert_needed[i]) {
    x <- e$expert
    set_status(st, i, t, "AWAITING_EXPERT"); log_event(st, i, t, "EXPERT_ORDERED")
    due <- t + x$days_mean
    got <- if (stats::runif(1) < x$late_prob) due + max(1, round(stats::rexp(1, 1 / x$late_days_mean))) else
      t + round(x$days_mean * stats::runif(1, 0.6, 1.0))
    rec_push(st$R$expert, case_id = i, ordered_day = as.integer(t), due_day = as.integer(due), delivered_day = as.integer(got))
    rec_push(st$R$deadline, case_id = i, deadline_type = "EXPERT_REPORT", set_day = as.integer(t),
             due_day = as.integer(due), met_day = as.integer(got), extended_days = 0L, responsible = "THIRD_PARTY")
    record_delay(st, i, due, got, "THIRD_PARTY", "EXPERT_LATE")
    log_event(st, i, got, "EXPERT_REPORT_FILED")
    add_truth(st, i, "expert_days", got - t)
    t <- got
  }
  finish_prep(st, i, t)
}

#' After preparation: settle, decide in writing, or request the main hearing.
finish_prep <- function(st, i, t) {
  cs <- st$cs
  if (cs$will_settle[i] && !cs$needs_main_hearing[i]) {
    return(schedule_event(st, t, i, EV[["DISPOSE"]], DISP[["SETTLED"]]))
  }
  if (!cs$needs_main_hearing[i]) {
    return(schedule_event(st, t, i, EV[["DELIB_START"]], DISP[["WRITTEN_DECISION"]]))
  }
  schedule_event(st, t, i, EV[["REQ_HEARING"]], 2L)
}
