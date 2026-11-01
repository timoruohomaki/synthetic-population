# Step 7: Finnish bank account numbers (IBAN) -------------------------------
#
# A Finnish IBAN is "FI" + 2 check digits + a 14-digit domestic account number
# (BBAN). The BBAN starts with a bank code and ends with a Luhn check digit.
# The default bank code "9" is not assigned to any bank in Finland, so the
# accounts are valid by checksum but cannot belong to a real customer.
#
# What you'll learn:
#   - keeping numbers as numbers: a 14-digit BBAN fits exactly in a double
#     (up to 2^53, about 9e15), so no string juggling is needed
#   - picking digits out of a number with %/% (integer division) and %% (remainder)
#   - the IBAN check (ISO 13616, mod 97) done with modular arithmetic
#   - formatting with sprintf(): "%014.0f" gives a zero-padded 14-digit number

#' Luhn check digit for 13-digit numbers (weights 2, 1, 2, ... from the right).
luhn_check_digit <- function(x13) {
  x13 <- as.numeric(x13)
  total <- numeric(length(x13))
  for (k in 0:12) {                       # a loop over digit positions, not rows
    digit <- (x13 %/% 10^k) %% 10         # k = 0 is the rightmost digit
    product <- digit * (if (k %% 2 == 0) 2 else 1)
    total <- total + product %/% 10 + product %% 10   # 14 -> 1 + 4
  }
  (10 - total %% 10) %% 10
}

#' IBAN check digits for numeric BBANs. The rule: put "FI00" at the end
#' (F = 15, I = 18, so "151800"), take mod 97, subtract from 98. Since
#' (a * 10^6 + b) mod 97 = ((a mod 97) * 10^6 + b) mod 97, the 20-digit number
#' is never needed.
iban_check_digits <- function(bban) {
  98 - ((bban %% 97) * 1e6 + 151800) %% 97
}

#' Generate `n` unique Finnish IBANs whose BBAN starts with `bank_code`.
make_iban <- function(n, bank_code = "9") {
  free <- 13 - nchar(bank_code)           # random digits before the Luhn digit
  if (free < 6) abort("Bank code '", bank_code, "' is too long")
  if (n > 0.5 * 10^free) abort("Too many accounts for bank code '", bank_code, "'")
  body <- numeric(0)
  while (length(body) < n) {              # draw, drop duplicates, top up if needed
    random <- floor(stats::runif(n - length(body)) * 10^free)
    body <- unique(c(body, as.numeric(bank_code) * 10^free + random))
  }
  bban <- body * 10 + luhn_check_digit(body)
  sprintf("FI%02.0f%014.0f", iban_check_digits(bban), bban)
}

#' Print an IBAN in groups of four: "FI21 1234 5600 0007 85".
iban_format <- function(iban) {
  trimws(gsub("(.{4})", "\\1 ", gsub(" ", "", iban)))
}

#' TRUE for Finnish IBANs with correct length, IBAN check digits and Luhn digit.
iban_is_valid <- function(iban) {
  x <- gsub(" ", "", toupper(iban))
  ok <- !is.na(x) & grepl("^FI[0-9]{16}$", x)
  result <- rep(FALSE, length(x))
  if (!any(ok)) return(result)
  bban <- as.numeric(substr(x[ok], 5, 18))
  check <- as.numeric(substr(x[ok], 3, 4))
  luhn_ok <- luhn_check_digit(bban %/% 10) == bban %% 10
  result[ok] <- iban_check_digits(bban) == check & luhn_ok
  result
}
