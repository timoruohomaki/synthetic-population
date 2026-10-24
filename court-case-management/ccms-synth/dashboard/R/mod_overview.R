# Overview: headline KPIs and monthly flow (Model Reports 7, 9, 10; CEPEJ) --

overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_column_wrap(width = 1 / 3, fill = FALSE,
      kpi_box("Incoming cases (period)", ns("incoming"), ns("incoming_note")),
      kpi_box("Resolved cases (period)", ns("resolved")),
      kpi_box("Clearance rate", ns("clearance"), ns("clearance_note")),
      kpi_box("Pending cases (as of)", ns("pending"), ns("pending_note")),
      kpi_box("Disposition time (CEPEJ)", ns("dt"), ns("dt_note")),
      kpi_box("Pending over time standard", ns("over"), ns("over_note"))),
    bslib::layout_columns(col_widths = c(6, 6),
      report_card("Incoming vs. resolved per month", "NCSC 7 / 10", plotly::plotlyOutput(ns("flow"))),
      report_card("Pending caseload at month end", "NCSC 9", plotly::plotlyOutput(ns("pending_trend")))))
}

overview_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    court_cols <- entity_colors(d$court$court_code, pal)
    k <- shiny::reactive(headline_kpis(f()$cases, f()$from, f()$to, f()$as_of, cfg$time_standards))
    flow <- shiny::reactive(monthly_flow(f()$cases, f()$from, f()$to, by = "court_code"))

    output$incoming <- shiny::renderText(fmt_num(k()$incoming))
    output$incoming_note <- shiny::renderUI(shiny::tags$small(sprintf("%s – %s", fmt_date(f()$from), fmt_date(f()$to))))
    output$resolved <- shiny::renderText(fmt_num(k()$resolved))
    output$clearance <- shiny::renderText(fmt_pct(k()$clearance))
    output$clearance_note <- shiny::renderUI({
      cr <- k()$clearance
      if (is.na(cr)) return(NULL)
      if (cr >= 1) status_label("good", "Backlog not growing", pal)
      else if (cr >= 0.95) status_label("warning", "Slightly below 100 %", pal)
      else status_label("critical", "Backlog growing", pal)
    })
    output$pending <- shiny::renderText(fmt_num(k()$pending))
    output$pending_note <- shiny::renderUI(shiny::tags$small(sprintf("Median age %s; change in period %s",
      fmt_days(k()$median_age), fmt_pct(k()$pending_change))))
    output$dt <- shiny::renderText(fmt_days(k()$disposition_time))
    output$dt_note <- shiny::renderUI(shiny::tags$small("Pending at period end ÷ resolved × days in period"))
    output$over <- shiny::renderText(fmt_pct(k()$over_standard))
    output$over_note <- shiny::renderUI({
      v <- k()$over_standard
      if (is.na(v)) return(NULL)
      lvl <- if (v < 0.1) "good" else if (v < 0.25) "warning" else if (v < 0.4) "serious" else "critical"
      status_label(lvl, "Share of pending cases older than their standard", pal)
    })

    output$flow <- plotly::renderPlotly({
      fl <- flow()[, .(incoming = sum(incoming), resolved = sum(resolved)), by = month]
      long <- data.table::melt(fl, id.vars = "month", variable.name = "measure", value.name = "cases")
      cols <- entity_colors(c("incoming", "resolved"), pal)
      plot_lines(long, "month", "cases", "measure", cols, pal, y_title = "Cases per month")
    })
    output$pending_trend <- plotly::renderPlotly(
      plot_lines(flow(), "month", "pending_end", "court_code", court_cols, pal, y_title = "Pending cases"))
  })
}
