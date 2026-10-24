# Judges and resources (Model Report 13 + court resource panel) -------------

resources_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(col_widths = c(7, 5),
      report_card("Caseload per judge", "NCSC 13",
        shiny::radioButtons(ns("measure"), NULL, inline = TRUE,
          choices = c("Open cases (as of)" = "open_cases", "Hearings held" = "hearings_held",
                      "Decisions issued" = "decisions")),
        plotly::plotlyOutput(ns("judges"), height = "460px")),
      report_card("Judge workload table", "NCSC 13", DT::DTOutput(ns("judge_table")))),
    bslib::layout_columns(col_widths = c(4, 4, 4),
      report_card("Judge FTE (after absences)", "Resources", plotly::plotlyOutput(ns("judges_fte"))),
      report_card("Clerk FTE", "Resources", plotly::plotlyOutput(ns("clerks_fte"))),
      report_card("E-filing rate", "Resources", plotly::plotlyOutput(ns("efiling")))))
}

resources_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    court_cols <- entity_colors(d$court$court_code, pal)
    jc <- shiny::reactive(judge_caseload(f()$cases, d$case_assignment, d$hearing, d$judge, d$court,
                                         f()$from, f()$to, f()$as_of)[court_code %in% f()$courts])
    panel <- shiny::reactive(resource_panel(d$court_resource_month, d$court, f()$courts, f()$from, f()$to))
    output$judges <- plotly::renderPlotly({
      x <- jc(); m <- input$measure
      x <- x[order(court_code, get(m))]
      p <- plotly::plot_ly()
      for (g in intersect(names(court_cols), unique(x$court_code))) {
        s <- x[court_code == g]
        p <- plotly::add_trace(p, x = s[[m]], y = s$judge_code, type = "bar", orientation = "h", name = g,
          marker = list(color = court_cols[[g]]), hovertemplate = paste0("%{y}: %{x:,.0f}<extra></extra>"))
      }
      viz_layout(p, pal) |> plotly::layout(hovermode = "closest",
        yaxis = list(categoryorder = "array", categoryarray = x$judge_code, title = ""))
    })
    output$judge_table <- DT::renderDT(fi_table(jc()[, .(judge_code, court_code, open_cases, hearings_held, decisions)],
      num = c("open_cases", "hearings_held", "decisions"), page_length = 12,
      labels = list(judge_code = "Judge", court_code = "Court", open_cases = "Open cases",
                    hearings_held = "Hearings held", decisions = "Decisions")))
    line <- function(col, title, fmt) plot_lines(panel(), "month_start_date", col, "court_code", court_cols, pal,
                                                y_title = title, y_fmt = fmt)
    output$judges_fte <- plotly::renderPlotly(line("judges_fte", "FTE", ",.1f"))
    output$clerks_fte <- plotly::renderPlotly(line("clerks_fte", "FTE", ",.1f"))
    output$efiling <- plotly::renderPlotly(line("efiling_rate", "Share e-filed", ".1%") |>
      plotly::layout(yaxis = list(tickformat = ".0%", rangemode = "normal")))
  })
}
