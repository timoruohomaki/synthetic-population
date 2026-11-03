# Step 13 (companies): company names from a Latin word list -----------------
#
# Names follow common Finnish patterns: "Lumen Vitae Oy", "Ferrum Virtanen
# Ky", "Osuuskunta Aurora", "Tmi Matti Virtanen". Latin words keep the names
# realistic-looking but unlikely to match a registered company.
#
# What you'll learn:
#   - cleaning a word list: first token only, letters only, sensible length
#   - capitalising words with substr() and toupper()
#   - switch()-like choices for many rows at once with a lookup by name
#   - making names unique by adding a word to the duplicates only

#' Read the word list (one word or phrase per row, first column) and clean it.
#' Your own list in data/ wins; otherwise the shared one in reference/.
read_company_words <- function(cfg) {
  hits <- find_shared_file(cfg, cfg$sources$company_words)
  log_info("Reading company name words: ", basename(hits[1]))
  raw <- readr::read_csv(hits[1], col_types = readr::cols(.default = "c"), progress = FALSE)
  words <- tolower(sub("[ ,(/].*", "", trimws(raw[[1]])))   # "iubeo iussi" -> "iubeo"
  words <- unique(words[grepl("^[a-z]{4,10}$", words)])
  if (length(words) < 200) abort("Word list ", basename(hits[1]), " has only ", length(words), " usable words")
  words
}

#' "lumen" -> "Lumen"
capitalise <- function(x) paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))

#' Company names for company forms ("oy", "ky", "ay", "osk", "tmi").
#' Partnerships and sole traders use the contact person's names.
make_company_names <- function(form, words, first_name, last_name) {
  n <- length(form)
  w1 <- capitalise(sample(words, n, replace = TRUE))
  w2 <- capitalise(sample(words, n, replace = TRUE))
  two_words <- stats::runif(n) < 0.4
  latin <- ifelse(two_words, paste(w1, w2), w1)
  personal_tmi <- stats::runif(n) < 0.5
  name <- character(n)
  name[form == "oy"] <- paste(latin, "Oy")[form == "oy"]
  name[form == "ky"] <- paste(w1, last_name, "Ky")[form == "ky"]
  name[form == "ay"] <- paste(w1, last_name, "Ay")[form == "ay"]
  name[form == "osk"] <- paste("Osuuskunta", latin)[form == "osk"]
  tmi <- form == "tmi"
  name[tmi] <- ifelse(personal_tmi, paste("Tmi", first_name, last_name), paste(w1, last_name))[tmi]
  make_names_unique(name, words)
}

#' Registered names must be unique: add a Latin word to repeats, before the
#' company form ("Lumen Oy" -> "Lumen Ferrum Oy").
make_names_unique <- function(name, words) {
  for (attempt in 1:10) {
    dup <- duplicated(tolower(name))
    if (!any(dup)) return(name)
    extra <- capitalise(sample(words, sum(dup), replace = TRUE))
    old <- name[dup]
    suffix <- ifelse(grepl(" (Oy|Ky|Ay)$", old), substring(old, nchar(old) - 2), "")  # " Oy"
    name[dup] <- paste0(sub(" (Oy|Ky|Ay)$", "", old), " ", extra, suffix)
  }
  abort("Could not make company names unique; use a longer word list")
}

#' Web-safe slug for domains: "Lumen Vitae Oy" -> "lumenvitae".
company_slug <- function(name) {
  slug <- ascii_name(gsub("\\b(Oy|Ky|Ay|Tmi|Osuuskunta)\\b", "", name))
  gsub("-", "", slug)
}
