# Exogenous per-case quantities computed before the event loop ------------

#' Clerk workload at filing (filings in the last 30 days per clerk capacity)
#' and the resulting registration lag. Exogenous, so computed up front.
precompute_intake <- function(st, rmonths) {
  cs <- st$cs; cfg <- st$cfg; e <- cfg$effects$registration
  n30 <- integer(nrow(cs))
  for (court in unique(cs$court_id)) {
    idx <- which(cs$court_id == court)
    per_day <- tabulate(cs$filing_day[idx] + 1L, nbins = st$n_days)
    cum <- cumsum(per_day)
    fd <- cs$filing_day[idx] + 1L
    n30[idx] <- cum[fd] - c(0, cum)[pmax(1L, fd - 29L)]
  }
  mk <- format(day_to_date(cs$filing_day, cfg), "%Y-%m")
  fte <- rmonths$clerks_fte[match(paste(cs$court_id, mk), paste(rmonths$court_id, rmonths$month_key))]
  load <- n30 / (fte * cfg$capacity$clerk_capacity_per_month)
  base <- ifelse(cs$filing_channel == "EFILING", e$base_days_efiling, e$base_days_paper)
  lag <- base * (1 + e$load_coef * pmax(0, load - 1)) * stats::rlnorm(nrow(cs), -e$noise_sdlog^2 / 2, e$noise_sdlog)
  data.table::set(st$truth, j = "clerk_load", value = round(load, 3))
  data.table::set(st$truth, j = "reg_lag_days", value = round(lag, 2))
  data.table::set(st$cs, j = "in_custody_now", value = FALSE)
}
