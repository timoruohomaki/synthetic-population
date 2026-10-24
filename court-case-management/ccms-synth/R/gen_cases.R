# Case arrivals (non-stationary Poisson) and case-level attributes ----------

#' Expected arrivals per court x case type x month, including bulk-filer surges.
arrival_plan <- function(ref, cfg) {
  months <- seq(cfg$run$start, cfg$run$end, by = "month")
  ct <- ref$case_types
  types <- cfg$case_types
  plan <- data.table::CJ(court_id = ref$courts$court_id, case_type_code = ct$case_type_code,
                         m = seq_along(months))
  plan <- merge(plan, ref$courts[, .(court_id, level, share)], by = "court_id")
  plan[, allowed := mapply(function(code, lv) lv %in% types[[code]]$levels, case_type_code, level)]
  plan <- plan[allowed == TRUE]
  plan[, w := vapply(case_type_code, function(code) types[[code]]$weight, numeric(1))]
  plan[, w := w / sum(w[!duplicated(case_type_code)]), by = court_id]
  v <- cfg$volume
  plan[, month_start := months[m]]
  plan[, lambda := v$cases_per_year / 12 * share * w * v$monthly_seasonality[as.integer(format(month_start, "%m"))] *
         (1 + v$annual_growth)^((m - 1) / 12)]
  # Split summary claims between bulk filers (with surges) and ordinary filers.
  a <- cfg$actors
  bulk <- plan[case_type_code == "CIV_SUM"][, .(litigant_id = seq_len(a$bulk_litigants)), by = names(plan)]
  bulk[, surge := stats::runif(.N) < a$bulk_surge_prob_month]
  bulk[, lambda := lambda * a$bulk_share_of_summary / a$bulk_litigants * data.table::fifelse(surge, a$bulk_surge_multiplier, 1)]
  plan[case_type_code == "CIV_SUM", lambda := lambda * (1 - a$bulk_share_of_summary)]
  plan[, `:=`(litigant_id = NA_integer_, surge = FALSE)]
  rbind(plan, bulk, use.names = TRUE)
}

#' Draw individual cases from the plan.
gen_cases <- function(ref, cal, rmonths, cfg) {
  plan <- arrival_plan(ref, cfg)
  plan[, n := stats::rpois(.N, lambda)]
  plan <- plan[n > 0]
  cs <- plan[rep(seq_len(.N), n), .(court_id, case_type_code, month_start, bulk_litigant_id = litigant_id, surge)]
  wd <- cal[is_working_day == TRUE & date <= cfg$run$end, .(day, mkey = format(date, "%Y-%m"))]
  cs[, mkey := format(month_start, "%Y-%m")]
  cs[, filing_day := { d <- wd$day[wd$mkey == .BY$mkey]; d[sample.int(length(d), .N, TRUE)] }, by = mkey]
  data.table::setorder(cs, filing_day)
  cs[, case_id := seq_len(.N)]
  cs <- add_case_attributes(cs, ref, rmonths, cfg)
  cs[, c("month_start", "mkey") := NULL]
  cs[]
}

#' Latent and observable case attributes. Latent ones go to truth_case only.
add_case_attributes <- function(cs, ref, rmonths, cfg) {
  tp <- function(field) vapply(cs$case_type_code, function(code) as.numeric(cfg$case_types[[code]][[field]]), numeric(1))
  cs[, category := vapply(case_type_code, function(code) cfg$case_types[[code]]$category, character(1))]
  sdl <- 0.45
  cs[, complexity := stats::rlnorm(.N, log(tp("complexity")) - sdl^2 / 2, sdl)]
  cs <- merge(cs, rmonths[, .(court_id, mkey = month_key, efiling_target_rate)], by = c("court_id", "mkey"), all.x = TRUE)
  cs[, filing_channel := data.table::fifelse(
    !is.na(bulk_litigant_id) | (category == "CRIMINAL" & stats::runif(.N) < 0.95) |
      stats::runif(.N) < efiling_target_rate, "EFILING", "PAPER")]
  cs[, contested := stats::runif(.N) < tp("contest_prob")]
  cs[, early_resolution := stats::runif(.N) < tp("early_prob")]
  cs[, will_settle := stats::runif(.N) < tp("settle_prob")]
  cs[, needs_main_hearing := stats::runif(.N) < tp("hearing_prob")]
  cs[, prep_hearing := as.logical(tp("prep_hearing"))]
  cs[, expert_needed := stats::runif(.N) < tp("expert_prob") * pmin(2, complexity / tp("complexity"))]
  cs[, interpreter_language := data.table::fifelse(stats::runif(.N) < tp("interpreter_prob"),
       sample(unlist(cfg$actors$interpreter_languages), .N, TRUE), NA_character_)]
  cs[, in_custody_at_filing := category == "CRIMINAL" & stats::runif(.N) < tp("custody_prob")]
  cs[, n_respondents := 1L + stats::rpois(.N, data.table::fifelse(category == "CRIMINAL", 0.30 * complexity, 0.10))]
  cs[, self_represented := stats::runif(.N) < tp("self_rep_prob")]
  cs[, claim_amount_eur := data.table::fifelse(category == "NON_CRIMINAL",
       round(stats::rlnorm(.N, log(1500 * complexity^2), 0.8), 2), NA_real_)]
  cs[, n_charges := data.table::fifelse(category == "CRIMINAL", 1L + stats::rpois(.N, complexity), NA_integer_)]
  # Counsel: weighted by activity so a few counsel carry heavy caseloads.
  cs[, respondent_counsel_id := NA_integer_]
  cs[, claimant_counsel_id := NA_integer_]
  for (cid in unique(cs$court_id)) {
    pool <- ref$counsel[court_id == cid]
    pick <- function(n) pool$counsel_id[sample.int(nrow(pool), n, TRUE, prob = pool$activity_weight)]
    idx <- which(cs$court_id == cid & !cs$self_represented)
    cs[idx, respondent_counsel_id := pick(length(idx))]
    idx <- which(cs$court_id == cid & cs$category == "NON_CRIMINAL" & is.na(cs$bulk_litigant_id) &
                   stats::runif(nrow(cs)) < 0.6)
    cs[idx, claimant_counsel_id := pick(length(idx))]
  }
  data.table::setorder(cs, case_id)
  cs
}
