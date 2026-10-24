# End-to-end pipeline -------------------------------------------------------

#' Simulate, assemble tables, write SQLite (+ optional CSV) to out_dir.
generate_dataset <- function(cfg, out_dir, sql_dir, overwrite = FALSE, write_csv = TRUE,
                             pg_sql_dir = NULL) {
  out_dir <- ensure_dir(out_dir)
  set.seed(cfg$run$seed)
  run_id <- sprintf("ccms-%s-%s", format(cfg$run$cutoff, "%Y%m%d"), cfg$run$seed)
  st <- with_timing("Building calendar and reference data", {
    cal <- build_calendar(cfg)
    ref <- gen_reference(cfg, cal)
    rmonths <- gen_resource_months(ref, cal, cfg)
    cases <- gen_cases(ref, cal, rmonths, cfg)
    log_info(sprintf("  %d cases, %d judges, %d counsel", nrow(cases), nrow(ref$judges), nrow(ref$counsel)))
    st <- init_state(cases, ref, cal, cfg)
    precompute_intake(st, rmonths)
    st$rmonths <- rmonths
    st
  })
  with_timing("Simulating case flow", run_simulation(st))
  tables <- with_timing("Assembling output tables", assemble_tables(st, cfg, run_id))
  validate_tables(tables)
  write_sqlite(tables, file.path(out_dir, "ccms_synth.sqlite"), sql_dir, overwrite)
  if (write_csv) {
    csv_dir <- ensure_dir(file.path(out_dir, "csv"))
    with_timing("Writing CSV files", for (tb in names(tables)) {
      write_csv_eu(tables[[tb]], file.path(csv_dir, paste0(tb, ".csv")))
    })
  }
  if (!is.null(pg_sql_dir)) with_timing("Writing PostgreSQL bundle", write_postgres_bundle(tables, out_dir, pg_sql_dir))
  summary <- summarise_run(tables)
  write_csv_eu(summary, file.path(out_dir, "run_summary.csv"))
  print(summary)
  invisible(tables)
}

assemble_tables <- function(st, cfg, run_id) {
  out <- build_reference_tables(st, cfg, run_id)
  sh <- build_status_history(st, cfg)
  out$case_status_history <- sh
  out$court_case <- build_court_case(st, cfg, sh)
  out$case_party <- build_parties(st)
  out$case_assignment <- build_assignments(st, cfg)
  out$case_event <- build_events(st, cfg)
  out$document <- build_documents(out$case_event, st)
  out$hearing <- build_hearings(st, cfg)
  out$procedural_deadline <- build_deadlines(st, cfg)
  out$motion <- build_motions(st, cfg)
  out$expert_report <- build_experts(st, cfg)
  out$custody_period <- build_custody(st, cfg)
  out$delay_period <- build_delays(st, cfg)
  out$court_resource_month <- build_resource_panel(st, st$rmonths, cfg)
  c(out, build_truth(st, cfg))
}

#' Cheap structural checks before touching the database.
validate_tables <- function(tables) {
  for (nm in names(tables)) {
    assert_that(data.table::is.data.table(tables[[nm]]), sprintf("Table %s is not a data.table", nm))
  }
  cc <- tables$court_case
  assert_that(!anyDuplicated(cc$case_id), "Duplicate case_id")
  assert_that(all(tables$hearing$case_id %in% cc$case_id), "Hearing refers to unknown case")
  bad <- cc[!is.na(disposition_date) & disposition_date < filing_date]
  assert_that(nrow(bad) == 0, sprintf("%d cases disposed before filing", nrow(bad)))
  invisible(TRUE)
}

summarise_run <- function(tables) {
  cc <- tables$court_case; h <- tables$hearing
  decided <- h[outcome %in% c("HELD", "ADJOURNED")]
  data.table::data.table(
    metric = c("cases", "open_at_cutoff", "hearings_decided", "adjournment_rate",
               "case_events", "delay_periods"),
    value = c(nrow(cc), sum(cc$is_open_at_cutoff), nrow(decided),
              round(mean(decided$outcome == "ADJOURNED"), 4), nrow(tables$case_event),
              nrow(tables$delay_period)))
}
