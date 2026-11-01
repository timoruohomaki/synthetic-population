# Step 2: read the name statistics of the Digital and Population Data Services
# Agency (DVV) --------------------------------------------------------------
#
# What you'll learn:
#   - readxl::excel_sheets() and read_excel() for multi-sheet Excel files
#   - renaming columns, filter(), arrange() with dplyr
#   - why we keep the counts: they become sampling weights in step 5

#' Read one sheet into a tibble(name, count).
read_name_sheet <- function(path, sheet) {
  df <- readxl::read_excel(path, sheet = sheet)
  if (ncol(df) < 2) abort("Sheet '", sheet, "' in ", basename(path), " has fewer than 2 columns")
  df <- df[, 1:2]
  names(df) <- c("name", "count")
  df |>
    dplyr::mutate(name = trimws(as.character(name)), count = suppressWarnings(as.numeric(count))) |>
    dplyr::filter(!is.na(name), name != "", !is.na(count), count > 0) |>
    dplyr::arrange(dplyr::desc(count))
}

#' Pick the sheet whose name matches `pattern` (case-insensitive).
match_sheet <- function(path, pattern) {
  sheets <- readxl::excel_sheets(path)
  hit <- sheets[grepl(pattern, sheets, ignore.case = TRUE)]
  if (length(hit) != 1) {
    abort("Expected one sheet matching '", pattern, "' in ", basename(path),
          ", found: ", paste(sheets, collapse = ", "))
  }
  hit
}

#' Read first and last name statistics.
#' Returns a list of tibbles: first_female, first_male (first given name),
#' other_female, other_male (second and later given names) and last.
read_names <- function(cfg) {
  data_dir <- file.path(cfg$root, "data")
  first_path <- find_source_file(data_dir, cfg$sources$first_names)
  last_path <- find_source_file(data_dir, cfg$sources$last_names)
  log_info("Reading first names: ", basename(first_path))
  sheet <- function(pattern) read_name_sheet(first_path, match_sheet(first_path, pattern))
  names_list <- list(
    first_female = sheet("^naiset ens"),
    first_male = sheet("^miehet ens"),
    other_female = sheet("^naiset muut"),
    other_male = sheet("^miehet muut")
  )
  log_info("Reading last names: ", basename(last_path))
  names_list$last <- read_name_sheet(last_path, match_sheet(last_path, "^nimet$"))
  sizes <- vapply(names_list, nrow, integer(1))
  if (any(sizes < 100)) abort("Name lists look too short: ", paste(names(sizes), sizes, collapse = ", "))
  log_info("Names: ", paste(names(sizes), fmt_int(sizes), sep = " = ", collapse = ", "))
  names_list
}
