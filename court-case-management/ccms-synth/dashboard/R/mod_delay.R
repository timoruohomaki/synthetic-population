# Delay and caseflow: where time goes and who causes it
# (NCSC Figure 10 caseflow reports; Clarke & Metzler; Jordan-style attribution)

delay_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(col_widths = c(6, 6),
      report_card("Mean days per phase, cases disposed in period", "Phase decomposition",
                  plotly::plotlyOutput(ns("phases"))),
      report_card("Delay days by responsible party", "Delay attribution", plotly::plotlyOutput(ns("attribution")))),
    bslib::layout_columns(col_widths = c(6, 6),
      report_card("Hearing adjournment rate per month", "Hearings", plotly::plotlyOutput(ns("adj_rate"))),
      report_card("Wait for a hearing slot (booking → hearing beyond notice)", "Calendar queue",
                  plotly::plotlyOutput(ns("wait")))),
    bslib::layout_columns(col_widths = c(6, 6),
      report_card("Adjournment reasons", "Hearings", plotly::plotlyOutput(ns("reasons"))),
      report_card("Time intervals between events, cases disposed in period", "NCSC Fig. 10",
                  DT::DTOutput(ns("intervals")))))
}

delay_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    court_cols <- entity_colors(d$court$court_code, pal)
    ids <- shiny::reactive(f()$cases$case_id)
    hm <- shiny::reactive(hearing_monthly(d$hearing, ids(), f()$from, f()$to))
    output$phases <- plotly::renderPlotly({
      x <- phase_profile(f()$cases, d$phase, f()$from, f()$to)
      plot_stacked(x, "court_code", "mean_days", "phase", entity_colors(PHASE_ORDER, pal), pal,
                   y_title = "Mean days", y_fmt = ",.1f")
    })
    output$attribution <- plotly::renderPlotly({
      x <- delay_attribution(d$delay_period, ids(), f()$from, f()$to)
      plot_stacked(x, "court_code", "delay_days", "attribution_code", entity_colors(ATTR_ORDER, pal), pal,
                   y_title = "Delay days (periods starting in period)")
    })
    output$adj_rate <- plotly::renderPlotly(
      plot_lines(hm(), "month", "adjournment_rate", "court_code", court_cols, pal,
                 y_title = "Share of hearings adjourned", y_fmt = ".1%") |>
        plotly::layout(yaxis = list(tickformat = ".0%")))
    output$wait <- plotly::renderPlotly(
      plot_lines(hm(), "month", "mean_wait", "court_code", court_cols, pal, y_title = "Mean days", y_fmt = ",.1f"))
    output$reasons <- plotly::renderPlotly({
      x <- adjournment_reasons(d$hearing, ids(), f()$from, f()$to, d$adjournment_reason)
      plot_hbar(x, "reason_code", "N", pal, x_title = "Adjourned hearings",
                hover = sprintf("%s<br>Attribution: %s<br>Share %s", x$description, x$attribution_code,
                                fmt_pct(x$share)))
    })
    output$intervals <- DT::renderDT({
      x <- event_intervals(f()$cases, d$hearing, f()$from, f()$to)
      fi_table(x, num = c("cases", "median"), dec = "p90",
               labels = list(interval = "Interval", cases = "Cases", median = "Median (d)", p90 = "90th pct (d)"))
    })
  })
}
