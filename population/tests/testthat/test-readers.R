test_that("the source files can be read (skipped without downloaded data)", {
  skip_without_data()
  cfg <- test_config()
  names_list <- read_names(cfg) |> suppressMessages()
  expect_true(all(vapply(names_list, nrow, integer(1)) > 1000))
  postcodes <- read_postcodes(cfg) |> suppressMessages()
  expect_true(all(grepl("^[0-9]{5}$", postcodes$postal_code)))
  municipalities <- read_municipalities(cfg) |> suppressMessages()
  expect_true("091" %in% municipalities$municipality_code)
})

test_that("config overrides and validation work", {
  expect_equal(test_config(run = list(n_persons = 5))$run$n_persons, 5L)
  expect_error(load_config(root, list(hetu = list(mode = "random"))), "hetu.mode")
  expect_error(load_config(root, list(run = list(n_persons = -1))), "n_persons")
})
