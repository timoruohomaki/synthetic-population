# Build the Latin word list used for company names (R/13_company_names.R) ---
#
# Downloads a public Latin-English word list and saves one Latin entry per row
# to latin_words.csv. The repository already contains the result, so you only
# need this to rebuild or extend the list.
#
#   Rscript extras/company-names/extract_latin_words.R [output.csv]
#
# What you'll learn:
#   - reading a web page with rvest (read_html, html_text2)
#   - extracting the text before ":" on each line with a regular expression
#   - failing clearly when the page cannot be read or looks different

WORD_LIST_URL <- "https://personal.math.ubc.ca/~cass/frivs/latin/latin-dict-full.html"

#' Latin entries from the dictionary text: lines "word: meaning".
extract_latin_words <- function(text) {
  lines <- trimws(unlist(strsplit(text, "\n", fixed = TRUE)))
  entry <- regmatches(lines, regexpr("^[^:\\[]+(?=:)", lines, perl = TRUE))
  entry <- trimws(sub("[,/].*$", "", entry))          # "amo, amare" -> "amo"
  unique(entry[nchar(entry) > 0])
}

#' Download the page and write the words to `out` (CSV with a column "x").
build_word_list <- function(out, url = WORD_LIST_URL) {
  if (!requireNamespace("rvest", quietly = TRUE)) stop("install.packages(\"rvest\")", call. = FALSE)
  page <- tryCatch(rvest::read_html(url),
                   error = function(e) stop("Cannot read ", url, ": ", conditionMessage(e), call. = FALSE))
  words <- extract_latin_words(rvest::html_text2(page))
  if (length(words) < 500) stop("Only ", length(words), " words found; has the page changed?", call. = FALSE)
  tmp <- paste0(out, ".partial")
  utils::write.csv(data.frame(x = words), tmp, row.names = FALSE, fileEncoding = "UTF-8")
  if (!file.rename(tmp, out)) stop("Cannot write ", out, call. = FALSE)
  message("Saved ", length(words), " words to ", out)
  invisible(words)
}

if (!interactive() && sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- if (length(args) >= 1) args[1] else "latin_words.csv"
  status <- tryCatch({ build_word_list(out); 0 }, error = function(e) { message("ERROR: ", conditionMessage(e)); 1 })
  quit(status = status, save = "no")
}
