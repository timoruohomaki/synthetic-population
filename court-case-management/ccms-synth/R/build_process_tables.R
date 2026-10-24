# Output process tables (hearings, deadlines, motions, experts, custody, delay)

HEARING_START_LOCAL <- c(9, 10.5, 13)  # local start-time slots

build_hearings <- function(st, cfg) {
  h <- rec_to_dt(st$R$hearing)[booked_day <= cutoff_day(cfg)]
  cut <- cutoff_day(cfg)
  h[hearing_day > cut & outcome != "VACATED", `:=`(outcome = "SCHEDULED", reason_code = NA_character_)]
  slot <- HEARING_START_LOCAL[(h$hearing_id %% length(HEARING_START_LOCAL)) + 1L]
  h[, .(hearing_id, case_id, hearing_type, judge_id, courtroom_id,
        scheduled_on_date = iso_date(booked_day, cfg), earliest_possible_date = iso_date(earliest_day, cfg),
        hearing_date = iso_date(hearing_day, cfg), start_ts = rfc3339_utc(hearing_day, slot, cfg),
        planned_hours = hours, outcome, adjournment_reason_code = reason_code,
        prior_adjournments, video_enabled = video)]
}

build_deadlines <- function(st, cfg) {
  d <- rec_to_dt(st$R$deadline)[set_day <= cutoff_day(cfg)]
  d[, .(deadline_id = seq_len(.N), case_id, deadline_type, set_date = iso_date(set_day, cfg),
        due_date = iso_date(due_day, cfg), met_date = iso_date(met_day, cfg, TRUE),
        extended_days, responsible_attribution = responsible)]
}

build_motions <- function(st, cfg) {
  m <- rec_to_dt(st$R$motion)[filed_day <= cutoff_day(cfg)]
  m[, .(motion_id = seq_len(.N), case_id, motion_type, filed_by_attribution = filed_by,
        filed_date = iso_date(filed_day, cfg), decided_date = iso_date(decided_day, cfg, TRUE),
        outcome = data.table::fifelse(decided_day <= cutoff_day(cfg), outcome, NA_character_))]
}

build_experts <- function(st, cfg) {
  x <- rec_to_dt(st$R$expert)[ordered_day <= cutoff_day(cfg)]
  x[, .(expert_report_id = seq_len(.N), case_id, ordered_date = iso_date(ordered_day, cfg),
        due_date = iso_date(due_day, cfg), delivered_date = iso_date(delivered_day, cfg, TRUE))]
}

build_custody <- function(st, cfg) {
  x <- rec_to_dt(st$R$custody)[from_day <= cutoff_day(cfg)]
  x[, .(custody_id = seq_len(.N), case_id, start_date = iso_date(from_day, cfg),
        end_date = iso_date(to_day, cfg, TRUE),
        end_reason = data.table::fifelse(!is.na(to_day) & to_day <= cutoff_day(cfg), end_reason, NA_character_))]
}

#' Recorded delay periods with responsibility (Jordan-style attribution).
build_delays <- function(st, cfg) {
  cut <- cutoff_day(cfg)
  x <- rec_to_dt(st$R$delay)[from_day <= cut]
  x[, .(delay_period_id = seq_len(.N), case_id, start_date = iso_date(from_day, cfg),
        end_date = iso_date(pmin(to_day, cut), cfg), attribution_code = attribution, cause_code,
        delay_days = pmin(to_day, cut) - from_day, is_ongoing_at_cutoff = to_day > cut)]
}

#' Ground truth for model validation. Never expose to analysts as features.
build_truth <- function(st, cfg) {
  cs <- st$cs
  case <- cbind(cs[, .(case_id, latent_complexity = round(complexity, 4), contested, early_resolution,
                       will_settle, needs_main_hearing, expert_needed, bulk_surge_month = surge)],
                st$truth[, -"case_id"])
  h <- rec_to_dt(st$R$hearing)[booked_day <= cutoff_day(cfg) & !is.na(lin_pred)]
  list(truth_case = case,
       truth_hearing = h[, .(hearing_id, counsel_load, linear_predictor = round(lin_pred, 5),
                             p_adjourn = round(p_adjourn, 5))],
       truth_parameter = flatten_effects(cfg),
       truth_counsel = st$ref$counsel[, .(counsel_id, activity_weight = round(activity_weight, 4))])
}
