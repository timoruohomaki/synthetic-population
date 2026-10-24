# Day-stepped discrete-event loop ------------------------------------------

dispatch_event <- function(st, type, i, d, arg) {
  switch(as.character(type),
    "1" = on_file(st, i, d),
    "2" = on_register(st, i, d),
    "3" = on_first_appearance(st, i, d),
    "4" = on_served(st, i, d),
    "5" = on_prep_start(st, i, d),
    "6" = on_req_hearing(st, i, d, arg),
    "7" = on_hearing(st, i, d, arg),
    "8" = on_delib_start(st, i, d, arg),
    "9" = on_judgment(st, i, d, arg),
    "10" = on_dispose(st, i, d, arg),
    ccms_abort(sprintf("Unknown event type %s", type), "ccms_sim_error"))
}

#' Run the simulation up to the cutoff day. Events after the cutoff are not
#' processed, but hearings may already be booked beyond it (future calendar).
run_simulation <- function(st) {
  for (i in seq_len(nrow(st$cs))) schedule_event(st, st$cs$filing_day[i], i, EV[["FILE"]])
  last <- min(st$cutoff_day, st$n_days - 1L)
  ev <- st$ev
  for (d in 0:last) {
    k <- 1L
    while (k <= length(st$buckets[[d + 1L]])) {
      id <- st$buckets[[d + 1L]][k]
      i <- ev$dt$case_id[id]
      type <- ev$dt$type[id]
      res <- tryCatch(dispatch_event(st, type, i, d, ev$dt$arg[id]),
        error = function(e) {
          ccms_abort(sprintf("Simulation failed on day %d, case %d, event %d: %s",
                             d, i, type, conditionMessage(e)), "ccms_sim_error")
        })
      k <- k + 1L
    }
    st$buckets[[d + 1L]] <- integer(0)
    if (d %% 180L == 0L) {
      log_info(sprintf("  day %4d (%s): open=%d pending_judgments=%d", d,
        format(day_to_date(d, st$cfg)), sum(st$jv$active), sum(st$jv$pending)))
    }
  }
  invisible(st)
}
