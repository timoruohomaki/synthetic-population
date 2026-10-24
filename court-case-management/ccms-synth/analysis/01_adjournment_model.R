#!/usr/bin/env Rscript
# Adjournment model: does a logistic regression recover the generator's TRUE effects?
# (1) "oracle" model with latent covariates from truth_* tables -> should match truth.
# (2) "observable" model with proxies a real analyst would have -> shows proxy bias.
source(file.path("analysis", "common.R"))

MAPPING <- c("(Intercept)" = "intercept", "log_complexity" = "log_complexity",
  "needs_interpreter" = "interpreter", "self_represented" = "self_represented",
  "counsel_load" = "counsel_load", "in_custody" = "custody", "video_enabled" = "video_room",
  "extra_defendants" = "extra_defendant", "prior_adjournments" = "prior_adjournments",
  "prep_hearing" = "prep_hearing")

main <- function() {
  con <- open_db(); on.exit(dbDisconnect(con))
  h <- q(con, "
    SELECT f.*, th.counsel_load, tc.latent_complexity,
           (SELECT page_count FROM document d
             WHERE d.case_id = f.case_id AND d.document_type = 'INITIATING_DOCUMENT') AS initial_pages
    FROM v_hearing_features f
    JOIN truth_hearing th ON th.hearing_id = f.hearing_id
    JOIN truth_case tc ON tc.case_id = f.case_id")
  if (nrow(h) < 500) stop("Too few decided hearings for a stable fit")
  h[, `:=`(log_complexity = log(latent_complexity), extra_defendants = n_respondents - 1L,
           prep_hearing = as.integer(hearing_type == "PREPARATORY"))]
  truth <- truth_param(con, "adjournment.")
  cat(sprintf("Decided hearings: %d, adjournment rate: %s\n\n", nrow(h), fmt_fi(mean(h$adjourned))))

  cat("== Oracle model (latent covariates) ==\n")
  oracle <- glm(adjourned ~ log_complexity + needs_interpreter + self_represented + counsel_load +
                  in_custody + video_enabled + extra_defendants + prior_adjournments + prep_hearing,
                family = binomial(), data = h)
  compare_coefs(oracle, MAPPING, truth)

  cat("\n== Observable model (proxies: initiating-document pages, counsel hearings +-3 d) ==\n")
  h[, `:=`(log_pages = log(pmax(1, initial_pages)), counsel_obs = counsel_other_hearings_pm3d)]
  obs <- glm(adjourned ~ log_pages + needs_interpreter + self_represented + counsel_obs +
               in_custody + video_enabled + extra_defendants + prior_adjournments + prep_hearing,
             family = binomial(), data = h)
  co <- coef(summary(obs))
  print(data.table(term = rownames(co), estimate = fmt_fi(co[, 1]), std_error = fmt_fi(co[, 2]),
                   p_value = fmt_fi(co[, 4])))
  cat(sprintf("\nCorrelation latent vs observed counsel load: %s\n",
              fmt_fi(cor(h$counsel_load, h$counsel_obs))))

  cat("\n== Adjournments by attribution (share of adjourned hearings) ==\n")
  print(h[adjourned == 1, .N, by = attribution_code][, share := fmt_fi(N / sum(N))][order(-N)])
}

run_analysis(main)
