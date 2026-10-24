# Hearings and adjournments -------------------------------------------------

on_req_hearing <- function(st, i, d, kind_idx) {
  if (st$cv$disposed[i]) return(invisible())
  kind <- HEARING_KIND[kind_idx]
  h <- book_hearing(st, i, kind, d)
  if (is.na(h)) return(invisible())
  hday <- rec_get(st$R$hearing, "hearing_day", h)
  if (!is.na(st$cv$adj_from[i])) {
    reason <- st$cv$adj_reason[i]
    attr <- st$cfg$codes$adjournment_reasons[[reason]]$attribution
    if (attr == "DEFENCE" && st$cs$category[i] == "NON_CRIMINAL") attr <- "RESPONDENT"
    record_delay(st, i, st$cv$adj_from[i], hday, attr, paste0("ADJ_", reason))
    add_truth(st, i, "adjournment_delay_days", hday - st$cv$adj_from[i])
    sput(st$cv, "adj_from", i, NA_integer_)
  }
  if (kind == "MAIN" && st$cs$will_settle[i] && is.na(st$cv$settle[i])) {
    share <- st$cfg$effects$settlement_window_share
    sput(st$cv, "settle", i, as.integer(d + round(stats::runif(1, 0.1, share) * (hday - d))))
    schedule_event(st, st$cv$settle[i], i, EV[["DISPOSE"]], DISP[["SETTLED"]])
  }
}

#' Linear predictor of adjournment (TRUE model, see config effects.adjournment).
adjournment_lp <- function(st, i, h, cl) {
  a <- st$cfg$effects$adjournment; cs <- st$cs
  a$intercept + a$log_complexity * log(cs$complexity[i]) +
    a$interpreter * (!is.na(cs$interpreter_language[i])) + a$self_represented * cs$self_represented[i] +
    a$counsel_load * cl + a$custody * isTRUE(cs$in_custody_now[i]) +
    a$video_room * isTRUE(rec_get(st$R$hearing, "video", h)) + a$extra_defendant * (cs$n_respondents[i] - 1) +
    a$prior_adjournments * st$cv$nadj[i] + a$prep_hearing * (rec_get(st$R$hearing, "hearing_type", h) == "PREPARATORY")
}

choose_reason <- function(st, i, cl) {
  rs <- st$cfg$codes$adjournment_reasons; cs <- st$cs
  w <- vapply(names(rs), function(code) {
    r <- rs[[code]]
    if (r$applies != "BOTH" && r$applies != cs$category[i]) return(0)
    switch(r$driver,
      counsel_load = r$weight * (1 + cl),
      self_rep = r$weight * (1 + 2 * cs$self_represented[i]),
      complexity = r$weight * cs$complexity[i],
      interpreter = if (is.na(cs$interpreter_language[i])) 0 else 4,
      expert = if (cs$expert_needed[i]) 2 else 0,
      r$weight)
  }, numeric(1))
  sample(names(rs), 1, prob = w)
}

on_hearing <- function(st, i, d, h) {
  if (st$cv$disposed[i] || !identical(st$cv$hrow[i], h)) return(invisible())
  sput(st$cv, "hrow", i, NA_integer_)
  cl <- counsel_load(st, i, d)
  lp <- adjournment_lp(st, i, h, cl)
  p <- stats::plogis(lp)
  H <- st$R$hearing
  rec_set(H, h, "counsel_load", cl); rec_set(H, h, "lin_pred", lp); rec_set(H, h, "p_adjourn", p)
  kind <- rec_get(H, "hearing_type", h)
  if (stats::runif(1) < p) {
    reason <- choose_reason(st, i, cl)
    rec_set(H, h, "outcome", "ADJOURNED"); rec_set(H, h, "reason_code", reason)
    log_event(st, i, d, "HEARING_ADJOURNED", hearing_id = h, detail = reason)
    sadd(st$cv, "nadj", i, 1L)
    sput(st$cv, "adj_from", i, as.integer(d)); sput(st$cv, "adj_reason", i, reason)
    extra <- st$cfg$codes$adjournment_reasons[[reason]]$extra_days * stats::runif(1, 0.6, 1.4)
    set_status(st, i, d, "AWAITING_HEARING")
    return(schedule_event(st, d + round(extra), i, EV[["REQ_HEARING"]], match(kind, HEARING_KIND)))
  }
  rec_set(H, h, "outcome", "HELD")
  log_event(st, i, d, "HEARING_HELD", hearing_id = h, detail = kind)
  if (kind == "PREPARATORY") {
    if (st$cs$will_settle[i] && stats::runif(1) < 0.4) return(close_case(st, i, d, "SETTLED"))
    return(continue_prep(st, i, d, st$cv$prep_rest[i]))
  }
  on_delib_start(st, i, d, DISP[["JUDGMENT"]])
}
