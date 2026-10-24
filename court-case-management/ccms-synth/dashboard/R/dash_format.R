# Number/date formatting for Finnish locale (thousands '.', decimal ',') -----

fmt_num <- function(x, digits = 0) {
  out <- formatC(x, format = "f", digits = digits, big.mark = ".", decimal.mark = ",")
  out[is.na(x)] <- "–"
  out
}

fmt_pct <- function(x, digits = 1) {
  out <- paste0(fmt_num(100 * x, digits), " %")
  out[is.na(x)] <- "–"
  out
}

fmt_days <- function(x, digits = 0) paste(fmt_num(x, digits), "d")

fmt_date <- function(x) format(as.Date(x), "%Y-%m-%d")

#' Write a CSV for Finnish/European locales (';' separator, ',' decimal).
write_csv_eu_file <- function(dt, path) {
  data.table::fwrite(dt, path, sep = ";", dec = ",", na = "", bom = TRUE)
}

#' Common plotly layout: locale separators, recessive grid, legend on top.
viz_layout <- function(p, pal, y_title = NULL, x_title = NULL, barmode = NULL, legend = NULL, ...) {
  axis <- list(gridcolor = pal$ink$grid, linecolor = pal$ink$axis, zeroline = FALSE,
               tickfont = list(color = pal$ink$secondary), title = list(font = list(color = pal$ink$secondary)))
  p <- plotly::layout(p,
    separators = ",.",
    paper_bgcolor = pal$surface, plot_bgcolor = pal$surface,
    font = list(family = "system-ui, -apple-system, 'Segoe UI', sans-serif", color = pal$ink$primary, size = 12),
    xaxis = utils::modifyList(axis, list(title = list(text = x_title %||% ""))),
    yaxis = utils::modifyList(axis, list(title = list(text = y_title %||% ""), rangemode = "tozero",
                                         tickformat = ",~f")),  # 80.000, not SI "80k"
    legend = legend %||% list(orientation = "h", y = 1.12, x = 0, font = list(color = pal$ink$secondary)),
    hovermode = "x unified", bargap = 0.25, barmode = barmode, margin = list(t = 40, r = 10, b = 40, l = 50), ...)
  plotly::config(p, displaylogo = FALSE,
                 modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d"))
}

#' ISO month ticks (YYYY-MM) for Date x axes; plotly's locale month names are avoided.
iso_month_axis <- function(p) plotly::layout(p, xaxis = list(tickformat = "%Y-%m", hoverformat = "%Y-%m"))

#' Stable colour per entity (never by rank): names -> palette slots in fixed order.
entity_colors <- function(levels, pal) {
  cols <- unlist(pal$categorical)
  if (length(levels) > length(cols)) {
    stop(sprintf("%d series exceed the %d-colour palette; fold extras into 'Other'", length(levels), length(cols)))
  }
  stats::setNames(cols[seq_along(levels)], levels)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Empty-state plot with a message (used when filters leave no data).
empty_plot <- function(msg = "No data for the current filters") {
  plotly::layout(plotly::plotly_empty(type = "scatter", mode = "markers"),
                 annotations = list(text = msg, showarrow = FALSE, font = list(size = 14, color = "#898781")))
}
