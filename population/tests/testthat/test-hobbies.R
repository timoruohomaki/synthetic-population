test_that("weighted sampling follows the weights", {
  set.seed(1)
  x <- sample(c("a", "b"), 1e5, replace = TRUE, prob = c(3, 1))
  expect_equal(mean(x == "a"), 0.75, tolerance = 0.01)
})

test_that("Zipf weights give the favourite the expected share", {
  set.seed(1)
  w <- zipf_weights(129, 1)
  expect_equal(max(w) / sum(w), 1 / sum(1 / 1:129))
  expect_setequal(round(1 / w), 1:129)
})

test_that("a complete weight column is used as it is", {
  h <- tibble::tibble(hobby = c("a", "b"), weight = c(5, 1))
  expect_equal(hobby_weights(h), c(5, 1))
  h$weight[2] <- NA
  expect_length(suppressMessages(hobby_weights(h)), 2)
})

test_that("persons get 0-3 distinct hobbies in a long table", {
  set.seed(2)
  h <- tibble::tibble(hobby = paste0("h", 1:20), weight = NA_real_)
  w <- c(100, rep(1, 19))                      # one very popular hobby
  ph <- assign_hobbies(1:5000, h, w, c(0.2, 0.3, 0.3, 0.2))
  expect_false(anyDuplicated(paste(ph$person_id, ph$hobby)) > 0)
  per_person <- table(ph$person_id)
  expect_true(all(per_person >= 1 & per_person <= 3))
  expect_equal(mean(!(1:5000 %in% ph$person_id)), 0.2, tolerance = 0.03)
  expect_equal(hobbies_as_text(ph[ph$person_id == ph$person_id[1], ], c(ph$person_id[1], -1))[2], "")
})

test_that("the hobby file is read without losing the first row", {
  skip_if(length(Sys.glob(file.path(root, "data", "hobbies*.xlsx"))) == 0, "hobbies.xlsx not in data/")
  h <- read_hobbies(test_config()) |> suppressMessages()
  expect_true(nrow(h) >= 10)
  expect_false(anyDuplicated(h$hobby) > 0)
})
