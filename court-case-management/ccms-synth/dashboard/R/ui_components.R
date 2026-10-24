# Reusable UI pieces: report cards, tables and chart builders ---------------

#' Card with a title and the NCSC model report it corresponds to.
report_card <- function(title, ref = NULL, ..., height = NULL) {
  bslib::card(full_screen = TRUE, height = height,
    bslib::card_header(class = "d-flex justify-content-between align-items-center",
      shiny::span(title), if (!is.null(ref)) shiny::span(class = "badge text-bg-light", ref)),
    bslib::card_body(...))
}

#' DT table with Finnish number formats; `pct`, `num`, `dec` name columns to format.
fi_table <- function(dt, pct = NULL, num = NULL, dec = NULL, page_length = 10, labels = NULL) {
  if (!is.null(labels)) data.table::setnames(dt, names(labels), unlist(labels), skip_absent = TRUE)
  tb <- DT::datatable(dt, rownames = FALSE, class = "compact stripe hover nowrap",
                      options = list(pageLength = page_length, scrollX = TRUE,
                                     dom = if (nrow(dt) > page_length) "tip" else "t"))
  ren <- function(x) if (!is.null(labels)) unname(sapply(x, function(k) labels[[k]] %||% k)) else x
  if (length(num)) tb <- DT::formatRound(tb, ren(num), digits = 0, mark = ".", dec.mark = ",")
  if (length(dec)) tb <- DT::formatRound(tb, ren(dec), digits = 1, mark = ".", dec.mark = ",")
  if (length(pct)) tb <- DT::formatPercentage(tb, ren(pct), digits = 1, mark = ".", dec.mark = ",")
  tb
}

#' Lines over time, one per group, colours fixed per entity.
plot_lines <- function(dt, x, y, group, colors, pal, y_title = NULL, y_fmt = ",.0f", dash = NULL) {
  if (nrow(dt) == 0) return(empty_plot())
  p <- plotly::plot_ly()
  for (g in intersect(names(colors), unique(dt[[group]]))) {
    s <- dt[dt[[group]] == g]
    p <- plotly::add_trace(p, x = s[[x]], y = s[[y]], type = "scatter", mode = "lines", name = g,
      line = list(color = colors[[g]], width = 2, dash = dash %||% "solid"),
      hovertemplate = paste0("%{y:", y_fmt, "}<extra>", g, "</extra>"))
  }
  p <- viz_layout(p, pal, y_title = y_title)
  if (inherits(dt[[x]], "Date")) p <- iso_month_axis(p)
  p
}

#' Stacked bars; categories stacked in the order of `colors`.
plot_stacked <- function(dt, x, y, stack, colors, pal, y_title = NULL, horizontal = FALSE,
                         y_fmt = ",.0f", percent = FALSE) {
  if (nrow(dt) == 0) return(empty_plot())
  p <- plotly::plot_ly()
  for (g in intersect(names(colors), unique(as.character(dt[[stack]])))) {
    s <- dt[as.character(dt[[stack]]) == g]
    args <- if (horizontal) list(y = s[[x]], x = s[[y]], orientation = "h") else list(x = s[[x]], y = s[[y]])
    hv <- if (horizontal) "%{x:" else "%{y:"
    p <- do.call(plotly::add_trace, c(list(p, type = "bar", name = g,
      marker = list(color = colors[[g]], line = list(color = pal$surface, width = 1)),
      hovertemplate = paste0(hv, y_fmt, "}<extra>", g, "</extra>")), args))
  }
  p <- viz_layout(p, pal, y_title = y_title, barmode = "stack", legend = list(orientation = "h", y = 1.12,
                  x = 0, traceorder = "normal", font = list(color = pal$ink$secondary)))
  if (!horizontal && inherits(dt[[x]], "Date")) p <- iso_month_axis(p)
  if (percent) {
    ax <- list(tickformat = ".0%", range = c(0, 1))
    p <- if (horizontal) plotly::layout(p, xaxis = ax) else plotly::layout(p, yaxis = ax)
  }
  if (horizontal) p <- plotly::layout(p, hovermode = "y unified", yaxis = list(autorange = "reversed"))
  p
}

#' Horizontal bars for one measure across many categories (single hue, sorted).
plot_hbar <- function(dt, label, value, pal, color = NULL, x_title = NULL, x_fmt = ",.0f", hover = NULL) {
  if (nrow(dt) == 0) return(empty_plot())
  o <- order(dt[[value]])
  hover <- if (is.null(hover)) rep("", nrow(dt)) else hover[o]  # keep hover text aligned with sorted bars
  dt <- dt[o]
  p <- plotly::plot_ly(x = dt[[value]], y = factor(dt[[label]], levels = dt[[label]]), type = "bar",
    orientation = "h", marker = list(color = color %||% unlist(pal$categorical)[1]),
    text = hover, textposition = "none",
    hovertemplate = paste0("%{y}: %{x:", x_fmt, "}<br>%{text}<extra></extra>"))
  viz_layout(p, pal, x_title = x_title) |>
    plotly::layout(hovermode = "closest", xaxis = list(tickformat = ",~f"),
                   yaxis = list(title = "", rangemode = "normal", tickformat = ""))
}

#' Value box with an optional status label (icon + text, never colour alone).
kpi_box <- function(title, output_id, note_id = NULL) {
  bslib::value_box(title = title, value = shiny::textOutput(output_id, inline = TRUE),
    if (!is.null(note_id)) shiny::uiOutput(note_id), theme = bslib::value_box_theme(bg = "#fcfcfb", fg = "#0b0b0b"))
}

status_label <- function(level, text, pal) {
  icon <- c(good = "✔", warning = "⚠", serious = "▲", critical = "✖")[[level]]
  shiny::span(style = sprintf("color:%s;font-weight:600", pal$ink$secondary),
    shiny::span(style = sprintf("color:%s", pal$status[[level]]), icon), " ", text)
}
