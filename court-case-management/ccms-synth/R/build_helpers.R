# Helpers to turn day indices into ISO 8601 dates / RFC 3339 timestamps ----

TZ_LOCAL <- "Europe/Helsinki"

#' Day index -> 'YYYY-MM-DD' text (NA stays NA). Days after cutoff -> NA when censor = TRUE.
iso_date <- function(day, cfg, censor = FALSE) {
  day <- as.integer(day)
  if (censor) day[!is.na(day) & day > as.integer(cfg$run$cutoff - cfg$run$start)] <- NA_integer_
  out <- format(cfg$run$start + day, "%Y-%m-%d")
  out[is.na(day)] <- NA_character_
  out
}

#' Local wall-clock time (hours since midnight, Europe/Helsinki) -> RFC 3339 UTC.
rfc3339_utc <- function(day, local_hours, cfg) {
  ok <- !is.na(day)
  out <- rep(NA_character_, length(day))
  if (!any(ok)) return(out)
  h <- floor(local_hours[ok]); m <- round((local_hours[ok] - h) * 60)
  txt <- sprintf("%s %02d:%02d:00", format(cfg$run$start + day[ok], "%Y-%m-%d"), as.integer(h), as.integer(m))
  ts <- as.POSIXct(txt, tz = TZ_LOCAL, format = "%Y-%m-%d %H:%M:%S")
  out[ok] <- format(ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  out
}

cutoff_day <- function(cfg) as.integer(cfg$run$cutoff - cfg$run$start)

#' Finnish-style case number, e.g. "DC-SOUTH R 24/001234".
case_numbers <- function(cs, courts, cfg) {
  prefix <- data.table::fcase(cs$category == "CRIMINAL", "R",
                              cs$case_type_code == "CIV_SUM", "H", default = "L")
  yy <- format(cfg$run$start + cs$filing_day, "%y")
  code <- courts$code[match(cs$court_id, courts$court_id)]
  key <- paste(code, prefix, yy)
  seq_no <- stats::ave(seq_along(key), key, FUN = seq_along)
  sprintf("%s %s %s/%06d", code, prefix, yy, seq_no)
}

#' Code tables from codes.yaml as data.tables.
code_tables <- function(cfg) {
  cd <- cfg$codes
  kv <- function(x, k, v) data.table::data.table(names(x), unlist(x, use.names = FALSE))[
    , stats::setNames(.SD, c(k, v))]
  list(
    attribution_code = kv(cd$attribution, "attribution_code", "description"),
    disposition_type = kv(cd$dispositions, "disposition_code", "description"),
    event_type = kv(cd$events, "event_code", "description"),
    status_code = data.table::data.table(status_code = names(cd$statuses),
      phase = vapply(cd$statuses, `[[`, "", "phase"), description = vapply(cd$statuses, `[[`, "", "label")),
    adjournment_reason = data.table::data.table(reason_code = names(cd$adjournment_reasons),
      description = vapply(cd$adjournment_reasons, `[[`, "", "label"),
      attribution_code = vapply(cd$adjournment_reasons, `[[`, "", "attribution"),
      applies_to = vapply(cd$adjournment_reasons, `[[`, "", "applies")))
}
