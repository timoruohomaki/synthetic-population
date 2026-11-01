# Run all tests: Rscript tests/run_tests.R (from the population folder),
# or in RStudio: testthat::test_dir("tests/testthat")
if (!requireNamespace("testthat", quietly = TRUE)) stop("install.packages(\"testthat\")")
here <- if (file.exists("tests/testthat")) "tests/testthat" else "testthat"
result <- testthat::test_dir(here, reporter = "summary", stop_on_failure = TRUE)
