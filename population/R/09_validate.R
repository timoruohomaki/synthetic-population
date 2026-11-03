# Step 9: check the result before saving it ----------------------------------
#
# Never trust generated data blindly: decode every code again and compare it
# with the columns it was made from.
#
# What you'll learn:
#   - writing checks as a named list of TRUE/FALSE results
#   - anyNA(), anyDuplicated() and all() on whole columns
#   - stopping with a report of every failed check, not just the first one

#' Run all checks; stop with a list of failures, or return the table invisibly.
validate_population <- function(pop, cfg) {
  required <- c("person_id", "hetu", "sex", "first_name", "given_names", "last_name",
                "birth_date", "street_address", "postal_code", "post_office",
                "municipality", "iban", "email", "phone")
  require_columns(pop, required, "Population table")
  parsed <- hetu_parse(pop$hetu)
  offset_mode <- cfg$hetu$mode == "month_offset"
  number <- parsed$individual_number
  checks <- c(
    "required columns have no missing values" = !anyNA(pop[required]),
    "person_id is unique" = !anyDuplicated(pop$person_id),
    "hetu is unique" = !anyDuplicated(pop$hetu),
    "hetu passes the checksum" = all(hetu_is_valid(pop$hetu, offset_mode, parsed)),
    "hetu birth date matches birth_date" = all(parsed$birth_date == pop$birth_date),
    "hetu individual number matches sex" = all(parsed$sex == pop$sex),
    "hetu month range matches the mode" = all(parsed$month_offset == offset_mode),
    "hetu number range matches the mode" =
      if (offset_mode) all(number <= 899) else all(number >= 900),
    "iban is unique" = !anyDuplicated(pop$iban),
    "iban passes the checksums" = all(iban_is_valid(pop$iban)),
    "iban uses the configured bank code" = all(startsWith(substr(pop$iban, 5, 18), cfg$iban$bank_code)),
    "email is unique" = !anyDuplicated(pop$email),
    "email uses a reserved domain" =
      all(sub(".*@", "", pop$email) %in% unlist(cfg$contact$email_domains)),
    "phone is unique" = !anyDuplicated(pop$phone),
    "phone uses the configured prefixes" =
      all(sub(" .*", "", pop$phone) %in% names(unlist(cfg$contact$phone_prefixes))),
    "postal code has 5 digits" = all(grepl("^[0-9]{5}$", pop$postal_code)),
    "age is within the age bands" = all(pop$age >= 0 & pop$age <= 120)
  )
  checks[is.na(checks)] <- FALSE
  if (!all(checks)) {
    abort("Validation failed:\n  - ", paste(names(checks)[!checks], collapse = "\n  - "))
  }
  log_info("All ", length(checks), " checks passed for ", fmt_int(nrow(pop)), " persons")
  invisible(pop)
}
