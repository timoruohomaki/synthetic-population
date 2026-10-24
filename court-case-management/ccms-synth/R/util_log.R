# Logging and typed error helpers ------------------------------------------

#' Current UTC timestamp in RFC 3339 format.
now_rfc3339 <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

#' Log a message to stderr with level and RFC 3339 timestamp.
log_msg <- function(level = c("INFO", "WARN", "ERROR", "DEBUG"), ...) {
  level <- match.arg(level)
  if (level == "DEBUG" && !isTRUE(getOption("ccms.debug", FALSE))) {
    return(invisible(NULL))
  }
  msg <- paste0(...)
  cat(sprintf("%s [%s] %s\n", now_rfc3339(), level, msg), file = stderr())
  invisible(msg)
}

log_info <- function(...) log_msg("INFO", ...)
log_warn <- function(...) log_msg("WARN", ...)
log_debug <- function(...) log_msg("DEBUG", ...)

#' Raise a classed condition so callers can handle error categories.
ccms_abort <- function(message, class = "ccms_error", data = NULL) {
  cond <- structure(
    class = c(class, "ccms_error", "error", "condition"),
    list(message = message, call = sys.call(-1), data = data)
  )
  stop(cond)
}

#' Assertion that raises a ccms_validation_error with a readable message.
assert_that <- function(condition, message) {
  if (!isTRUE(condition)) {
    ccms_abort(message, class = "ccms_validation_error")
  }
  invisible(TRUE)
}

#' Assert that x is a single finite number inside [lower, upper].
assert_number <- function(x, name, lower = -Inf, upper = Inf) {
  ok <- is.numeric(x) && length(x) == 1L && is.finite(x) && x >= lower && x <= upper
  assert_that(ok, sprintf("'%s' must be a number in [%s, %s], got: %s",
                          name, lower, upper, paste(format(x), collapse = ",")))
}

#' Assert that x is a probability.
assert_prob <- function(x, name) assert_number(x, name, 0, 1)

#' Run expr, logging duration; errors propagate unchanged.
with_timing <- function(label, expr) {
  t0 <- proc.time()[["elapsed"]]
  log_info(label, " ...")
  result <- force(expr)
  log_info(label, " done in ", sprintf("%.1f", proc.time()[["elapsed"]] - t0), " s")
  result
}
