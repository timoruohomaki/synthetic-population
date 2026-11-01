test_that("check character matches the official example 131052-308T", {
  expect_equal(hetu_check_char("131052", "308"), "T")
  expect_true(hetu_is_valid("131052-308T"))
  expect_false(hetu_is_valid("131052-308U"))
})

test_that("check characters are vectorised", {
  expect_equal(hetu_check_char(c("131052", "010101"), c("308", "002")),
               c("T", hetu_check_char("010101", "002")))
})

test_that("invalid formats and dates are rejected", {
  expect_false(any(hetu_is_valid(c("310252-308T", "131052308T", "131052-001X", NA, ""))))
})

test_that("test_series codes use 900-999, real months and the right parity", {
  set.seed(1)
  birth <- as.Date("1980-05-17") + sample(-20000:20000, 5000, replace = TRUE)
  sex <- sample(c("F", "M"), 5000, replace = TRUE)
  h <- make_hetu(birth, sex, "test_series")
  p <- hetu_parse(h)
  expect_true(all(hetu_is_valid(h, allow_month_offset = FALSE)))
  expect_true(all(p$individual_number >= 900))
  expect_equal(p$birth_date, birth)
  expect_equal(p$sex, sex)
  expect_false(anyDuplicated(h) > 0)
})

test_that("month_offset codes use months 13-24 and pass the checksum", {
  set.seed(2)
  birth <- as.Date(c("1899-12-31", "1950-01-01", "2005-03-01"))
  h <- make_hetu(birth, c("M", "F", "F"), "month_offset")
  expect_equal(substr(h, 3, 4), c("24", "13", "15"))
  expect_equal(substr(h, 7, 7), c("+", "-", "A"))
  expect_true(all(hetu_is_valid(h)))
  expect_false(any(hetu_is_valid(h, allow_month_offset = FALSE)))
  expect_equal(hetu_parse(h)$birth_date, birth)
})

test_that("new century markers are used when asked", {
  set.seed(3)
  h <- make_hetu(as.Date(c("1990-01-01", "2010-01-01")), c("F", "M"), new_marker_share = 1)
  expect_true(substr(h[1], 7, 7) %in% c("Y", "X", "W", "V", "U"))
  expect_true(substr(h[2], 7, 7) %in% c("B", "C", "D", "E", "F"))
  expect_true(all(hetu_is_valid(h)))
})

test_that("too many people on one day gives a helpful error", {
  birth <- rep(as.Date("2000-01-01"), 51)
  expect_error(make_hetu(birth, rep("F", 51), "test_series"), "month_offset")
  expect_length(make_hetu(birth, rep("F", 51), "month_offset"), 51)
})
