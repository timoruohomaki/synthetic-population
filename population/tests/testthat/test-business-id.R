test_that("check digits match known Business IDs", {
  expect_equal(business_id_check_digit("0153791"), 8)
  expect_true(business_id_is_valid("0153791-8"))
  expect_false(any(business_id_is_valid(c("0153791-7", "0153791", "015379-18", NA))))
})

test_that("remainder 1 numbers are never generated", {
  set.seed(1)
  ids <- make_business_id(20000, "9")
  expect_true(all(business_id_is_valid(ids)))
  expect_false(anyDuplicated(ids) > 0)
  expect_true(all(startsWith(ids, "9")))
  expect_equal(vat_number("0153791-8"), "FI01537918")
})
