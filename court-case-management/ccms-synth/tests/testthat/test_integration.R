# Integration test: small end-to-end run and database invariants -----------

run_small <- function() {
  cfg <- load_config(proj("config/simulation.yaml"), proj("config/codes.yaml"))
  cfg$run$end <- as.Date("2023-09-30"); cfg$run$cutoff <- as.Date("2024-03-31")
  cfg$run$calendar_horizon_days <- 300
  cfg$volume$cases_per_year <- 1500
  out <- file.path(tempdir(), "ccms_it")
  unlink(out, recursive = TRUE)
  invisible(utils::capture.output(
    generate_dataset(cfg, out, proj("sql/sqlite"), overwrite = TRUE, write_csv = FALSE)))
  list(cfg = cfg, db = file.path(out, "ccms_synth.sqlite"))
}

it <- run_small()
con <- DBI::dbConnect(RSQLite::SQLite(), it$db)
withr_q <- function(sql) DBI::dbGetQuery(con, sql)

test_that("database passes FK and integrity checks", {
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
  expect_equal(nrow(withr_q("PRAGMA foreign_key_check")), 0)
  expect_equal(withr_q("PRAGMA integrity_check")[[1]], "ok")
})

test_that("nothing is dated after the cutoff", {
  cut <- format(it$cfg$run$cutoff)
  expect_equal(withr_q(sprintf("SELECT COUNT(*) n FROM case_event WHERE event_date > '%s'", cut))$n, 0)
  expect_equal(withr_q(sprintf("SELECT COUNT(*) n FROM court_case WHERE disposition_date > '%s'", cut))$n, 0)
  expect_equal(withr_q(sprintf("SELECT COUNT(*) n FROM hearing WHERE hearing_date > '%s'
                                AND outcome IN ('HELD','ADJOURNED')", cut))$n, 0)
})

test_that("case timelines are ordered", {
  bad <- withr_q("SELECT COUNT(*) n FROM court_case WHERE registration_date < filing_date
                  OR first_appearance_date < registration_date OR disposition_date < filing_date")$n
  expect_equal(bad, 0)
  expect_equal(withr_q("SELECT COUNT(*) n FROM hearing WHERE hearing_date < scheduled_on_date")$n, 0)
})

test_that("status history is gap-free and ends in DISPOSED for disposed cases", {
  gaps <- withr_q("SELECT COUNT(*) n FROM case_status_history a JOIN case_status_history b
                   ON b.case_id = a.case_id AND b.status_history_id = a.status_history_id + 1
                   WHERE a.valid_to <> b.valid_from")$n
  expect_equal(gaps, 0)
  mism <- withr_q("SELECT COUNT(*) n FROM court_case WHERE (disposition_date IS NOT NULL) <> (case_status = 'DISPOSED')")$n
  expect_equal(mism, 0)
})

test_that("every adjournment has a reason and an attribution", {
  x <- withr_q("SELECT COUNT(*) n FROM hearing h LEFT JOIN adjournment_reason r
                ON r.reason_code = h.adjournment_reason_code
                WHERE h.outcome = 'ADJOURNED' AND r.attribution_code IS NULL")$n
  expect_equal(x, 0)
})

test_that("judge capacity is never overbooked", {
  over <- withr_q("SELECT judge_id, hearing_date, SUM(planned_hours) h FROM hearing
                   WHERE outcome <> 'VACATED' GROUP BY judge_id, hearing_date HAVING h > 5.5 + 1e-9")
  expect_equal(nrow(over), 0)
})

test_that("all analytical views are queryable", {
  views <- withr_q("SELECT name FROM sqlite_master WHERE type = 'view'")$name
  expect_true(length(views) >= 8)
  for (v in views) expect_silent(withr_q(sprintf("SELECT * FROM %s LIMIT 5", v)))
})

DBI::dbDisconnect(con)
