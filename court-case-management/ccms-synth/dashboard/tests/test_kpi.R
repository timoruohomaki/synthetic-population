# Unit tests for KPI functions on a small hand-checkable fixture -----------

d0 <- as.Date("2025-01-01")
fixture <- data.table::data.table(
  case_id = 1:6, case_number = paste0("C", 1:6), court_code = c("A", "A", "A", "B", "B", "B"),
  case_type_code = c("X", "X", "Y", "X", "Y", "Y"), category = "NON_CRIMINAL",
  filing_date = d0 + c(-40, 5, 10, 20, -100, 50),
  disposition_date = d0 + c(10, 25, NA, NA, 60, NA),
  disposition_code = c("JUDGMENT", "SETTLED", NA, NA, "JUDGMENT", NA),
  judge_id = c(1L, 1L, 2L, 3L, 3L, 3L))
standards <- list(X = 30, Y = 60)

test_that("pending status follows filing and disposition dates", {
  expect_equal(is_pending(fixture, d0 - 1), c(TRUE, FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_equal(is_pending(fixture, d0 + 30), c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE))
})

test_that("caseload inventory balances (Model Reports 7/9/10)", {
  inv <- caseload_inventory(fixture, d0, d0 + 30, by = character(0))
  expect_equal(inv$begin_pending, 2L)
  expect_equal(inv$filed, 3L)
  expect_equal(inv$disposed, 2L)
  expect_equal(inv$end_pending, inv$begin_pending + inv$filed - inv$disposed)
  expect_equal(inv$clearance_rate, 2 / 3)
  by_type <- caseload_inventory(fixture, d0, d0 + 30)
  expect_equal(sum(by_type$share_of_filings), 1)
})

test_that("monthly flow pending equals inventory end pending", {
  mf <- monthly_flow(fixture, d0, d0 + 58, by = character(0))
  expect_equal(nrow(mf), 2L)
  expect_equal(mf$pending_end[1], sum(is_pending(fixture, as.Date("2025-01-31"))))
  expect_equal(mf$incoming, c(3L, 1L))
})

test_that("age buckets and exceptions respect standards (Reports 20, 25, 27)", {
  expect_equal(as.character(age_bucket(c(0, 90, 91, 365, 800), c(90, 180, 365, 730))),
               c("0–90", "0–90", "91–180", "181–365", ">730"))
  as_of <- d0 + 75
  hs <- data.table::data.table(case_id = 3L, scheduled_on_date = d0, hearing_date = d0 + 80, outcome = "SCHEDULED")
  st <- data.table::data.table(status_history_id = 1:3, case_id = c(3L, 4L, 6L),
                               status_code = "PREPARATION", valid_from = d0, valid_to = as.Date(NA))
  jd <- data.table::data.table(judge_id = 1:3, judge_code = c("J1", "J2", "J3"))
  ex <- exception_list(fixture, st, hs, jd, as_of, standards)
  # case 4 (X, age 55 > 30, over by 25) and case 3 (Y, age 65 > 60, over by 5); case 6 (Y, 25) is not
  expect_equal(ex$case_number, c("C4", "C3"))
  expect_equal(ex$over_by, c(25L, 5L))
  expect_equal(ex[case_number == "C3", next_hearing], d0 + 80)
  expect_equal(ex[case_number == "C4", judge_code], "J3")
})

test_that("standard compliance counts dispositions within the standard", {
  sc <- standard_compliance(fixture, d0 - 200, d0 + 100, standards)
  # X: 50 d (over) and 20 d (within) vs 30 -> 0.5; Y: 160 d vs 60 -> 0
  expect_equal(sc[case_type_code == "X", within_standard], 0.5)
  expect_equal(sc[case_type_code == "Y", within_standard], 0)
})

test_that("projection recovers a linear trend (Report 19)", {
  flow <- data.table::data.table(court_code = "A", month = seq(d0, by = "month", length.out = 12),
                                 pending_end = 100 + 10 * (0:11))
  pr <- project_pending(flow, fit_months = 12, horizon = 3)
  expect_equal(pr$slope_per_month[1], 10)
  expect_equal(pr[type == "projection", pending_end], c(220, 230, 240))
})
