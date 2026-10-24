#!/usr/bin/env Rscript
# ccms-synth: generate a synthetic court case management dataset.
# Usage: Rscript run.R [--config config/simulation.yaml] [--codes config/codes.yaml]
#                      [--out output] [--cases N] [--seed N] [--overwrite] [--no-csv] [--postgres]

REQUIRED_PKGS <- c(DBI = "1.1.0", RSQLite = "2.2.0", data.table = "1.14.0", yaml = "2.3.0")

check_packages <- function(pkgs) {
  for (p in names(pkgs)) {
    if (!requireNamespace(p, quietly = TRUE)) {
      stop(sprintf("Package '%s' (>= %s) is required: install.packages('%s')", p, pkgs[[p]], p), call. = FALSE)
    }
    if (utils::packageVersion(p) < pkgs[[p]]) {
      stop(sprintf("Package '%s' >= %s required, found %s", p, pkgs[[p]], utils::packageVersion(p)), call. = FALSE)
    }
  }
}

parse_args <- function(args) {
  opts <- list(config = "config/simulation.yaml", codes = "config/codes.yaml", out = "output",
               cases = NA_real_, seed = NA_real_, overwrite = FALSE, csv = TRUE, postgres = FALSE)
  i <- 1L
  while (i <= length(args)) {
    a <- args[i]
    if (a == "--overwrite") { opts$overwrite <- TRUE; i <- i + 1L; next }
    if (a == "--no-csv") { opts$csv <- FALSE; i <- i + 1L; next }
    if (a == "--postgres") { opts$postgres <- TRUE; i <- i + 1L; next }
    key <- sub("^--", "", a)
    if (!key %in% c("config", "codes", "out", "cases", "seed") || i == length(args)) {
      stop(sprintf("Unknown or incomplete argument: %s", a), call. = FALSE)
    }
    val <- args[i + 1L]
    opts[[key]] <- if (key %in% c("cases", "seed")) as.numeric(val) else val
    if (key %in% c("cases", "seed") && is.na(opts[[key]])) stop(sprintf("--%s must be numeric", key), call. = FALSE)
    i <- i + 2L
  }
  opts
}

#' Locate the project root (directory of this script) and source R/ files.
source_project <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  root <- if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
  for (f in sort(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE))) {
    sys.source(f, envir = globalenv())
  }
  root
}

main <- function() {
  check_packages(REQUIRED_PKGS)
  suppressPackageStartupMessages(library(data.table))
  opts <- parse_args(commandArgs(trailingOnly = TRUE))
  root <- source_project()
  resolve <- function(p) if (grepl("^(/|[A-Za-z]:)", p)) p else file.path(root, p)
  cfg <- load_config(resolve(opts$config), resolve(opts$codes))
  if (!is.na(opts$cases)) cfg$volume$cases_per_year <- opts$cases
  if (!is.na(opts$seed)) cfg$run$seed <- opts$seed
  generate_dataset(cfg, out_dir = resolve(opts$out), sql_dir = file.path(root, "sql", "sqlite"),
                   overwrite = opts$overwrite, write_csv = opts$csv,
                   pg_sql_dir = if (opts$postgres) file.path(root, "sql", "postgres") else NULL)
}

status <- tryCatch({ main(); 0L },
  ccms_validation_error = function(e) { message("Configuration error: ", conditionMessage(e)); 2L },
  ccms_config_error = function(e) { message("Configuration error: ", conditionMessage(e)); 2L },
  ccms_io_error = function(e) { message("I/O error: ", conditionMessage(e)); 3L },
  error = function(e) { message("Error: ", conditionMessage(e)); 1L })
quit(save = "no", status = status)
