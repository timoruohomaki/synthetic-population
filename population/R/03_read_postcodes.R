# Step 3: read Posti's postcode file and Statistics Finland's municipality list
#
# What you'll learn:
#   - fixed-width files with readr::read_fwf() and fwf_positions()
#   - character encodings: Posti's files are ISO 8859-1 (latin1), not UTF-8
#   - cleaning text with gsub() and trimws()

#' Field positions of the postcode file (PCF), from Posti's record description.
PCF_FIELDS <- readr::fwf_positions(
  start = c(1, 14, 19, 49, 111, 177, 180, 200, 220),
  end   = c(5, 18, 48, 78, 111, 179, 199, 219, 220),
  col_names = c("record", "postal_code", "post_office_fi", "post_office_sv", "type",
                "pcf_municipality_code", "pcf_municipality_fi", "pcf_municipality_sv", "language")
)

#' Read the postcode file: one row per postal code.
#' language: 1 = Finnish, 2-3 = bilingual, 4 = Swedish-speaking municipality.
read_postcodes <- function(cfg) {
  path <- find_source_file(file.path(cfg$root, "data"), cfg$sources$postcodes)
  log_info("Reading postcodes: ", basename(path))
  pcf <- readr::read_fwf(path, col_positions = PCF_FIELDS,
                         col_types = readr::cols(.default = readr::col_character()),
                         locale = readr::locale(encoding = "latin1"), progress = FALSE)
  pcf <- pcf |>
    dplyr::filter(record == "PONOT") |>
    dplyr::mutate(dplyr::across(dplyr::everything(), trimws)) |>
    dplyr::select(-record)
  if (nrow(pcf) < 1000 || anyDuplicated(pcf$postal_code)) {
    abort("Postcode file ", basename(path), " looks wrong: ", nrow(pcf), " rows or duplicate codes")
  }
  pcf
}

#' Read the municipality classification (code;level;classificationName;).
#' Codes are stored like "'020'", so quotes and apostrophes are removed.
read_municipalities <- function(cfg) {
  path <- find_source_file(file.path(cfg$root, "data"), cfg$sources$municipalities)
  log_info("Reading municipalities: ", basename(path))
  # The trailing ";" on each line creates an empty 4th column; name_repair keeps it quiet.
  raw <- readr::read_delim(path, delim = ";", col_types = readr::cols(.default = "c"),
                           locale = readr::locale(encoding = "UTF-8"), progress = FALSE,
                           name_repair = "unique_quiet")
  require_columns(raw, c("code", "classificationName"), basename(path))
  out <- raw |>
    dplyr::transmute(municipality_code = gsub("[\"']", "", code),
                     municipality = trimws(classificationName)) |>
    dplyr::filter(grepl("^[0-9]{3}$", municipality_code))
  if (nrow(out) < 250) abort("Municipality list ", basename(path), " has only ", nrow(out), " rows")
  out
}

#' Read the DVV region (maakunta) codes shipped in reference/.
read_regions <- function(cfg) {
  path <- file.path(cfg$root, "reference", "regions_dvv.csv")
  if (!file.exists(path)) abort("Missing reference file ", path)
  readr::read_delim(path, delim = ";", col_types = "ccc", progress = FALSE)
}
