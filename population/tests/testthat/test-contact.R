test_that("names become plain ASCII e-mail addresses", {
  first <- c("Äijä", "Matti", "Matti", "Élise")
  last <- c("Öhman-Ström", "Virtanen", "Virtanen", "Åberg")
  e <- make_email(first, last, "example.com")
  expect_equal(e, c("aija.ohman-strom@example.com", "matti.virtanen@example.com",
                    "matti.virtanen2@example.com", "elise.aberg@example.com"))
})

test_that("e-mail addresses are unique and use the given domains", {
  set.seed(1)
  e <- make_email(rep("Anna", 1000), rep("Korhonen", 1000), c("example.com", "example.org"))
  expect_false(anyDuplicated(e) > 0)
  expect_true(all(sub(".*@", "", e) %in% c("example.com", "example.org")))
})

test_that("phone numbers are unique and use the prefixes", {
  set.seed(1)
  p <- make_phone(5000, list("047" = 0.5, "048" = 0.5))
  expect_false(anyDuplicated(p) > 0)
  expect_true(all(grepl("^04[78] [0-9]{7}$", p)))
})
