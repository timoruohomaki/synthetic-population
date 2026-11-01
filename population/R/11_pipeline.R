# Step 11: the whole pipeline in one function --------------------------------
#
# What you'll learn:
#   - composing small functions into a pipeline
#   - set.seed(): the same seed gives the same population every time
#   - dplyr::mutate() to add the identifier columns, select() to order them

#' Generate a synthetic Finnish population.
#'
#' @param n Number of persons (overrides run.n_persons).
#' @param seed Random seed (overrides run.seed).
#' @param hetu_mode "test_series" or "month_offset" (overrides hetu.mode).
#' @param write Save files to the output folder? FALSE just returns the table.
#' @param root The population project folder; found automatically.
#' @return A tibble with one row per person.
generate_population <- function(n = NULL, seed = NULL, hetu_mode = NULL,
                                write = TRUE,
                                root = getOption("population.root", find_project_root())) {
  overrides <- list(run = list(n_persons = n, seed = seed), hetu = list(mode = hetu_mode))
  overrides <- lapply(overrides, function(x) Filter(Negate(is.null), x))
  cfg <- load_config(root, overrides)
  log_info("Generating ", fmt_int(cfg$run$n_persons), " persons (seed ", cfg$run$seed,
           ", hetu mode ", cfg$hetu$mode, ")")
  set.seed(cfg$run$seed)

  names_list <- timed("Read names", read_names(cfg))
  postcodes <- timed("Read postcodes", read_postcodes(cfg))
  addresses <- timed("Loaded addresses", load_addresses(cfg, postcodes))

  pop <- timed("Drew people", draw_people(cfg, names_list, addresses))
  pop <- timed("Added identifiers and contact details", pop |>
    dplyr::mutate(
      hetu = make_hetu(birth_date, sex, cfg$hetu$mode, cfg$hetu$new_century_marker_share),
      iban = make_iban(dplyr::n(), cfg$iban$bank_code),
      email = make_email(first_name, last_name, cfg$contact$email_domains),
      phone = make_phone(dplyr::n(), cfg$contact$phone_prefixes)) |>
    dplyr::select(dplyr::all_of(POPULATION_COLUMNS)))

  timed("Validated", validate_population(pop, cfg))
  if (write) {
    paths <- write_population(pop, cfg)
    log_info("Done. Files:\n  ", paste(paths, collapse = "\n  "))
  }
  pop
}

