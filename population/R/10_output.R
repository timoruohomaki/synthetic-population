# Step 10: save the population -----------------------------------------------
#
# What you'll learn:
#   - CSV for people: write_excel_csv2() uses ";" and decimal "," and adds a
#     byte order mark so Excel opens UTF-8 (ä, ö, å) correctly
#   - RDS for R: saveRDS() keeps column types (Dates stay Dates) and is small
#   - Parquet for big data tools, when the arrow package is installed
#   - requireNamespace() to use a package only when it is available

#' Final column order.
POPULATION_COLUMNS <- c(
  "person_id", "hetu", "first_name", "given_names", "last_name", "sex",
  "birth_date", "age", "street_address", "postal_code", "post_office",
  "municipality_code", "municipality", "region_code", "region",
  "email", "phone", "iban"
)

#' Write `pop` in every configured format; returns the written paths.
write_population <- function(pop, cfg) {
  out_dir <- file.path(cfg$root, cfg$run$output_dir)
  stem <- sprintf("population_%s_%s", format(nrow(pop), scientific = FALSE),
                  format(Sys.Date(), "%Y-%m-%d"))
  written <- character(0)
  for (fmt in unlist(cfg$run$formats)) {
    path <- file.path(out_dir, paste0(stem, ".", fmt))
    if (fmt == "parquet" && !requireNamespace("arrow", quietly = TRUE)) {
      log_info("Skipping parquet: install.packages(\"arrow\") to enable it")
      next
    }
    writer <- switch(fmt,
      csv = function(p) readr::write_excel_csv2(pop, p, na = ""),
      rds = function(p) saveRDS(pop, p, compress = TRUE),
      parquet = function(p) arrow::write_parquet(pop, p))
    timed(paste0("Wrote ", basename(path)), write_atomically(path, writer))
    written <- c(written, path)
  }
  invisible(written)
}
