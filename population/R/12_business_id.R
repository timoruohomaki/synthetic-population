# Step 12 (companies): Finnish Business IDs (Y-tunnus) ----------------------
#
# Format 1234567-8: seven digits, a dash and a check digit. Weights 7, 9, 10,
# 5, 8, 4, 2; remainder r = sum mod 11. r = 0 gives check digit 0, r = 1 is
# never issued, otherwise the check digit is 11 - r. Example: 0153791-8.
#
# Business IDs are issued in increasing order; in 2026 new IDs start with 3.
# There is no reserved test range, so by default the generated IDs start with
# 9, far beyond the issued range. That is safe for years, not forever.
#
# What you'll learn:
#   - weighted sums with %*% (matrix product): all IDs in one multiplication
#   - dropping impossible values (remainder 1) and drawing replacements
#   - sorting one vector by another: older companies get smaller IDs

YTUNNUS_WEIGHTS <- c(7, 9, 10, 5, 8, 4, 2)

#' Check digit for 7-digit numbers; NA when the remainder is 1 (not valid).
business_id_check_digit <- function(x7) {
  x7 <- as.numeric(x7)
  digits <- vapply(6:0, function(k) (x7 %/% 10^k) %% 10, numeric(length(x7)))
  digits <- matrix(digits, nrow = length(x7))           # one row per number
  r <- as.vector(digits %*% YTUNNUS_WEIGHTS) %% 11
  ifelse(r == 0, 0, ifelse(r == 1, NA, 11 - r))
}

#' `n` unique Business IDs whose first digit is `first_digit`.
make_business_id <- function(n, first_digit = "9") {
  if (!grepl("^[0-9]$", first_digit)) abort("companies.business_id_first_digit must be one digit")
  base <- as.numeric(first_digit) * 1e6
  if (n > 5e5) abort("At most 500.000 Business IDs per first digit")
  body <- numeric(0)
  while (length(body) < n) {     # draw, drop remainder-1 numbers and duplicates
    draw <- base + floor(stats::runif(2 * (n - length(body))) * 1e6)
    draw <- draw[!is.na(business_id_check_digit(draw))]
    body <- unique(c(body, draw))
  }
  body <- body[seq_len(n)]
  sprintf("%07.0f-%.0f", body, business_id_check_digit(body))
}

#' TRUE for well-formed Business IDs with a correct check digit.
business_id_is_valid <- function(x) {
  ok <- !is.na(x) & grepl("^[0-9]{7}-[0-9]$", x)
  check <- rep(NA_real_, length(x))
  check[ok] <- business_id_check_digit(substr(x[ok], 1, 7))
  ok & !is.na(check) & check == suppressWarnings(as.numeric(substr(x, 9, 9)))
}

#' Finnish VAT number: "FI" + the Business ID without the dash.
vat_number <- function(business_id) paste0("FI", sub("-", "", business_id, fixed = TRUE))
