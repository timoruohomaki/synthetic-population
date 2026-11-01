# Step 16: the whole pipeline in one function --------------------------------
#
# What you'll learn:
#   - composing small functions into a pipeline
#   - set.seed(): the same seed gives the same population every time
#   - dplyr::mutate() to add the identifier columns, select() to order them
#   - optional steps controlled by configuration

#' Generate a synthetic Finnish population and, optionally, companies.
#'
#' @param n Number of persons (overrides run.n_persons).
#' @param seed Random seed (overrides run.seed).
#' @param hetu_mode "test_series" or "month_offset" (overrides hetu.mode).
#' @param companies TRUE/FALSE to override companies.enabled.
#' @param write Save files to the output folder? FALSE just returns the tables.
#' @param root The population project folder; found automatically.
#' @return A list: `persons` (one row per person) and `companies` (NULL when
#'   companies are not generated).
generate_population <- function(n = NULL, seed = NULL, hetu_mode = NULL, companies = NULL,
                                write = TRUE,
                                root = getOption("population.root", find_project_root())) {
  overrides <- list(run = list(n_persons = n, seed = seed), hetu = list(mode = hetu_mode),
                    companies = list(enabled = companies))
  overrides <- lapply(overrides, function(x) Filter(Negate(is.null), x))
  cfg <- load_config(root, overrides)
  log_info("Generating ", fmt_int(cfg$run$n_persons), " persons (seed ", cfg$run$seed,
           ", hetu mode ", cfg$hetu$mode, ", companies ", isTRUE(cfg$companies$enabled), ")")
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
      phone = make_phone(dplyr::n(), cfg$contact$phone_prefixes),
      business_id = NA_character_) |>
    dplyr::select(dplyr::all_of(POPULATION_COLUMNS)))
  timed("Validated persons", validate_population(pop, cfg))

  firms <- NULL
  if (isTRUE(cfg$companies$enabled)) {          # the optional last step
    firms <- timed("Drew companies", draw_companies(cfg, pop, addresses))
    pop <- add_business_ids(pop, firms)
    timed("Validated companies", validate_companies(firms, pop, cfg))
  }
  if (write) {
    paths <- c(write_table(pop, cfg, "population"),
               if (!is.null(firms)) write_table(firms, cfg, "companies"))
    log_info("Done. Files:\n  ", paste(paths, collapse = "\n  "))
  }
  list(persons = pop, companies = firms)
}
