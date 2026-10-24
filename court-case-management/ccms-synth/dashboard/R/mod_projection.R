# Pending caseload projection (Model Report 19) ------------------------------

projection_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    report_card("Pending caseload: actual and projected", "NCSC 19",
      shiny::tags$small(class = "text-muted",
        "Linear trend fitted to the last months up to the end of the reporting period; shaded band is the ",
        "prediction interval. A simple management projection, not a forecast model."),
      plotly::plotlyOutput(ns("projection"), height = "460px")),
    report_card("Projection summary", "NCSC 19", DT::DTOutput(ns("summary"))))
}

projection_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    pc <- cfg$projection
    court_cols <- entity_colors(d$court$court_code, pal)
    proj <- shiny::reactive({
      flow <- monthly_flow(f()$cases, d$start, f()$to, by = "court_code")
      last_complete <- as.Date(format(f()$to + 1, "%Y-%m-01")) - 1
      flow <- flow[month <= as.Date(format(last_complete, "%Y-%m-01"))]
      project_pending(flow, "court_code", pc$fit_months, pc$horizon_months, pc$interval_level)
    })
    output$projection <- plotly::renderPlotly({
      x <- proj()
      if (nrow(x) == 0) return(empty_plot("Not enough months to fit a trend"))
      p <- plotly::plot_ly()
      for (g in intersect(names(court_cols), unique(x$court_code))) {
        a <- x[court_code == g & type == "actual"]; pr <- x[court_code == g & type == "projection"]
        col <- court_cols[[g]]
        p <- p |>
          plotly::add_ribbons(x = pr$month, ymin = pr$lower, ymax = pr$upper, name = paste(g, "interval"),
            fillcolor = grDevices::adjustcolor(col, 0.15), line = list(width = 0), showlegend = FALSE,
            hoverinfo = "skip") |>
          plotly::add_trace(x = a$month, y = a$pending_end, type = "scatter", mode = "lines", name = g,
            line = list(color = col, width = 2), hovertemplate = paste0("%{y:,.0f}<extra>", g, "</extra>")) |>
          plotly::add_trace(x = pr$month, y = pr$pending_end, type = "scatter", mode = "lines",
            name = paste(g, "projection"), line = list(color = col, width = 2, dash = "dash"),
            hovertemplate = paste0("%{y:,.0f}<extra>", g, " projected</extra>"))
      }
      iso_month_axis(viz_layout(p, pal, y_title = "Pending cases at month end"))
    })
    output$summary <- DT::renderDT({
      x <- proj()
      if (nrow(x) == 0) return(fi_table(data.table::data.table(message = "Not enough data")))
      s <- x[, .(last_actual = pending_end[type == "actual"][sum(type == "actual")],
                 projected_end = pending_end[.N], lower = lower[.N], upper = upper[.N],
                 trend_per_month = slope_per_month[1]), by = court_code]
      fi_table(s, num = c("last_actual", "projected_end", "lower", "upper"), dec = "trend_per_month",
        labels = list(court_code = "Court", last_actual = "Pending now", projected_end = "Projected (horizon end)",
                      lower = "Lower", upper = "Upper", trend_per_month = "Trend per month"))
    })
  })
}
