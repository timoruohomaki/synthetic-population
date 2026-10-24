# Unit tests: calendar, recorder, config validation, I/O -------------------

small_cfg <- function() {
  cfg <- load_config(proj("config/simulation.yaml"), proj("config/codes.yaml"))
  cfg$run$end <- as.Date("2023-06-30"); cfg$run$cutoff <- as.Date("2023-12-31")
  cfg$run$calendar_horizon_days <- 200
  cfg$volume$cases_per_year <- 400
  cfg
}

test_that("Easter and Finnish holidays are correct", {
  expect_equal(easter_sunday(2024), as.Date("2024-03-31"))
  expect_equal(easter_sunday(2025), as.Date("2025-04-20"))
  h <- holidays_fi(2025)
  expect_equal(nrow(h), 12)
  expect_true(as.Date("2025-06-20") %in% h$date)  # Midsummer Eve (Friday)
  expect_true(as.Date("2025-12-06") %in% h$date)
})

test_that("calendar has no hearing capacity on holidays and weekends", {
  cal <- build_calendar(small_cfg())
  expect_true(all(cal[is_holiday | iso_weekday > 5, capacity_factor] == 0))
  expect_true(all(diff(cal$cum_work) >= 0))
  expect_equal(cal$day, seq_len(nrow(cal)) - 1L)
})

test_that("add_work_days skips non-working days", {
  cal <- build_calendar(small_cfg())
  fri <- cal[date == as.Date("2023-01-13"), day]          # Friday
  expect_equal(cal$date[add_work_days(cal, fri, 1) + 1], as.Date("2023-01-16"))
  expect_true(all(add_work_days(cal, 0:30, 5) >= 0:30))
})

test_that("recorder grows and updates in place", {
  r <- rec_new(list(a = integer(), b = character()), capacity = 2L)
  for (i in 1:5) rec_push(r, a = i, b = letters[i])
  expect_equal(rec_size(r), 5L)
  rec_set(r, 3L, "b", "z")
  dt <- rec_to_dt(r)
  expect_equal(dt$a, 1:5)
  expect_equal(dt$b[3], "z")
  expect_error(rec_set(r, 9L, "a", 1L), class = "ccms_sim_error")
})

test_that("config validation rejects bad input", {
  cfg <- small_cfg()
  bad <- cfg; bad$courts[[1]]$share <- 0.9
  expect_error(validate_config(bad), class = "ccms_validation_error")
  bad <- cfg; bad$case_types$CIV_SUM$settle_prob <- 1.5
  expect_error(validate_config(bad), class = "ccms_validation_error")
  bad <- cfg; bad$run$cutoff_date <- "2020-01-01"
  expect_error(validate_config(bad), class = "ccms_validation_error")
  expect_error(read_yaml_file("does/not/exist.yaml"), class = "ccms_io_error")
})

test_that("EU CSV round-trips decimals with comma", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  dt <- data.table(x = c(1.5, 1234.25), d = c("2025-01-31", NA))
  write_csv_eu(dt, tmp)
  expect_match(readLines(tmp)[2], "1,5")
  back <- read_csv_eu(tmp)
  expect_equal(back$x, dt$x)
})

test_that("SQL splitter ignores comments and keeps statements whole", {
  st <- read_sql_statements(proj("sql/sqlite/005_views_case.sql"))
  expect_true(length(st) >= 4)
  expect_true(all(grepl("^CREATE VIEW", st)))
})
