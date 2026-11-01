# Step 5: draw the people - sex, birth date, names and address --------------
#
# What you'll learn:
#   - sample() with `prob =` weights: common names are drawn more often
#   - working with Dates: sequences, differences and ages
#   - vectorised code: one call handles a million rows, no loops over people
#   - ifelse() / dplyr::case_when() to build columns conditionally

#' Draw `n` names from a tibble(name, count), weighted by count.
draw_names <- function(names_tbl, n) {
  if (n == 0) return(character(0))
  sample(names_tbl$name, n, replace = TRUE, prob = names_tbl$count)
}

#' Age in whole years on `ref` for each birth date.
age_on <- function(birth, ref) {
  years <- as.integer(format(ref, "%Y")) - as.integer(format(birth, "%Y"))
  before_birthday <- format(ref, "%m%d") < format(birth, "%m%d")
  years - before_birthday
}

#' Same calendar day `k` years earlier (29.2. becomes 28.2.).
years_before <- function(date, k) {
  y <- as.integer(format(date, "%Y")) - k
  md <- format(date, "%m-%d")
  md[md == "02-29"] <- "02-28"
  as.Date(paste0(y, "-", md))
}

#' Birth dates: choose an age band by weight, then a uniform day inside it.
draw_birth_dates <- function(n, bands, ref) {
  weights <- vapply(bands, `[[`, numeric(1), "weight")
  band <- sample(seq_along(bands), n, replace = TRUE, prob = weights)
  birth <- as.Date(rep(NA_real_, n))
  for (b in unique(band)) {  # a loop over 4 bands, not over people
    idx <- which(band == b)
    latest <- years_before(ref, bands[[b]]$from)           # turns `from` today
    earliest <- years_before(ref, bands[[b]]$to + 1) + 1   # turns `to + 1` tomorrow
    span <- as.integer(latest - earliest)
    birth[idx] <- earliest + sample.int(span + 1, length(idx), replace = TRUE) - 1
  }
  birth
}

#' Given names for one sex: first name from the "first given name" list,
#' second and third from the "other given names" list, no repeats.
draw_given_names <- function(n, first_tbl, other_tbl, count_probs) {
  k <- sample(seq_along(count_probs), n, replace = TRUE, prob = count_probs)
  first <- draw_names(first_tbl, n)
  second <- ifelse(k >= 2, draw_names(other_tbl, n), NA)
  third <- ifelse(k >= 3, draw_names(other_tbl, n), NA)
  second[which(second == first)] <- NA          # drop a name that repeats
  third[which(third == first | third == second)] <- NA
  all <- paste(first, ifelse(is.na(second), "", second), ifelse(is.na(third), "", third))
  list(first_name = first, given_names = gsub(" +", " ", trimws(all)))
}

#' The people table: one row per person, without identifiers yet.
draw_people <- function(cfg, names_list, addresses) {
  n <- cfg$run$n_persons
  ref <- cfg$run$reference_date
  sex <- ifelse(stats::runif(n) < cfg$people$share_female, "F", "M")
  birth <- draw_birth_dates(n, cfg$people$age_bands, ref)
  probs <- unlist(cfg$people$given_name_counts)
  first_name <- character(n)
  given_names <- character(n)
  for (s in c("F", "M")) {  # a loop over two sexes, not over people
    idx <- which(sex == s)
    key <- if (s == "F") "female" else "male"
    g <- draw_given_names(length(idx), names_list[[paste0("first_", key)]],
                          names_list[[paste0("other_", key)]], probs)
    first_name[idx] <- g$first_name
    given_names[idx] <- g$given_names
  }
  home <- addresses[sample.int(nrow(addresses), n, replace = TRUE), ]
  tibble::tibble(person_id = seq_len(n), sex = sex, first_name = first_name,
                 given_names = given_names, last_name = draw_names(names_list$last, n),
                 birth_date = birth, age = age_on(birth, ref)) |>
    dplyr::bind_cols(home)
}
