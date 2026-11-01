# Step 6: Finnish personal identity codes (henkilötunnus, "hetu") ----------
#
# Format DDMMYYCNNNT: birth date, century marker C, individual number NNN
# (odd = male, even = female) and check character T = the 9-digit number
# DDMMYYNNN modulo 31, looked up in HETU_CHECK_CHARS.
#
# What you'll learn:
#   - building strings with sprintf() and paste0(), and taking them apart with substr()
#   - modular arithmetic (%%) - the whole checksum is one line
#   - numbering rows inside groups without a loop (rank_within() in 00_utils.R)

HETU_CHECK_CHARS <- "0123456789ABCDEFHJKLMNPRSTUVWXY"
HETU_MARKERS <- list("18" = "+", "19" = c("-", "Y", "X", "W", "V", "U"), "20" = c("A", "B", "C", "D", "E", "F"))

#' Check character for 6-digit date strings and 3-digit individual numbers.
hetu_check_char <- function(date6, nnn) {
  remainder <- as.numeric(paste0(date6, nnn)) %% 31
  strsplit(HETU_CHECK_CHARS, "")[[1]][remainder + 1]   # remainder 0 -> "0", 30 -> "Y"
}

#' Century markers; a share of codes use the alternatives added in 2023.
century_marker <- function(year, new_share = 0) {
  century <- substr(sprintf("%04d", year), 1, 2)
  if (any(!century %in% names(HETU_MARKERS))) abort("Birth years must be 1800-2099")
  use_new <- stats::runif(length(year)) < new_share & century != "18"
  marker <- vapply(HETU_MARKERS[century], `[`, character(1), 1)
  alternatives <- HETU_MARKERS[century[use_new]]
  marker[use_new] <- vapply(alternatives, function(m) sample(m[-1], 1), character(1))
  unname(marker)
}

#' Individual numbers, unique for each birth date and sex.
#' test_series: 900-999 (50 per sex per day); month_offset: 002-899 (449).
individual_numbers <- function(birth_date, sex, mode) {
  start <- if (mode == "test_series") c(F = 900, M = 901) else c(F = 2, M = 3)
  end <- if (mode == "test_series") c(F = 998, M = 999) else c(F = 898, M = 899)
  pool_size <- (end[["F"]] - start[["F"]]) / 2 + 1
  key <- as.integer(birth_date) * 2L + (sex == "M")   # one number per date and sex
  rank <- rank_within(key, shuffle = TRUE)          # 1, 2, 3 ... in random order
  if (max(rank) > pool_size) {
    abort("More than ", pool_size, " people of the same sex share a birth date. ",
          "Use hetu.mode = 'month_offset' (449 numbers per day) or fewer persons.")
  }
  group <- match(key, unique(key))                  # group number 1, 2, 3 ...
  offset <- sample.int(pool_size, max(group), replace = TRUE)[group]  # random start per group
  step <- (offset + rank - 2) %% pool_size
  as.integer(unname(start[sex]) + 2 * step)
}

#' Generate personal identity codes for birth dates and sexes ("F"/"M").
make_hetu <- function(birth_date, sex, mode = "test_series", new_marker_share = 0) {
  year <- as.integer(format(birth_date, "%Y"))
  month <- as.integer(format(birth_date, "%m")) + if (mode == "month_offset") 12L else 0L
  date6 <- sprintf("%s%02d%02d", format(birth_date, "%d"), month, year %% 100)
  nnn <- sprintf("%03d", individual_numbers(birth_date, sex, mode))
  paste0(date6, century_marker(year, new_marker_share), nnn, hetu_check_char(date6, nnn))
}

#' Take codes apart. Returns a tibble with birth_date (real date, month offset
#' removed), sex, individual number and whether the check character matches.
hetu_parse <- function(x) {
  ok_format <- grepl("^[0-9]{6}[-+A-FU-Y][0-9]{3}[0-9A-FHJ-NPR-Y]$", x)
  x[!ok_format] <- NA_character_          # the rest of the parsing sees only good formats
  dd <- as.integer(substr(x, 1, 2)); mm <- as.integer(substr(x, 3, 4))
  marker <- substr(x, 7, 7)
  century <- ifelse(marker == "+", 1800L, ifelse(marker %in% HETU_MARKERS[["19"]], 1900L, 2000L))
  year <- century + as.integer(substr(x, 5, 6))
  offset <- !is.na(mm) & mm > 12
  real_month <- ifelse(offset, mm - 12L, mm)
  nnn <- as.integer(substr(x, 8, 10))
  # An explicit format turns impossible dates such as 31.2. into NA
  birth <- as.Date(sprintf("%04d-%02d-%02d", year, real_month, dd), format = "%Y-%m-%d")
  check_ok <- ok_format
  check_ok[ok_format] <- hetu_check_char(substr(x[ok_format], 1, 6), substr(x[ok_format], 8, 10)) ==
    substr(x[ok_format], 11, 11)
  tibble::tibble(
    valid_format = ok_format, birth_date = birth, month_offset = offset,
    individual_number = nnn, sex = ifelse(nnn %% 2 == 1, "M", "F"),
    check_ok = check_ok)
}

#' TRUE for codes with a correct format, real date, number 002-999 and check
#' character. Month offset codes (months 13-24) are accepted only when allowed.
hetu_is_valid <- function(x, allow_month_offset = TRUE, parsed = hetu_parse(x)) {
  p <- parsed
  ok <- p$valid_format & p$check_ok & !is.na(p$birth_date) & p$individual_number >= 2
  ok & (allow_month_offset | !p$month_offset)
}
