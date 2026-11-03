# Step 17 (lesson): enrich persons with hobbies ------------------------------
#
# Not part of generate_population(): see lessons/enrich_hobbies.R for the
# lesson that uses these functions step by step.
#
# What you'll learn:
#   - weighted sampling with sample(prob = ): fast even for a million draws
#   - where weights come from: a column in the source file, or an assumption
#     you write down (Zipf's law) when the source has none
#   - one-to-many data: a long table person_id + hobby instead of a text list
#   - removing repeats inside a group and redrawing only those rows

#' Read the hobby list (first sheet). Column 1 = hobby; an optional column
#' 2 = weight (popularity). A file without a header row is handled too.
read_hobbies <- function(cfg) {
  path <- find_source_file(file.path(cfg$root, "data"), cfg$hobbies$source)
  log_info("Reading hobbies: ", basename(path))
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE, .name_repair = "minimal")
  hobby <- trimws(as.character(raw[[1]]))
  weight <- if (ncol(raw) >= 2) suppressWarnings(as.numeric(raw[[2]])) else rep(NA_real_, length(hobby))
  header <- seq_along(hobby) == 1 & tolower(hobby) %in% c("hobby", "hobbies", "harrastus", "harrastukset")
  keep <- !header & !is.na(hobby) & hobby != ""
  out <- tibble::tibble(hobby = hobby[keep], weight = weight[keep]) |>
    dplyr::distinct(hobby, .keep_all = TRUE)
  if (nrow(out) < 10) abort("Hobby list ", basename(path), " has only ", nrow(out), " hobbies")
  out
}

#' Weights by Zipf's law: the r-th most popular hobby is 1 / r^s as popular as
#' the first. The popularity order is random (but repeatable with the seed),
#' because the list itself carries no popularity information.
zipf_weights <- function(n, exponent = 1) {
  rank <- sample.int(n)               # a random popularity order
  1 / rank^exponent
}

#' Use the weight column when it is complete, otherwise Zipf weights.
hobby_weights <- function(hobbies, exponent = 1) {
  w <- hobbies$weight
  if (all(!is.na(w)) && all(w >= 0) && sum(w) > 0) return(w)
  log_info("No complete weight column: using Zipf weights (exponent ", exponent, ")")
  zipf_weights(nrow(hobbies), exponent)
}

#' Give each person 0..k hobbies, no hobby twice for the same person.
#' Returns a long table: one row per person and hobby.
assign_hobbies <- function(person_id, hobbies, weights, count_probs) {
  k <- sample(seq_along(count_probs) - 1L, length(person_id), replace = TRUE, prob = count_probs)
  row <- rep(seq_along(person_id), times = k)       # person 7 with 3 hobbies -> 7, 7, 7
  m <- nrow(hobbies)
  # Draw row numbers, not names: numbers are faster to compare than text.
  pick <- sample.int(m, length(row), replace = TRUE, prob = weights)
  for (attempt in 1:50) {                           # a loop over attempts, not people
    dup <- duplicated(row * m + pick)               # one number per person + hobby
    if (!any(dup)) break
    pick[dup] <- sample.int(m, sum(dup), replace = TRUE, prob = weights)
  }
  if (anyDuplicated(row * m + pick)) abort("Could not draw distinct hobbies; lower hobbies.count_probs")
  tibble::tibble(person_id = person_id[row], hobby = hobbies$hobby[pick])
}

#' One text column per person, e.g. "Archery, Yoga" (for viewing, not analysis).
hobbies_as_text <- function(person_hobbies, person_id, sep = ", ") {
  text <- tapply(person_hobbies$hobby, person_hobbies$person_id, paste, collapse = sep)
  out <- as.vector(text[as.character(person_id)])     # tapply returns an array
  ifelse(is.na(out), "", out)
}
