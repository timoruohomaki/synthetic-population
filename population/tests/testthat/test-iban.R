test_that("the textbook example FI21 1234 5600 0007 85 validates", {
  expect_equal(luhn_check_digit(1234560000078), 5)
  expect_equal(iban_check_digits(12345600000785), 21)
  expect_true(iban_is_valid("FI21 1234 5600 0007 85"))
  expect_false(any(iban_is_valid(c("FI2112345600000786", "FI2212345600000785",
                                   "SE2112345600000785", "FI211234", NA))))
})

test_that("generated IBANs are valid, unique and use the bank code", {
  set.seed(1)
  i <- make_iban(20000, "9")
  expect_true(all(iban_is_valid(i)))
  expect_false(anyDuplicated(i) > 0)
  expect_true(all(substr(i, 5, 5) == "9"))
  expect_true(all(nchar(i) == 18))
  expect_true(all(startsWith(make_iban(10, "1234"), "FI") & substr(make_iban(10, "1234"), 5, 8) == "1234"))
})

test_that("iban_format groups by four", {
  expect_equal(iban_format("FI2112345600000785"), "FI21 1234 5600 0007 85")
})
