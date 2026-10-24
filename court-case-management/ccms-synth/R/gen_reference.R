# Reference entities: courts, courtrooms, judges, absences, counsel, litigants

gen_courts <- function(cfg) {
  dt <- data.table::rbindlist(lapply(cfg$courts, data.table::as.data.table))
  dt[, court_id := seq_len(.N)]
  dt[]
}

gen_courtrooms <- function(courts) {
  courts[, .(room_no = seq_len(courtrooms), video_rooms), by = .(court_id, code)][
    , .(court_id, room_name = sprintf("%s-R%02d", code, room_no),
        video_enabled = room_no <= video_rooms)][
    , courtroom_id := seq_len(.N)][]
}

gen_judges <- function(courts, cfg) {
  j <- courts[, .(seq_in_court = seq_len(judges)), by = .(court_id, code, n_wd = hearing_weekdays)]
  j[, judge_id := seq_len(.N)]
  j[, judge_code := sprintf("%s-J%02d", code, seq_in_court)]
  j[, experience_years := round(stats::runif(.N, 1, 30))]
  # Each judge hears on a fixed set of weekdays, e.g. "2,3,4".
  j[, hearing_weekdays := vapply(n_wd, function(n) paste(sort(sample(1:5, n)), collapse = ","), character(1))]
  j[, .(judge_id, court_id, judge_code, experience_years, hearing_weekdays)]
}

#' Absence episodes per judge over the whole calendar.
gen_absences <- function(judges, cal, cfg) {
  a <- cfg$absence
  n_days <- nrow(cal)
  years <- n_days / 365.25
  out <- lapply(judges$judge_id, function(jid) {
    n_short <- stats::rpois(1, a$short_rate_per_year * years)
    s_start <- sample.int(n_days, n_short, replace = TRUE) - 1L
    s_len <- pmax(1L, stats::rpois(n_short, a$short_days_mean))
    n_long <- stats::rbinom(1, ceiling(years), a$long_prob_per_year)
    l_start <- sample.int(n_days, n_long, replace = TRUE) - 1L
    l_len <- as.integer(round(stats::runif(n_long, a$long_days_min, a$long_days_max)))
    data.table::data.table(judge_id = jid,
      start_day = c(s_start, l_start), length_days = c(s_len, l_len),
      absence_type = c(rep("SHORT_ILLNESS", n_short), rep("LONG_LEAVE", n_long)))
  })
  dt <- data.table::rbindlist(out)
  dt[, end_day := pmin(start_day + length_days - 1L, n_days - 1L)]
  dt[, absence_id := seq_len(.N)]
  dt[, .(absence_id, judge_id, absence_type, start_day, end_day)]
}

#' Counsel pool per court with heavy-tailed activity (some lawyers are very busy).
gen_counsel <- function(courts, cfg) {
  n <- cfg$actors$counsel_per_court
  shape <- cfg$actors$counsel_activity_shape
  dt <- courts[, .(k = seq_len(n)), by = .(court_id, code)]
  dt[, counsel_id := seq_len(.N)]
  dt[, counsel_code := sprintf("%s-C%03d", code, k)]
  dt[, counsel_type := sample(c("PRIVATE", "PUBLIC_DEFENDER"), .N, TRUE, c(0.7, 0.3))]
  dt[, activity_weight := (1 / stats::runif(.N))^(1 / shape)]  # Pareto(1, shape)
  dt[, .(counsel_id, court_id, counsel_code, counsel_type, activity_weight)]
}

#' Bulk (mass / robot) filers of summary claims, plus a generic prosecution office.
gen_litigants <- function(cfg) {
  n <- cfg$actors$bulk_litigants
  data.table::data.table(
    litigant_id = seq_len(n + 1L),
    litigant_name = c(sprintf("Collection Agency %s", LETTERS[seq_len(n)]), "Public Prosecution Service"),
    litigant_type = c(rep("ORGANISATION", n), "PUBLIC_AUTHORITY"),
    is_bulk_filer = c(rep(TRUE, n), FALSE))
}

gen_case_types <- function(cfg) {
  data.table::rbindlist(lapply(names(cfg$case_types), function(code) {
    t <- cfg$case_types[[code]]
    data.table::data.table(case_type_code = code, label = t$label, category = t$category,
      court_levels = paste(t$levels, collapse = ","), mean_complexity = t$complexity,
      response_days = t$response_days, presumptive_ceiling_days = t$ceiling_days)
  }))
}

gen_reference <- function(cfg, cal) {
  courts <- gen_courts(cfg)
  judges <- gen_judges(courts, cfg)
  list(courts = courts, rooms = gen_courtrooms(courts), judges = judges,
       absences = gen_absences(judges, cal, cfg), counsel = gen_counsel(courts, cfg),
       litigants = gen_litigants(cfg), case_types = gen_case_types(cfg))
}
