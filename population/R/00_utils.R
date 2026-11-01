# Shared helpers: logging, errors, finding files, safe writing ----------------
#
# What you'll learn:
#   - writing small reusable functions
#   - stop() with clear messages, and checking inputs early
#   - Sys.glob() to find files by pattern, file.info() to pick the newest

#' Print a timestamped message (RFC 3339, UTC).
log_info <- function(...) {
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  message(ts, " ", paste0(...))
}

#' Format whole numbers the Finnish way: 1000000 -> "1.000.000".
fmt_int <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")

#' Stop with a message that names the problem and how to fix it.
abort <- function(...) stop(paste0(...), call. = FALSE)

#' Run `expr`, log how long it took and return its value.
timed <- function(label, expr) {
  t0 <- Sys.time()
  value <- force(expr)
  log_info(label, " (", format(round(difftime(Sys.time(), t0, units = "secs"), 1)), ")")
  value
}

#' Find the population project folder: the folder holding config.yaml and R/.
#' Works when the working directory is the project, the repo root or a subfolder.
find_project_root <- function(start = getwd()) {
  dir <- normalizePath(start, mustWork = FALSE)
  for (i in 1:5) {
    for (cand in c(dir, file.path(dir, "population"))) {
      if (file.exists(file.path(cand, "config.yaml")) && dir.exists(file.path(cand, "R"))) {
        return(normalizePath(cand))
      }
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) break
    dir <- parent
  }
  abort("Cannot find the population project (config.yaml + R/). ",
        "Open population/synthetic-population.Rproj in RStudio or setwd() to that folder.")
}

#' Newest file in `dir` matching a glob `pattern`; a clear error if none exists.
find_source_file <- function(dir, pattern) {
  hits <- Sys.glob(file.path(dir, pattern))
  if (length(hits) == 0) {
    abort("No file matching '", pattern, "' in ", dir,
          ". See data/README.md for where to download it.")
  }
  hits[which.max(file.info(hits)$mtime)]
}

#' Check that a data frame has the expected columns.
require_columns <- function(df, cols, what) {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    abort(what, " is missing column(s): ", paste(missing, collapse = ", "),
          ". The source file format may have changed.")
  }
  invisible(df)
}

#' Write a file through a temporary name so a crash never leaves half a file.
#' `writer` is a function(path) that writes the content.
write_atomically <- function(path, writer) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".partial")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  writer(tmp)
  if (file.exists(path) && !file.remove(path)) abort("Cannot replace ", path)
  if (!file.rename(tmp, path)) abort("Cannot write ", path)
  invisible(path)
}

#' Running number inside each group: c("a","b","a") -> c(1, 1, 2).
#' Sorting once is much faster than splitting a million rows into groups;
#' method = "radix" sorts a million strings in well under a second.
rank_within <- function(key, shuffle = FALSE) {
  ord <- if (shuffle) order(key, stats::runif(length(key)), method = "radix") else order(key, method = "radix")
  rank <- integer(length(key))
  rank[ord] <- sequence(rle(key[ord])$lengths)
  rank
}
