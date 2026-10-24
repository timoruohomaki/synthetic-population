# Global filters (sidebar): courts, case categories and types, period, as-of date

filters_ui <- function(id, d) {
  ns <- shiny::NS(id)
  last_filing <- d$sim_run$end_date[1]
  types <- d$case_type[order(category, case_type_code)]
  shiny::tagList(
    shiny::checkboxGroupInput(ns("courts"), "Courts", choices = d$court$court_code, selected = d$court$court_code),
    shiny::checkboxGroupInput(ns("categories"), "Case category",
      choices = c("Criminal" = "CRIMINAL", "Non-criminal" = "NON_CRIMINAL"), selected = c("CRIMINAL", "NON_CRIMINAL")),
    shiny::selectizeInput(ns("types"), "Case types", multiple = TRUE,
      choices = stats::setNames(types$case_type_code, paste0(types$case_type_code, " – ", types$description)),
      selected = types$case_type_code, options = list(plugins = list("remove_button"))),
    shiny::dateRangeInput(ns("period"), "Reporting period", start = as.Date(format(last_filing, "%Y-01-01")),
      end = last_filing, min = d$start, max = d$cutoff, format = "yyyy-mm-dd", weekstart = 1),
    shiny::dateInput(ns("as_of"), "Pending caseload as of", value = last_filing, min = d$start,
      max = d$cutoff, format = "yyyy-mm-dd", weekstart = 1),
    shiny::hr(),
    shiny::tags$small(class = "text-muted",
      shiny::HTML(sprintf("Run <code>%s</code><br>Filings %s – %s<br>Extraction (cutoff) %s<br>%s",
        d$run_id, fmt_date(d$start), fmt_date(last_filing), fmt_date(d$cutoff),
        "After the last filing date the data show run-off only (no new filings).")))
  )
}

#' Returns a reactive list: cases (filtered), from, to, as_of, courts.
filters_server <- function(id, d) {
  shiny::moduleServer(id, function(input, output, session) {
    # Keep the type selector consistent with the chosen categories.
    shiny::observeEvent(input$categories, {
      keep <- d$case_type[category %in% input$categories, case_type_code]
      shiny::updateSelectizeInput(session, "types", selected = intersect(input$types %||% keep, keep) %||% keep)
    }, ignoreNULL = FALSE)

    shiny::reactive({
      shiny::validate(
        shiny::need(length(input$courts) > 0, "Select at least one court."),
        shiny::need(length(input$categories) > 0, "Select at least one case category."),
        shiny::need(length(input$types) > 0, "Select at least one case type."),
        shiny::need(!any(is.na(input$period)) && input$period[1] <= input$period[2],
                    "The reporting period must start before it ends."),
        shiny::need(!is.na(input$as_of), "Choose an as-of date."))
      cases <- filter_cases(d$court_case, input$courts, input$categories, input$types)
      shiny::validate(shiny::need(nrow(cases) > 0, "No cases match the current filters."))
      list(cases = cases, from = as.Date(input$period[1]), to = as.Date(input$period[2]),
           as_of = as.Date(input$as_of), courts = input$courts)
    }) |> shiny::debounce(300)
  })
}
