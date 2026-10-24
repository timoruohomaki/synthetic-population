# Output reference tables --------------------------------------------------

build_reference_tables <- function(st, cfg, run_id) {
  ref <- st$ref; cal <- st$cal; cut <- cutoff_day(cfg)
  out <- code_tables(cfg)
  out$sim_run <- data.table::data.table(run_id = run_id, generated_at = now_rfc3339(),
    seed = as.integer(cfg$run$seed), start_date = format(cfg$run$start), end_date = format(cfg$run$end),
    cutoff_date = format(cfg$run$cutoff), generator = "ccms-synth 1.0.0", config_yaml = cfg$raw_yaml)
  out$calendar_day <- cal[day <= cut + 365L, .(calendar_date = format(date, "%Y-%m-%d"), iso_weekday,
    is_working_day, is_holiday, holiday_name, capacity_factor = round(capacity_factor, 3))]
  out$court <- ref$courts[, .(court_id, court_code = code, court_name = name, court_level = level,
    population, judges_establishment = judges, clerks_establishment = clerks,
    hearing_weekdays_per_judge = hearing_weekdays)]
  out$courtroom <- ref$rooms[, .(courtroom_id, court_id, room_name, video_enabled)]
  out$judge <- ref$judges[, .(judge_id, court_id, judge_code, experience_years_at_start = experience_years,
    hearing_weekdays)]
  ab <- ref$absences[start_day <= cut]
  out$judge_absence <- ab[, .(absence_id, judge_id, absence_type,
    start_date = iso_date(start_day, cfg), end_date = iso_date(pmin(end_day, cut), cfg),
    is_ongoing_at_cutoff = end_day > cut)]
  out$counsel <- ref$counsel[, .(counsel_id, home_court_id = court_id, counsel_code, counsel_type)]
  out$litigant <- ref$litigants
  out$case_type <- ref$case_types[, .(case_type_code, description = label, category, court_levels,
    response_days, presumptive_ceiling_days)]
  out
}

#' Court x month resource panel (Rocha et al. style controls).
build_resource_panel <- function(st, rmonths, cfg) {
  jf <- judge_fte_by_month(st$ref, st$cal)
  cs <- st$cs
  ef <- cs[, .(cases_filed = .N, efiling_rate = round(mean(filing_channel == "EFILING"), 4)),
           by = .(court_id, month_key = format(cfg$run$start + filing_day, "%Y-%m"))]
  p <- merge(rmonths, jf, by = c("court_id", "month_key"), all.x = TRUE)
  p <- merge(p, ef, by = c("court_id", "month_key"), all.x = TRUE)
  p <- merge(p, st$ref$courts[, .(court_id, judges)], by = "court_id")
  p[, .(court_id, period_month = month_key, month_start_date = format(month_start, "%Y-%m-%d"),
        judges_establishment = judges, judges_fte, clerks_fte, clerk_vacancy_rate, budget_eur,
        it_budget_share, efiling_rate, population)][order(court_id, period_month)]
}
