# Calendar booking engine: first-appearance docket and hearing slots --------

#' First day >= earliest where `ok_fun(days)` is TRUE, searched in chunks.
first_ok_day <- function(st, earliest, ok_fun, chunk = 120L) {
  from <- max(0L, as.integer(earliest))
  while (from < st$n_days) {
    to <- min(st$n_days - 1L, from + chunk - 1L)
    days <- from:to
    hit <- which(ok_fun(days))
    if (length(hit) > 0) return(days[hit[1]])
    from <- to + 1L
  }
  NA_integer_
}

#' Book the next free first-appearance slot of the case's court.
book_first_appearance <- function(st, i, earliest) {
  court <- st$cs$court_id[i]
  d <- first_ok_day(st, earliest, function(days) grid_get(st$fa_free, court, days) >= 1)
  if (!is.na(d)) grid_add(st$fa_free, court, d, -1)
  d
}

case_counsel <- function(st, i) {
  k <- c(st$cs$respondent_counsel_id[i], st$cs$claimant_counsel_id[i])
  k[!is.na(k)]
}

#' Book a hearing: needs judge hours, a courtroom with free hours and no
#' same-day conflict for any counsel of the case. Returns hearing row or NA.
book_hearing <- function(st, i, kind, request_day) {
  lead <- maybe_reassign(st, i, request_day)
  cat_key <- if (isTRUE(st$cs$in_custody_now[i])) "CUSTODY" else st$cs$category[i]
  earliest <- request_day + lead + st$cfg$capacity$min_notice_days[[cat_key]]
  j <- st$cv$judge[i]
  rooms <- st$ref$rooms$courtroom_id[st$ref$rooms$court_id == st$cs$court_id[i]]
  counsel <- case_counsel(st, i)
  hours <- hearing_hours(st, i, kind)
  ok_fun <- function(days) {
    ok <- grid_get(st$judge_free, j, days) >= hours
    room_ok <- grid_get(st$room_free, rooms[1], days) >= hours
    for (r in rooms[-1]) room_ok <- room_ok | grid_get(st$room_free, r, days) >= hours
    ok <- ok & room_ok
    for (k in counsel) ok <- ok & grid_get(st$counsel_busy, k, days) == 0L
    ok
  }
  d <- first_ok_day(st, earliest, ok_fun)
  if (is.na(d)) return(NA_integer_)
  free <- vapply(rooms, function(r) grid_get(st$room_free, r, d), numeric(1))
  room <- rooms[which(free >= hours)][1]
  grid_add(st$judge_free, j, d, -hours)
  grid_add(st$room_free, room, d, -hours)
  for (k in counsel) grid_add(st$counsel_busy, k, d, 1L)
  add_truth(st, i, "hearing_queue_days", d - earliest)
  h <- rec_push(st$R$hearing, hearing_id = st$R$hearing$n + 1L, case_id = i, hearing_type = kind,
    judge_id = j, courtroom_id = room, booked_day = as.integer(request_day),
    earliest_day = as.integer(earliest), hearing_day = d, hours = hours, outcome = "SCHEDULED",
    prior_adjournments = st$cv$nadj[i], video = st$ref$rooms$video_enabled[room])
  sput(st$cv, "hrow", i, h)
  log_event(st, i, request_day, "HEARING_SCHEDULED", hearing_id = h,
            detail = sprintf("%s on %s", kind, format(day_to_date(d, st$cfg))))
  set_status(st, i, request_day, "AWAITING_HEARING")
  schedule_event(st, d, i, EV[["HEARING"]], h)
  h
}

hearing_hours <- function(st, i, kind) {
  base <- st$cfg$case_types[[st$cs$case_type_code[i]]]$hearing_hours
  if (kind == "PREPARATORY") base <- base * 0.5
  h <- base * st$cs$complexity[i]^0.6 * (1 + 0.3 * (st$cs$n_respondents[i] - 1))
  min(st$cfg$capacity$hearing_hours_per_day, max(0.5, round(h * 2) / 2))
}

#' Free the capacity of a hearing that will not take place (case resolved).
release_hearing <- function(st, i, h, day) {
  H <- st$R$hearing
  hd <- rec_get(H, "hearing_day", h); hrs <- rec_get(H, "hours", h)
  grid_add(st$judge_free, rec_get(H, "judge_id", h), hd, hrs)
  grid_add(st$room_free, rec_get(H, "courtroom_id", h), hd, hrs)
  for (k in case_counsel(st, i)) grid_add(st$counsel_busy, k, hd, -1L)
  rec_set(H, h, "outcome", "VACATED")
  log_event(st, i, day, "HEARING_VACATED", hearing_id = h)
  sput(st$cv, "hrow", i, NA_integer_)
}

#' Other hearings of the case's counsel within +-3 days (excluding this one).
counsel_load <- function(st, i, day) {
  k <- case_counsel(st, i)
  if (length(k) == 0) return(0L)
  days <- max(0L, day - 3L):min(st$n_days - 1L, day + 3L)
  busy <- vapply(k, function(x) sum(grid_get(st$counsel_busy, x, days)), numeric(1))
  as.integer(sum(busy) - length(k))
}
