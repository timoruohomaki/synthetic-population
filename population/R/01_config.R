# Step 1: read and check the configuration ------------------------------------
#
# What you'll learn:
#   - reading YAML into an R list with yaml::read_yaml()
#   - modifying nested lists ($ and [[ ]]) and modifyList()
#   - validating values before doing any heavy work

#' Read config.yaml and apply overrides, e.g. list(run = list(n_persons = 1e6)).
load_config <- function(root, overrides = list()) {
  path <- file.path(root, "config.yaml")
  if (!file.exists(path)) abort("Configuration not found: ", path)
  cfg <- tryCatch(yaml::read_yaml(path),
                  error = function(e) abort("Invalid YAML in ", path, ": ", conditionMessage(e)))
  cfg <- utils::modifyList(cfg, overrides)
  cfg$root <- root
  validate_config(cfg)
  cfg$run$reference_date <- as.Date(cfg$run$reference_date)
  cfg
}

validate_config <- function(cfg) {
  n <- cfg$run$n_persons
  if (!is.numeric(n) || length(n) != 1 || n < 1 || n != round(n)) {
    abort("run.n_persons must be a whole number >= 1, got: ", format(n))
  }
  if (is.na(as.Date(cfg$run$reference_date, optional = TRUE))) {
    abort("run.reference_date must be an ISO 8601 date (YYYY-MM-DD)")
  }
  if (!cfg$hetu$mode %in% c("test_series", "month_offset")) {
    abort("hetu.mode must be 'test_series' or 'month_offset', got: ", cfg$hetu$mode)
  }
  share <- cfg$hetu$new_century_marker_share
  if (!is.numeric(share) || share < 0 || share > 1) abort("hetu.new_century_marker_share must be 0..1")
  if (!grepl("^[0-9]{1,4}$", cfg$iban$bank_code)) abort("iban.bank_code must be 1-4 digits")
  bands <- cfg$people$age_bands
  ok <- vapply(bands, function(b) b$from >= 0 && b$to >= b$from && b$to <= 120 && b$weight > 0, logical(1))
  if (!all(ok)) abort("people.age_bands: each band needs 0 <= from <= to <= 120 and weight > 0")
  probs <- unlist(cfg$people$given_name_counts)
  if (length(probs) < 1 || any(probs < 0) || sum(probs) <= 0) {
    abort("people.given_name_counts must be non-negative weights")
  }
  bad <- setdiff(cfg$run$formats, c("csv", "rds", "parquet"))
  if (length(bad) > 0) abort("run.formats: unknown format(s) ", paste(bad, collapse = ", "))
  if (isTRUE(cfg$companies$enabled)) validate_company_config(cfg$companies)
  invisible(TRUE)
}

validate_company_config <- function(cc) {
  if (!is.numeric(cc$per_1000_persons) || cc$per_1000_persons <= 0 || cc$per_1000_persons > 500) {
    abort("companies.per_1000_persons must be between 0 and 500")
  }
  ages <- unlist(cc$contact_age)
  if (length(ages) != 2 || ages[1] < 18 || ages[2] < ages[1]) abort("companies.contact_age must be [min >= 18, max]")
  if (is.na(as.Date(cc$first_registration, optional = TRUE))) abort("companies.first_registration must be YYYY-MM-DD")
  forms <- unlist(cc$forms)
  if (!all(names(forms) %in% c("oy", "ky", "ay", "osk", "tmi")) || any(forms < 0) || sum(forms) <= 0) {
    abort("companies.forms: use oy, ky, ay, osk, tmi with non-negative weights")
  }
  probs <- c(unlist(cc$registers), cc$sole_trader_home_share)
  if (any(!is.numeric(probs) | probs < 0 | probs > 1)) abort("companies.registers and sole_trader_home_share must be 0..1")
  if (!grepl("^\\.[a-z]+$", cc$domain_suffix)) abort("companies.domain_suffix must look like '.example'")
}
