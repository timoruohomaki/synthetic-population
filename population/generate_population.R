# Synthetic Finnish population - entry point ----------------------------------
#
# In RStudio: open synthetic-population.Rproj, then
#   source("generate_population.R")
#   res <- generate_population(n = 10000)           # also writes output/ files
#   res <- generate_population(n = 1000, companies = TRUE, write = FALSE)
#   View(res$persons); View(res$companies)
#
# From a terminal (in the population folder):
#   Rscript generate_population.R --n 1000000 --seed 42 --hetu-mode month_offset
#   Rscript generate_population.R --n 100000 --companies true
#
# Settings live in config.yaml; source files go to data/ (see data/README.md).

local({
  needed <- c("dplyr", "readr", "readxl", "tibble", "yaml")
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Install the missing packages first: install.packages(c(\"",
         paste(missing, collapse = "\", \""), "\"))", call. = FALSE)
  }
  # The folder of this script: from source(), from Rscript's --file=, or the
  # working directory as a last resort.
  file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  here <- if (!is.null(ofile)) dirname(ofile) else if (length(file_arg) == 1) dirname(file_arg) else "."
  steps <- sort(list.files(file.path(here, "R"), pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE))
  if (length(steps) == 0) stop("No R/ step files next to generate_population.R", call. = FALSE)
  for (f in steps) sys.source(f, envir = globalenv())
  options(population.root = normalizePath(here))
})

#' Read "--name value" pairs from the command line into a named list.
parse_cli <- function(args) {
  known <- c("--n" = "n", "--seed" = "seed", "--hetu-mode" = "hetu_mode", "--companies" = "companies")
  out <- list()
  i <- 1
  while (i <= length(args)) {
    key <- args[i]
    if (key %in% c("-h", "--help")) {
      cat("Usage: Rscript generate_population.R [--n N] [--seed S]",
          "[--hetu-mode test_series|month_offset] [--companies true|false]\n")
      quit(status = 0)
    }
    if (!key %in% names(known) || i == length(args)) abort("Unknown or incomplete argument: ", key)
    value <- args[i + 1]
    out[[known[[key]]]] <- switch(key,
      "--hetu-mode" = value,
      "--companies" = if (tolower(value) %in% c("true", "false")) tolower(value) == "true" else NA,
      as.numeric(value))
    i <- i + 2
  }
  if (anyNA(unlist(out))) abort("--n and --seed must be numbers, --companies true or false")
  out
}

if (!interactive() && sys.nframe() == 0) {
  status <- tryCatch({
    args <- parse_cli(commandArgs(trailingOnly = TRUE))
    do.call(generate_population, args)
    0
  }, error = function(e) {
    message("ERROR: ", conditionMessage(e))
    1
  })
  quit(status = status, save = "no")
}
