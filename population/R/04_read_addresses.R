# Step 4: read DVV's building address file and build a clean address table ---
#
# What you'll learn:
#   - reading a large (400 MB, 3,9 million rows) delimited file efficiently:
#     only the columns you need (col_select), all as text, the right encoding
#   - filter() to keep only usable rows, joins with dplyr::left_join()
#   - if_else() / dplyr::coalesce() for choosing between columns
#   - caching an expensive result with saveRDS() / readRDS()

#' Column numbers of the address file (DVV record description, 16 fields).
ADDRESS_COLUMNS <- c(municipality_code = 2, region_code = 3, usage = 4,
                     street_fi = 8, street_sv = 9, street_number = 10, postal_code = 11)

#' Read the raw file: one row per building address.
read_address_file <- function(path) {
  log_info("Reading addresses: ", basename(path), " (", round(file.size(path) / 1e6), " MB)")
  readr::read_delim(path, delim = ";", col_names = FALSE, quote = "",
                    col_select = dplyr::all_of(unname(ADDRESS_COLUMNS)),
                    col_types = readr::cols(.default = readr::col_character()),
                    locale = readr::locale(encoding = "latin1"), progress = FALSE) |>
    stats::setNames(names(ADDRESS_COLUMNS))
}

#' Keep residential buildings that have a street name, number and postcode,
#' then add post office, municipality and region names.
clean_addresses <- function(raw, postcodes, municipalities, regions) {
  addr <- raw |>
    dplyr::filter(usage == "1", !is.na(street_number), !is.na(postal_code),
                  !is.na(street_fi) | !is.na(street_sv), !is.na(municipality_code)) |>
    dplyr::inner_join(postcodes, by = "postal_code") |>
    dplyr::left_join(municipalities, by = "municipality_code") |>
    dplyr::left_join(regions, by = "region_code")
  # Swedish-speaking municipalities get Swedish street and post office names.
  swedish <- addr$language == "4" & !is.na(addr$street_sv)
  addr |>
    dplyr::mutate(
      street = dplyr::if_else(swedish, street_sv, dplyr::coalesce(street_fi, street_sv)),
      street_address = paste(street, street_number),
      post_office = dplyr::if_else(swedish, post_office_sv, post_office_fi),
      municipality = dplyr::coalesce(municipality, pcf_municipality_fi)) |>
    dplyr::select(street_address, postal_code, post_office, municipality_code,
                  municipality, region_code, region = region_fi)
}

#' Clean address table, read from the cache when the same source files were
#' used before (the cache file name contains the source file names).
load_addresses <- function(cfg, postcodes) {
  data_dir <- file.path(cfg$root, "data")
  path <- find_source_file(data_dir, cfg$sources$addresses)
  key <- paste(tools::file_path_sans_ext(basename(path)),
               tools::file_path_sans_ext(basename(find_source_file(data_dir, cfg$sources$postcodes))),
               sep = "__")
  cache <- file.path(data_dir, "cache", paste0("addresses__", key, ".rds"))
  if (isTRUE(cfg$sources$cache_addresses) && file.exists(cache)) {
    log_info("Using cached addresses: ", basename(cache))
    return(readRDS(cache))
  }
  addr <- clean_addresses(read_address_file(path), postcodes,
                          read_municipalities(cfg), read_regions(cfg))
  if (nrow(addr) < 1000) abort("Only ", nrow(addr), " usable addresses in ", basename(path))
  log_info("Usable residential addresses: ", fmt_int(nrow(addr)))
  if (isTRUE(cfg$sources$cache_addresses)) {
    write_atomically(cache, function(p) saveRDS(addr, p))
  }
  addr
}
