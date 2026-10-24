# Dispositions: manner, age at disposition, time-standard compliance
# (Model Reports 11, 12, 17, 21, 22)

DISP_ORDER <- c("JUDGMENT", "WRITTEN_DECISION", "DEFAULT_JUDGMENT", "SETTLED", "WITHDRAWN", "GUILTY_PLEA")

dispositions_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(col_widths = c(7, 5),
      report_card("Manner of disposition per month", "NCSC 11 / 17",
        shiny::radioButtons(ns("scale"), NULL, inline = TRUE, choices = c("Number" = "n", "Share" = "pct")),
        plotly::plotlyOutput(ns("mix"))),
      report_card("Disposed within time standard", "Performance measure", plotly::plotlyOutput(ns("compliance")))),
    report_card("Age of cases at disposition (days)", "NCSC 21 / 22",
      shiny::radioButtons(ns("group"), NULL, inline = TRUE,
        choices = c("Case type × manner" = "both", "Case type" = "type", "Manner" = "manner")),
      DT::DTOutput(ns("age_table"))))
}

dispositions_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    disp_cols <- entity_colors(DISP_ORDER, pal)
    output$mix <- plotly::renderPlotly({
      x <- disposition_mix(f()$cases, f()$from, f()$to)
      if (input$scale == "pct") {
        x[, share := N / sum(N), by = month]
        return(plot_stacked(x, "month", "share", "disposition_code", disp_cols, pal, y_title = "Share of dispositions",
                            y_fmt = ".1%", percent = TRUE))
      }
      plot_stacked(x, "month", "N", "disposition_code", disp_cols, pal, y_title = "Dispositions")
    })
    output$compliance <- plotly::renderPlotly({
      x <- standard_compliance(f()$cases, f()$from, f()$to, cfg$time_standards)
      std <- unlist(cfg$time_standards)[x$case_type_code]
      plot_hbar(x, "case_type_code", "within_standard", pal, x_title = "Share disposed within standard",
                x_fmt = ".1%", hover = sprintf("Standard %s d, %s cases", std, fmt_num(x$disposed))) |>
        plotly::layout(xaxis = list(tickformat = ".0%", range = c(0, 1)))
    })
    output$age_table <- DT::renderDT({
      by <- switch(input$group, both = c("case_type_code", "disposition_code"), type = "case_type_code",
                   manner = "disposition_code")
      x <- age_at_disposition(f()$cases, f()$from, f()$to, by = by)
      fi_table(x, num = c("n", "median"), dec = c("mean", "p90"), page_length = 15,
               labels = list(case_type_code = "Case type", disposition_code = "Manner of disposition",
                             n = "Cases", mean = "Mean", median = "Median", p90 = "90th percentile"))
    })
  })
}
