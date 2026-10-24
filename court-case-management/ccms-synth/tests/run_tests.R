#!/usr/bin/env Rscript
# Run the test suite from the project root: Rscript tests/run_tests.R
suppressPackageStartupMessages({
  library(testthat)
  library(data.table)
})
options(ccms.root = normalizePath("."))
proj <- function(...) file.path(getOption("ccms.root"), ...)
for (f in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) sys.source(f, envir = globalenv())
res <- test_dir("tests/testthat", reporter = "summary", stop_on_failure = FALSE)
failed <- sum(as.data.frame(res)$failed) + sum(as.data.frame(res)$error)
quit(save = "no", status = if (failed > 0) 1L else 0L)
