# Growable column store backed by data.table (in-place, amortised O(1)) ----
# Plain R vectors held in environments are copied on every element assignment
# inside functions; data.table::set() writes by reference instead.

#' Create a recorder. `schema` is a named list of prototype vectors,
#' e.g. list(case_id = integer(), day = integer(), code = character()).
rec_new <- function(schema, capacity = 1024L) {
  rec <- new.env(parent = emptyenv())
  rec$proto <- lapply(schema, function(v) { length(v) <- 0; v })
  rec$dt <- na_block(rec$proto, capacity)
  rec$n <- 0L
  rec
}

na_block <- function(proto, n) {
  data.table::as.data.table(lapply(proto, function(v) { length(v) <- n; v }))
}

#' Append one row; unspecified fields stay NA. Returns the row index.
rec_push <- function(rec, ...) {
  vals <- list(...)
  i <- rec$n + 1L
  if (i > nrow(rec$dt)) {
    rec$dt <- rbind(rec$dt, na_block(rec$proto, nrow(rec$dt)))
  }
  data.table::set(rec$dt, i = i, j = names(vals), value = vals)
  rec$n <- i
  i
}

#' Read field(s) of row(s).
rec_get <- function(rec, field, i) rec$dt[[field]][i]

#' Update a single field of an existing row.
rec_set <- function(rec, i, field, value) {
  if (i < 1L || i > rec$n) ccms_abort(sprintf("Row %d out of range", i), "ccms_sim_error")
  data.table::set(rec$dt, i = i, j = field, value = value)
  invisible(i)
}

rec_size <- function(rec) rec$n

#' Materialise the recorded rows as a data.table (copy).
rec_to_dt <- function(rec) rec$dt[seq_len(rec$n)]

# Per-entity mutable state ---------------------------------------------------

#' Get a case/judge state field.
sget <- function(dt, field, i) dt[[field]][i]

#' Set a case/judge state field in place.
sput <- function(dt, field, i, value) data.table::set(dt, i = i, j = field, value = value)

#' Add delta to a numeric state field in place.
sadd <- function(dt, field, i, delta) data.table::set(dt, i = i, j = field, value = dt[[field]][i] + delta)

#' Capacity grid stored day-major (row = day + 1, column = resource index).
grid_new <- function(mat) {
  dt <- data.table::as.data.table(t(mat))
  data.table::setnames(dt, as.character(seq_len(ncol(dt))))
  dt
}
grid_get <- function(g, res, days) g[[res]][days + 1L]
grid_add <- function(g, res, day, delta) {
  data.table::set(g, i = day + 1L, j = res, value = g[[res]][day + 1L] + delta)
}
