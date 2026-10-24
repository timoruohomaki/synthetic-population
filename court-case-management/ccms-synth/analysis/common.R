# Shared helpers for analysis scripts ---------------------------------------

suppressPackageStartupMessages({
  library(DBI)
  library(data.table)
})

#' Open the generated database read-only; fails clearly when it is missing.
open_db <- function(path = Sys.getenv("CCMS_DB", "output/ccms_synth.sqlite")) {
  if (!file.exists(path)) {
    stop(sprintf("Database '%s' not found. Run: Rscript run.R --overwrite", path), call. = FALSE)
  }
  dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
}

q <- function(con, sql) as.data.table(dbGetQuery(con, sql))

truth_param <- function(con, prefix) {
  tp <- q(con, "SELECT parameter, value FROM truth_parameter")
  tp[startsWith(parameter, prefix)][, parameter := sub(prefix, "", parameter, fixed = TRUE)][]
}

#' Format numbers for Finnish locale output (thousands '.', decimal ',').
fmt_fi <- function(x, digits = 3) formatC(x, format = "f", digits = digits, big.mark = ".", decimal.mark = ",")

#' Print a coefficient comparison table: estimate vs. truth.
compare_coefs <- function(fit, mapping, truth) {
  est <- coef(summary(fit))
  rows <- lapply(names(mapping), function(term) {
    p <- mapping[[term]]
    data.table(term = term, truth = truth[parameter == p, value],
               estimate = est[term, 1], std_error = est[term, 2])
  })
  out <- rbindlist(rows)
  out[, z_vs_truth := (estimate - truth) / std_error]
  out[, `:=`(truth = fmt_fi(truth), estimate = fmt_fi(estimate), std_error = fmt_fi(std_error),
             z_vs_truth = fmt_fi(z_vs_truth, 2))]
  print(out)
  invisible(out)
}

run_analysis <- function(fun) {
  status <- tryCatch({ fun(); 0L }, error = function(e) { message("Analysis failed: ", conditionMessage(e)); 1L })
  invisible(status)
}
