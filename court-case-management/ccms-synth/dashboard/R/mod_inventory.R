# Caseload inventory by case type (Model Reports 7, 8, 9, 10, 14) ----------

INVENTORY_LABELS <- list(court_code = "Court", case_type_code = "Case type", begin_pending = "Pending at start",
  filed = "Filed", disposed = "Disposed", end_pending = "Pending at end", change = "Change",
  change_pct = "Change %", clearance_rate = "Clearance rate", share_of_filings = "Share of filings",
  filed_prev = "Filed (prev. period)", filed_change_pct = "Filed change %",
  disposed_prev = "Disposed (prev. period)", disposed_change_pct = "Disposed change %")

inventory_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::radioButtons(ns("by"), NULL, inline = TRUE,
      choices = c("By case type" = "type", "By court and case type" = "court_type")),
    report_card("Trial court caseload inventory", "NCSC 7 / 9 / 10",
      shiny::div(shiny::downloadButton(ns("download"), "Download CSV", class = "btn-sm btn-outline-secondary")),
      DT::DTOutput(ns("table"))),
    bslib::layout_columns(col_widths = c(6, 6),
      report_card("Share of filings by case type", "NCSC 8", plotly::plotlyOutput(ns("share"))),
      report_card("Change vs. preceding period of equal length", "NCSC 14", DT::DTOutput(ns("compare")))))
}

inventory_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    by <- shiny::reactive(if (input$by == "type") "case_type_code" else c("court_code", "case_type_code"))
    inv <- shiny::reactive({
      x <- caseload_inventory(f()$cases, f()$from, f()$to, by = by())
      x[order(-filed)]
    })
    output$table <- DT::renderDT({
      x <- data.table::copy(inv())
      tot <- x[, .(begin_pending = sum(begin_pending), filed = sum(filed), disposed = sum(disposed),
                   end_pending = sum(end_pending))]
      tot[, change := end_pending - begin_pending]
      tot[, `:=`(change_pct = change / begin_pending, clearance_rate = disposed / filed, share_of_filings = 1)]
      for (b in by()) tot[, (b) := "Total"]
      x <- rbind(x, tot, use.names = TRUE)
      fi_table(x, pct = c("change_pct", "clearance_rate", "share_of_filings"),
               num = c("begin_pending", "filed", "disposed", "end_pending", "change"),
               page_length = 25, labels = INVENTORY_LABELS)
    })
    output$download <- shiny::downloadHandler(
      filename = function() sprintf("caseload_inventory_%s_%s.csv", fmt_date(f()$from), fmt_date(f()$to)),
      content = function(file) write_csv_eu_file(inv(), file))
    output$share <- plotly::renderPlotly({
      x <- caseload_inventory(f()$cases, f()$from, f()$to, by = "case_type_code")
      plot_hbar(x, "case_type_code", "share_of_filings", pal, x_title = "Share of filings", x_fmt = ".1%",
                hover = paste(fmt_num(x$filed), "cases")) |> plotly::layout(xaxis = list(tickformat = ".0%"))
    })
    output$compare <- DT::renderDT({
      x <- period_comparison(f()$cases, f()$from, f()$to)
      fi_table(x, num = c("filed", "disposed", "filed_prev", "disposed_prev"),
               pct = c("filed_change_pct", "disposed_change_pct"), labels = INVENTORY_LABELS)
    })
  })
}
