# Configuration loading and validation -------------------------------------

REQUIRED_TYPE_KEYS <- c("label", "category", "levels", "weight", "complexity",
  "contest_prob", "early_prob", "settle_prob", "hearing_prob", "prep_hearing",
  "expert_prob", "interpreter_prob", "custody_prob", "self_rep_prob",
  "response_days", "prep_days", "hearing_hours", "delib_days", "ceiling_days")

REQUIRED_COURT_KEYS <- c("code", "name", "level", "share", "population", "judges", "hearing_weekdays",
  "clerks", "courtrooms", "video_rooms", "budget_eur_month", "it_share",
  "efiling_start", "efiling_end")

#' Load simulation and code configs, validate, and derive date fields.
load_config <- function(sim_path, codes_path) {
  cfg <- read_yaml_file(sim_path)
  cfg$codes <- read_yaml_file(codes_path)
  cfg$raw_yaml <- paste(readLines(sim_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  validate_config(cfg)
  cfg$run$start <- as.Date(cfg$run$start_date)
  cfg$run$end <- as.Date(cfg$run$end_date)
  cfg$run$cutoff <- as.Date(cfg$run$cutoff_date)
  cfg
}

parse_iso_date <- function(x, name) {
  d <- tryCatch(as.Date(x, format = "%Y-%m-%d"), error = function(e) NA)
  assert_that(length(d) == 1 && !is.na(d), sprintf("'%s' must be an ISO 8601 date (YYYY-MM-DD)", name))
  d
}

validate_config <- function(cfg) {
  for (sec in c("run", "volume", "courts", "case_types", "actors", "capacity", "absence", "effects")) {
    assert_that(!is.null(cfg[[sec]]), sprintf("Missing config section '%s'", sec))
  }
  s <- parse_iso_date(cfg$run$start_date, "run.start_date")
  e <- parse_iso_date(cfg$run$end_date, "run.end_date")
  c <- parse_iso_date(cfg$run$cutoff_date, "run.cutoff_date")
  assert_that(s < e && e <= c, "Dates must satisfy start_date < end_date <= cutoff_date")
  assert_number(cfg$run$seed, "run.seed")
  assert_number(cfg$volume$cases_per_year, "volume.cases_per_year", 10, 1e7)
  assert_that(length(cfg$volume$monthly_seasonality) == 12, "monthly_seasonality needs 12 values")

  shares <- vapply(cfg$courts, function(x) x$share, numeric(1))
  assert_that(abs(sum(shares) - 1) < 1e-6, "Court shares must sum to 1")
  for (ct in cfg$courts) {
    miss <- setdiff(REQUIRED_COURT_KEYS, names(ct))
    assert_that(length(miss) == 0, sprintf("Court %s missing: %s", ct$code, paste(miss, collapse = ", ")))
    assert_that(ct$level %in% c("ORDINARY", "SMALL_CLAIMS"), sprintf("Court %s: invalid level", ct$code))
    assert_that(ct$judges >= 1 && ct$clerks >= 1 && ct$courtrooms >= 1, sprintf("Court %s: capacity must be >= 1", ct$code))
    assert_that(ct$hearing_weekdays %in% 1:5, sprintf("Court %s: hearing_weekdays must be 1..5", ct$code))
  }
  levels_used <- unique(vapply(cfg$courts, function(x) x$level, character(1)))
  for (code in names(cfg$case_types)) {
    tp <- cfg$case_types[[code]]
    miss <- setdiff(REQUIRED_TYPE_KEYS, names(tp))
    assert_that(length(miss) == 0, sprintf("Case type %s missing: %s", code, paste(miss, collapse = ", ")))
    assert_that(tp$category %in% c("CRIMINAL", "NON_CRIMINAL"), sprintf("Case type %s: bad category", code))
    for (p in grep("_prob$", names(tp), value = TRUE)) assert_prob(tp[[p]], paste0(code, ".", p))
    assert_number(tp$complexity, paste0(code, ".complexity"), 0.05, 20)
  }
  for (lv in levels_used) {
    n <- sum(vapply(cfg$case_types, function(t) lv %in% t$levels, logical(1)))
    assert_that(n > 0, sprintf("No case types defined for court level %s", lv))
  }
  reasons <- cfg$codes$adjournment_reasons
  for (r in names(reasons)) {
    assert_that(reasons[[r]]$attribution %in% names(cfg$codes$attribution),
                sprintf("Reason %s has unknown attribution", r))
  }
  invisible(TRUE)
}

#' Flatten effects to a key/value table for the truth_parameter table.
flatten_effects <- function(cfg) {
  v <- unlist(cfg$effects)
  data.table::data.table(parameter = names(v), value = as.numeric(v))
}
