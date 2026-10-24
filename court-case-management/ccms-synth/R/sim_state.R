# Simulation state: calendars, capacity matrices, per-case state, recorders

EV <- c(FILE = 1L, REGISTER = 2L, FIRST_APPEAR = 3L, SERVED = 4L, PREP_START = 5L,
        REQ_HEARING = 6L, HEARING = 7L, DELIB_START = 8L, JUDGMENT = 9L, DISPOSE = 10L)
HEARING_KIND <- c("PREPARATORY", "MAIN")

#' Mark absences in a judge x day matrix and compute "absent until" per cell.
absence_matrices <- function(ref, n_days) {
  nj <- nrow(ref$judges)
  absent <- matrix(FALSE, nj, n_days)
  for (k in seq_len(nrow(ref$absences))) {
    a <- ref$absences[k]
    absent[a$judge_id, (a$start_day:a$end_day) + 1L] <- TRUE
  }
  until <- matrix(-1L, nj, n_days)
  for (j in seq_len(nj)) {
    r <- rle(absent[j, ])
    ends <- cumsum(r$lengths)
    starts <- ends - r$lengths + 1L
    for (k in which(r$values)) until[j, starts[k]:ends[k]] <- ends[k] - 1L
  }
  list(absent = absent, until = until)
}

init_state <- function(cases, ref, cal, cfg) {
  st <- new.env(parent = emptyenv())
  st$cfg <- cfg; st$ref <- ref; st$cal <- cal
  st$cs <- data.table::copy(cases)
  st$cs[, `:=`(disposition_code = NA_character_, disposition_day = NA_integer_,
               registration_day = NA_integer_, first_appearance_day = NA_integer_)]
  st$n_days <- nrow(cal); st$cutoff_day <- as.integer(cfg$run$cutoff - cfg$run$start)
  cap <- cfg$capacity; nd <- st$n_days
  am <- absence_matrices(ref, nd)
  st$absent <- am$absent; st$absent_until <- am$until
  wd_ok <- t(vapply(strsplit(ref$judges$hearing_weekdays, ","), function(w)
    cal$iso_weekday %in% as.integer(w), logical(nd)))
  # Capacity grids are day-major data.tables updated in place (see sim_recorder.R).
  st$judge_free <- grid_new(matrix(cap$hearing_hours_per_day, nrow(ref$judges), nd) *
    rep(cal$capacity_factor, each = nrow(ref$judges)) * wd_ok * (!st$absent))
  st$room_free <- grid_new(matrix(cap$room_hours_per_day, nrow(ref$rooms), nd) *
    rep(as.numeric(cal$is_working_day), each = nrow(ref$rooms)))
  fa_day <- cal$is_working_day & cal$iso_weekday %in% unlist(cap$first_appearance_weekdays)
  st$fa_free <- grid_new(matrix(round(cap$first_appearance_slots_per_day * pmax(cal$capacity_factor, 0.5) * fa_day),
                         nrow(ref$courts), nd, byrow = TRUE))
  st$counsel_busy <- grid_new(matrix(0L, nrow(ref$counsel), nd))
  st$jv <- data.table::data.table(active = integer(nrow(ref$judges)), pending = integer(nrow(ref$judges)))
  n <- nrow(cases)
  st$cv <- data.table::data.table(judge = rep(NA_integer_, n), status = rep(NA_character_, n),
    disposed = rep(FALSE, n), nadj = integer(n), settle = rep(NA_integer_, n),
    assign_row = rep(NA_integer_, n), custody_row = rep(NA_integer_, n),
    hrow = rep(NA_integer_, n),            # currently scheduled hearing
    prep_rest = numeric(n),                # preparation left after a preparatory hearing
    adj_from = rep(NA_integer_, n), adj_reason = rep(NA_character_, n))
  st$buckets <- vector("list", nd)
  st$ev <- rec_new(list(case_id = integer(), type = integer(), arg = integer()), 65536L)
  st$truth <- data.table::data.table(case_id = cases$case_id, reg_lag_days = NA_real_,
    clerk_load = NA_real_, service_days = NA_real_, unreachable_attempts = 0L,
    prep_days = 0, motion_delay_days = 0, expert_days = 0, hearing_queue_days = 0,
    adjournment_delay_days = 0, deliberation_work_days = NA_real_, backlog_at_deliberation = NA_integer_,
    reassigned = FALSE, trend_factor = NA_real_)
  init_recorders(st)
  st
}

init_recorders <- function(st) {
  I <- integer(); C <- character(); D <- double(); L <- logical()
  st$R <- list(
    event = rec_new(list(case_id = I, day = I, event_code = C, judge_id = I, hearing_id = I, detail = C), 131072L),
    status = rec_new(list(case_id = I, day = I, status_code = C), 131072L),
    hearing = rec_new(list(hearing_id = I, case_id = I, hearing_type = C, judge_id = I, courtroom_id = I,
      booked_day = I, earliest_day = I, hearing_day = I, hours = D, outcome = C, reason_code = C,
      prior_adjournments = I, counsel_load = I, video = L, lin_pred = D, p_adjourn = D), 32768L),
    assign = rec_new(list(case_id = I, judge_id = I, from_day = I, to_day = I, reason = C), 32768L),
    deadline = rec_new(list(case_id = I, deadline_type = C, set_day = I, due_day = I, met_day = I,
      extended_days = I, responsible = C), 32768L),
    motion = rec_new(list(case_id = I, motion_type = C, filed_by = C, filed_day = I, decided_day = I, outcome = C)),
    expert = rec_new(list(case_id = I, ordered_day = I, due_day = I, delivered_day = I)),
    custody = rec_new(list(case_id = I, from_day = I, to_day = I, end_reason = C)),
    delay = rec_new(list(case_id = I, from_day = I, to_day = I, attribution = C, cause_code = C), 32768L))
  invisible(st)
}

#' Queue an event for a future (or the current) day; days past the horizon are dropped.
schedule_event <- function(st, day, case_id, type, arg = NA_integer_) {
  day <- as.integer(ceiling(day))
  if (is.na(day) || day >= st$n_days) return(invisible(NA_integer_))
  id <- rec_push(st$ev, case_id = case_id, type = type, arg = arg)
  st$buckets[[day + 1L]] <- c(st$buckets[[day + 1L]], id)
  invisible(id)
}
