# SQLite database creation, transactional load and integrity checks --------

TABLE_ORDER <- c("sim_run", "calendar_day", "court", "courtroom", "judge", "judge_absence", "counsel",
  "litigant", "case_type", "attribution_code", "disposition_type", "event_type", "status_code",
  "adjournment_reason", "court_case", "case_party", "case_assignment", "case_status_history",
  "case_event", "document", "hearing", "procedural_deadline", "motion", "expert_report",
  "custody_period", "delay_period", "court_resource_month", "truth_parameter", "truth_case",
  "truth_hearing", "truth_counsel")

#' Split a SQL script into statements (statement terminator: ';' at end of line).
read_sql_statements <- function(path) {
  assert_readable(path)
  txt <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  parts <- strsplit(txt, ";[ \t]*(\n|$)")[[1]]
  parts <- vapply(parts, function(p) {
    lines <- strsplit(p, "\n")[[1]]
    paste(lines[!grepl("^\\s*--", lines)], collapse = "\n")
  }, character(1), USE.NAMES = FALSE)
  trimws(parts[nzchar(trimws(parts))])
}

apply_schema <- function(con, sql_dir) {
  files <- sort(list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE))
  if (length(files) == 0) ccms_abort(sprintf("No .sql files in '%s'", sql_dir), "ccms_io_error")
  for (f in files) {
    for (stmt in read_sql_statements(f)) {
      tryCatch(DBI::dbExecute(con, stmt), error = function(e) {
        ccms_abort(sprintf("Schema error in %s: %s\n%s", basename(f), conditionMessage(e),
                           substr(stmt, 1, 200)), "ccms_db_error")
      })
    }
  }
}

#' Write all tables into a fresh SQLite file. The database is built under a
#' temporary name and renamed only after all checks pass.
write_sqlite <- function(tables, db_path, sql_dir, overwrite = FALSE) {
  if (file.exists(db_path) && !overwrite) {
    ccms_abort(sprintf("'%s' exists; use --overwrite to replace it", db_path), "ccms_io_error")
  }
  missing <- setdiff(TABLE_ORDER, names(tables))
  if (length(missing) > 0) ccms_abort(paste("Missing tables:", paste(missing, collapse = ", ")), "ccms_db_error")
  atomic_write(db_path, function(tmp) {
    con <- DBI::dbConnect(RSQLite::SQLite(), tmp)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
    apply_schema(con, sql_dir)
    DBI::dbWithTransaction(con, {
      for (tb in TABLE_ORDER) {
        n <- DBI::dbAppendTable(con, tb, as.data.frame(tables[[tb]]))
        log_debug(sprintf("  %-22s %8d rows", tb, n))
      }
    })
    verify_database(con, tables)
    DBI::dbExecute(con, "ANALYZE")
  })
  log_info("SQLite database written: ", db_path)
  invisible(db_path)
}

verify_database <- function(con, tables) {
  fk <- DBI::dbGetQuery(con, "PRAGMA foreign_key_check")
  if (nrow(fk) > 0) {
    ccms_abort(sprintf("Foreign key violations: %d (first in table %s)", nrow(fk), fk$table[1]), "ccms_db_error")
  }
  ic <- DBI::dbGetQuery(con, "PRAGMA integrity_check")[[1]]
  if (!identical(ic, "ok")) ccms_abort(paste("Integrity check failed:", ic[1]), "ccms_db_error")
  for (tb in TABLE_ORDER) {
    n <- DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", tb))$n
    if (n != nrow(tables[[tb]])) {
      ccms_abort(sprintf("Row count mismatch in %s: %d vs %d", tb, n, nrow(tables[[tb]])), "ccms_db_error")
    }
  }
  invisible(TRUE)
}
