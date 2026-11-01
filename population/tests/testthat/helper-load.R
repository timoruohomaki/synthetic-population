# Load the step files from R/ before the tests run.
root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
for (f in sort(list.files(file.path(root, "R"), pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE))) {
  sys.source(f, envir = globalenv())
}
options(population.root = root)

#' A tiny configuration that does not need the source files.
test_config <- function(...) {
  cfg <- load_config(root, list(...))
  cfg$run$n_persons <- as.integer(cfg$run$n_persons)
  cfg
}

#' Skip a test when the downloaded source files are not in data/.
skip_without_data <- function() {
  ok <- length(Sys.glob(file.path(root, "data", "Suomi_osoitteet_*.OPT"))) > 0
  testthat::skip_if_not(ok, "Source data not downloaded (see data/README.md)")
}
