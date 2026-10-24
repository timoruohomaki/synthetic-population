# Pending caseload: age, status and exceptions (Model Reports 20, 23, 25-27)

aging_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_columns(col_widths = c(7, 5),
      report_card("Age of pending cases", "NCSC 20", plotly::plotlyOutput(ns("age"))),
      report_card("Status of pending cases (next step awaited)", "NCSC 23 / 26", plotly::plotlyOutput(ns("status")))),
    report_card("Exception report: cases pending longer than the time standard", "NCSC 25 / 27",
      shiny::div(class = "d-flex justify-content-between align-items-center",
        shiny::textOutput(ns("exc_summary")),
        shiny::downloadButton(ns("download"), "Download CSV", class = "btn-sm btn-outline-secondary")),
      DT::DTOutput(ns("exceptions"))))
}

aging_server <- function(id, d, f, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    pal <- cfg$palette
    breaks <- unlist(cfg$age_breaks)
    # Ordinal buckets: one sequential (blue) ramp, light -> dark, starting at step 250.
    ramp <- c("#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#104281", "#0d366b")
    bucket_cols <- stats::setNames(ramp[seq_len(length(breaks) + 1)], age_labels(breaks))
    output$age <- plotly::renderPlotly({
      x <- age_of_pending(f()$cases, f()$as_of, breaks)
      if (nrow(x) == 0) return(empty_plot("No pending cases at this date"))
      x[, label := sprintf("%s (n=%s, median %s d)", case_type_code, fmt_num(total), fmt_num(median_age))]
      plot_stacked(x, "label", "share", "bucket", bucket_cols, pal, y_title = "Share of pending cases",
                   horizontal = TRUE, y_fmt = ".1%", percent = TRUE)
    })
    pending_status <- shiny::reactive({
      ids <- f()$cases[is_pending(f()$cases, f()$as_of), case_id]
      s <- status_at(d$case_status_history, ids, f()$as_of)
      merge(s[, .N, by = status_code], d$status_code[, .(status_code, phase, description)], by = "status_code")
    })
    output$status <- plotly::renderPlotly({
      x <- pending_status()
      plot_hbar(x, "status_code", "N", pal, x_title = "Pending cases", hover = paste(x$phase, "–", x$description))
    })
    exc <- shiny::reactive(exception_list(f()$cases, d$case_status_history, d$hearing, d$judge,
                                          f()$as_of, cfg$time_standards))
    output$exc_summary <- shiny::renderText({
      n_p <- sum(is_pending(f()$cases, f()$as_of))
      sprintf("%s of %s pending cases (%s) exceed their standard on %s. Sorted by days over standard.",
              fmt_num(nrow(exc())), fmt_num(n_p), fmt_pct(nrow(exc()) / max(1, n_p)), fmt_date(f()$as_of))
    })
    output$exceptions <- DT::renderDT({
      x <- data.table::copy(exc())
      if (nrow(x) == 0) return(fi_table(data.table::data.table(message = "No exceptions")))
      fi_table(x, num = c("age", "standard", "over_by"), page_length = 15,
        labels = list(case_number = "Case number", court_code = "Court", case_type_code = "Type",
          filing_date = "Filed", age = "Age (d)", standard = "Standard (d)", over_by = "Over by (d)",
          status_code = "Status", next_hearing = "Next hearing", judge_code = "Judge"))
    })
    output$download <- shiny::downloadHandler(
      filename = function() sprintf("exception_report_%s.csv", fmt_date(f()$as_of)),
      content = function(file) write_csv_eu_file(exc(), file))
  })
}
