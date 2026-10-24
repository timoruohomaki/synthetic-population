# Robust file I/O ----------------------------------------------------------

#' Create a directory (recursively) and verify it is writable.
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    ok <- dir.create(path, recursive = TRUE, showWarnings = FALSE)
    if (!ok && !dir.exists(path)) {
      ccms_abort(sprintf("Cannot create directory '%s'", path), "ccms_io_error")
    }
  }
  if (file.access(path, mode = 2) != 0) {
    ccms_abort(sprintf("Directory '%s' is not writable", path), "ccms_io_error")
  }
  normalizePath(path, mustWork = TRUE)
}

#' Read a required file, failing with a clear message when missing.
assert_readable <- function(path) {
  if (!file.exists(path)) {
    ccms_abort(sprintf("File not found: '%s'", path), "ccms_io_error")
  }
  if (file.access(path, mode = 4) != 0) {
    ccms_abort(sprintf("File not readable: '%s'", path), "ccms_io_error")
  }
  invisible(path)
}

#' Parse a YAML file with error context.
read_yaml_file <- function(path) {
  assert_readable(path)
  tryCatch(
    yaml::read_yaml(path, eval.expr = FALSE),
    error = function(e) {
      ccms_abort(sprintf("Invalid YAML in '%s': %s", path, conditionMessage(e)),
                 "ccms_config_error")
    }
  )
}

#' Write to a temp file in the same directory, then rename atomically.
#' `writer` is a function(tmp_path) that writes the content.
atomic_write <- function(path, writer) {
  dir <- dirname(path)
  ensure_dir(dir)
  tmp <- tempfile(pattern = ".tmp_", tmpdir = dir, fileext = paste0(".", tools::file_ext(path)))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  writer(tmp)
  if (!file.exists(tmp)) {
    ccms_abort(sprintf("Writer produced no output for '%s'", path), "ccms_io_error")
  }
  if (file.exists(path) && !file.remove(path)) {
    ccms_abort(sprintf("Cannot replace existing file '%s'", path), "ccms_io_error")
  }
  if (!file.rename(tmp, path)) {
    ccms_abort(sprintf("Atomic rename failed for '%s'", path), "ccms_io_error")
  }
  invisible(path)
}

#' Write a data.table as CSV for Finnish/European locales:
#' ';' field separator, ',' decimal mark, UTF-8, ISO 8601 dates as text.
write_csv_eu <- function(dt, path) {
  atomic_write(path, function(tmp) {
    data.table::fwrite(dt, tmp, sep = ";", dec = ",", na = "",
                       bom = FALSE, quote = "auto", dateTimeAs = "ISO")
  })
}

#' Read a CSV written by write_csv_eu.
read_csv_eu <- function(path) {
  assert_readable(path)
  data.table::fread(path, sep = ";", dec = ",", encoding = "UTF-8", na.strings = "")
}
