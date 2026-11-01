# Step 15 (companies): check the companies against the persons ---------------
#
# What you'll learn:
#   - checking relations between two tables with match() and %in%
#   - the same "named list of checks" pattern as in step 9

#' Run all company checks; stop with a list of failures.
validate_companies <- function(companies, pop, cfg) {
  required <- c("business_id", "company_name", "company_form", "registration_date",
                "main_business_line", "street_address", "postal_code", "home_municipality",
                "contact_person_id", "contact_role", "website", "email")
  require_columns(companies, required, "Company table")
  person <- match(companies$contact_person_id, pop$person_id)
  tmi <- companies$company_form == COMPANY_FORMS[["tmi"]]
  tmi_person <- match(pop$business_id, companies$business_id[tmi])
  has_id <- !is.na(pop$business_id)
  ages <- unlist(cfg$companies$contact_age)
  checks <- c(
    "required columns have no missing values" = !anyNA(companies[required]),
    "business_id is unique" = !anyDuplicated(companies$business_id),
    "business_id passes the checksum" = all(business_id_is_valid(companies$business_id)),
    "company_name is unique" = !anyDuplicated(tolower(companies$company_name)),
    "domains are unique" = !anyDuplicated(companies$website),
    "every contact person exists" = !anyNA(person),
    "nobody is the contact of two companies" = !anyDuplicated(companies$contact_person_id),
    "contact lives in the company's postal code" =
      all(pop$postal_code[person] == companies$postal_code),
    "contact lives in the home municipality" =
      all(pop$municipality[person] == companies$home_municipality),
    "contact age is within companies.contact_age" =
      all(pop$age[person] >= ages[1] & pop$age[person] <= ages[2]),
    "contact was an adult when the company was registered" =
      all(age_on(pop$birth_date[person], companies$registration_date) >= ages[1]),
    "registration is not in the future" = all(companies$registration_date <= cfg$run$reference_date),
    "older companies have smaller Business IDs" =
      !is.unsorted(companies$business_id[order(companies$registration_date)]),
    "sole traders' persons carry the Business ID" =
      sum(has_id) == sum(tmi) && all(!is.na(tmi_person[has_id])),
    "VAT number only for the VAT register" =
      all(is.na(companies$vat_number) == !companies$vat_register)
  )
  checks[is.na(checks)] <- FALSE
  if (!all(checks)) {
    abort("Company validation failed:\n  - ", paste(names(checks)[!checks], collapse = "\n  - "))
  }
  log_info("All ", length(checks), " company checks passed for ", fmt_int(nrow(companies)), " companies")
  invisible(companies)
}
