# Smoke test: every module server runs against the generated database --------

db <- tryCatch(find_database(app_dir), error = function(e) NULL)
skip_if(is.null(db), "ccms_synth.sqlite not available")
d <- load_dashboard_data(db)
cfg <- yaml::read_yaml(file.path(app_dir, "config.yaml"))
last <- d$sim_run$end_date[1]
f <- shiny::reactive(list(cases = d$court_case, from = as.Date("2025-01-01"), to = last,
                          as_of = last, courts = d$court$court_code))

check_outputs <- function(server, outputs, inputs = list()) {
  shiny::testServer(server, args = list(d = d, f = f, cfg = cfg), {
    if (length(inputs)) do.call(session$setInputs, inputs)
    for (o in outputs) expect_no_error(output[[o]], message = o)
  })
}

test_that("overview renders", check_outputs(overview_server,
  c("incoming", "resolved", "clearance", "pending", "dt", "over", "flow", "pending_trend")))
test_that("inventory renders", check_outputs(inventory_server, c("table", "share", "compare"), list(by = "court_type")))
test_that("dispositions render", check_outputs(dispositions_server, c("mix", "compliance", "age_table"),
                                               list(scale = "pct", group = "both")))
test_that("aging renders", check_outputs(aging_server, c("age", "status", "exc_summary", "exceptions")))
test_that("delay renders", check_outputs(delay_server, c("phases", "attribution", "adj_rate", "wait", "reasons", "intervals")))
test_that("resources render", check_outputs(resources_server, c("judges", "judge_table", "judges_fte", "efiling"),
                                            list(measure = "decisions")))
test_that("projection renders", check_outputs(projection_server, c("projection", "summary")))

test_that("headline KPIs are internally consistent", {
  k <- headline_kpis(d$court_case, as.Date("2025-01-01"), last, last, cfg$time_standards)
  inv <- caseload_inventory(d$court_case, as.Date("2025-01-01"), last, by = character(0))
  expect_equal(k$pending, inv$end_pending)
  expect_true(k$over_standard >= 0 && k$over_standard <= 1)
})
