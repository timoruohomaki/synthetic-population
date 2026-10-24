# Data access: locate the ccms-synth database and load what the dashboard needs

#' Resolve the database path: CCMS_DB env var, then the usual relative locations.
find_database <- function(app_dir = getwd()) {
  env <- Sys.getenv("CCMS_DB", "")
  candidates <- c(env, file.path(app_dir, "..", "output", "ccms_synth.sqlite"),
                  file.path(app_dir, "..", "..", "output", "ccms_synth.sqlite"))
  candidates <- candidates[nzchar(candidates)]
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) {
    stop("ccms_synth.sqlite not found. Generate it with `Rscript run.R` or set CCMS_DB. Tried: ",
         paste(normalizePath(candidates, mustWork = FALSE), collapse = ", "), call. = FALSE)
  }
  normalizePath(hit[1])
}

REQUIRED_TABLES <- c("sim_run", "court", "case_type", "judge", "court_case", "hearing", "delay_period",
                     "case_status_history", "case_assignment", "court_resource_month", "adjournment_reason",
                     "attribution_code", "status_code")

DATE_COLS <- c("filing_date", "registration_date", "first_appearance_date", "disposition_date",
               "scheduled_on_date", "earliest_possible_date", "hearing_date", "start_date", "end_date",
               "valid_from", "valid_to", "month_start_date", "cutoff_date")

#' Load all dashboard tables into memory as data.tables with Date columns.
load_dashboard_data <- function(db_path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  missing <- setdiff(REQUIRED_TABLES, DBI::dbListTables(con))
  if (length(missing) > 0) {
    stop("Database is missing tables: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  get <- function(tb) {
    dt <- data.table::as.data.table(DBI::dbReadTable(con, tb))
    for (cl in intersect(DATE_COLS, names(dt))) data.table::set(dt, j = cl, value = as.Date(dt[[cl]]))
    dt
  }
  d <- lapply(stats::setNames(REQUIRED_TABLES, REQUIRED_TABLES), get)
  d$phase <- data.table::as.data.table(DBI::dbGetQuery(con, "SELECT case_id, phase, days_in_phase FROM v_case_phase_duration"))
  enrich_cases(d)
}

enrich_cases <- function(d) {
  cs <- d$court_case
  cs <- merge(cs, d$court[, .(court_id, court_code)], by = "court_id")
  cs <- merge(cs, d$case_type[, .(case_type_code, type_label = description)], by = "case_type_code")
  last_judge <- d$case_assignment[order(case_id, start_date, assignment_id)][, .(judge_id = judge_id[.N]), by = case_id]
  cs <- merge(cs, last_judge, by = "case_id", all.x = TRUE)
  data.table::setkey(cs, case_id)
  d$court_case <- cs
  d$hearing <- merge(d$hearing, cs[, .(case_id, court_code, case_type_code, category)], by = "case_id")
  d$delay_period <- merge(d$delay_period, cs[, .(case_id, court_code, case_type_code, category)], by = "case_id")
  d$cutoff <- d$sim_run$cutoff_date[1]
  d$start <- min(cs$filing_date)
  d$run_id <- d$sim_run$run_id[1]
  d
}

#' Apply the global filters to the case table (court codes, categories, case types).
filter_cases <- function(cases, courts, categories, types) {
  cases[court_code %in% courts & category %in% categories & case_type_code %in% types]
}
