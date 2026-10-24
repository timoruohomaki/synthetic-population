# Calendar: day indexing, holidays, capacity factors, working-day arithmetic

#' Gregorian Easter Sunday (anonymous Gregorian algorithm).
easter_sunday <- function(year) {
  a <- year %% 19; b <- year %/% 100; c <- year %% 100
  d <- b %/% 4; e <- b %% 4; f <- (b + 8) %/% 25; g <- (b - f + 1) %/% 3
  h <- (19 * a + b - d - g + 15) %% 30; i <- c %/% 4; k <- c %% 4
  l <- (32 + 2 * e + 2 * i - h - k) %% 7; m <- (a + 11 * h + 22 * l) %/% 451
  month <- (h + l - 7 * m + 114) %/% 31; day <- ((h + l - 7 * m + 114) %% 31) + 1
  as.Date(sprintf("%04d-%02d-%02d", year, month, day))
}

#' Finnish public holidays (incl. Midsummer and Christmas Eve) for given years.
holidays_fi <- function(years) {
  out <- lapply(years, function(y) {
    es <- easter_sunday(y)
    mid_eve <- seq(as.Date(sprintf("%d-06-19", y)), by = "day", length.out = 7)
    mid_eve <- mid_eve[format(mid_eve, "%u") == "5"]
    data.table::data.table(
      date = c(as.Date(sprintf("%d-%s", y, c("01-01", "01-06", "05-01", "12-06", "12-24", "12-25", "12-26"))),
               es - 2, es + 1, es + 39, mid_eve, mid_eve + 1),
      holiday_name = c("New Year's Day", "Epiphany", "May Day", "Independence Day",
                       "Christmas Eve", "Christmas Day", "Boxing Day", "Good Friday",
                       "Easter Monday", "Ascension Day", "Midsummer Eve", "Midsummer Day"))
  })
  data.table::rbindlist(out)
}

#' Build the simulation calendar from start_date to cutoff + horizon.
#' Columns: day (0-based index), date, iso_weekday, is_holiday, is_working_day,
#' capacity_factor (hearing capacity), work_weight (judgment drafting speed).
build_calendar <- function(cfg) {
  start <- cfg$run$start
  last <- cfg$run$cutoff + cfg$run$calendar_horizon_days
  cal <- data.table::data.table(date = seq(start, last, by = "day"))
  cal[, day := seq_len(.N) - 1L]
  cal[, iso_weekday := as.integer(format(date, "%u"))]
  hol <- if (identical(cfg$run$holiday_set, "FI")) {
    holidays_fi(as.integer(format(start, "%Y")):as.integer(format(last, "%Y")))
  } else {
    data.table::data.table(date = as.Date(character()), holiday_name = character())
  }
  cal <- merge(cal, hol, by = "date", all.x = TRUE, sort = TRUE)
  cal[, is_holiday := !is.na(holiday_name)]
  cal[, is_working_day := iso_weekday <= 5L & !is_holiday]
  cap <- cfg$capacity
  month <- as.integer(format(cal$date, "%m"))
  md <- format(cal$date, "%m-%d")
  yearend <- md >= "12-22" | md <= "01-06"
  cal[, capacity_factor := data.table::fifelse(is_working_day, 1, 0)]
  cal[month == cap$summer_recess_month, capacity_factor := capacity_factor * cap$summer_capacity_factor]
  cal[yearend, capacity_factor := capacity_factor * cap$yearend_capacity_factor]
  # Drafting continues in recess but slower: weight floor of 0.4 on working days.
  cal[, work_weight := data.table::fifelse(is_working_day, pmax(capacity_factor, 0.4), 0)]
  cal[, cum_work := cumsum(work_weight)]
  data.table::setkey(cal, day)
  cal
}

#' Convert day index to Date.
day_to_date <- function(day, cfg) cfg$run$start + day

#' Add `n` effective working days (weighted) to day index `from`.
#' Returns the first day whose cumulative work exceeds start + n.
add_work_days <- function(cal, from, n) {
  cw <- cal$cum_work
  target <- cw[from + 1L] + pmax(n, 0)
  idx <- findInterval(target - 1e-9, cw) + 1L
  idx <- pmin(idx, length(cw))
  as.integer(idx - 1L)
}

#' Next working day on or after `day`.
next_working_day <- function(cal, day) {
  wd <- cal$is_working_day
  n <- length(wd)
  vapply(day, function(d) {
    d <- max(0L, min(as.integer(d), n - 1L))
    hit <- which(wd[(d + 1L):n])
    if (length(hit) == 0L) n - 1L else as.integer(d + hit[1] - 1L)
  }, integer(1))
}

#' RFC 3339 UTC timestamp string from day index and hour fraction (UTC).
fmt_ts <- function(date, hour_utc) {
  h <- floor(hour_utc); m <- round((hour_utc - h) * 60)
  sprintf("%sT%02d:%02d:00Z", format(date, "%Y-%m-%d"), as.integer(h), as.integer(m))
}
