#!/usr/bin/env Rscript
# Run dashboard tests from the ccms-synth project root: Rscript dashboard/tests/run_tests.R
suppressPackageStartupMessages({ library(testthat); library(data.table) })
app_dir <- normalizePath("dashboard")
for (f in sort(list.files(file.path(app_dir, "R"), pattern = "\\.R$", full.names = TRUE))) source(f)
res <- test_dir(file.path(app_dir, "tests"), filter = "kpi|app", reporter = "summary", stop_on_failure = FALSE,
                env = environment())
df <- as.data.frame(res)
quit(save = "no", status = if (sum(df$failed) + sum(df$error) > 0) 1L else 0L)
