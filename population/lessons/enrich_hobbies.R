# Lesson: enriching data - give every person hobbies -------------------------
#
# Run one line at a time in RStudio (Ctrl+Enter). You need data/hobbies.xlsx:
# one hobby per row in the first column, optionally a popularity weight in the
# second. The functions used here are in R/17_hobbies.R.
#
# Questions this lesson answers:
#   1. Is sample() fast enough for a million people? (Yes.)
#   2. How do popular hobbies get picked more often? (prob = weights.)
#   3. Where do the weights come from when the list has none?
#   4. How do we store several hobbies per person? (A long table.)

source("generate_population.R")
cfg <- load_config(find_project_root())
set.seed(cfg$run$seed)

# A population to enrich: the newest saved one, or a quick new one.
saved <- sort(Sys.glob(file.path(cfg$root, "output", "population_*.rds")), decreasing = TRUE)
pop <- if (length(saved) > 0) readRDS(saved[1]) else
  generate_population(n = 100000, write = FALSE)$persons
nrow(pop)

# 1. The hobby list -------------------------------------------------------------
hobbies <- read_hobbies(cfg)
hobbies                      # weight is NA: the file says nothing about popularity

# 2. Plain sample(): every hobby is equally likely ------------------------------
system.time(uniform <- sample(hobbies$hobby, nrow(pop), replace = TRUE))
head(sort(table(uniform), decreasing = TRUE))    # all about nrow(pop) / 129

# 3. Weighted sample(): popular hobbies more often --------------------------------
# prob = gives each value a weight; the weights don't need to sum to 1.
toy <- sample(c("Reading", "Fishing", "Beekeeping"), 1e5, replace = TRUE, prob = c(60, 30, 10))
prop.table(table(toy))                           # about 0,60 / 0,30 / 0,10

# The list has no weights, so we make an assumption and write it down:
# Zipf's law - the r-th most popular hobby is 1/r as popular as the first.
w <- hobby_weights(hobbies, cfg$hobbies$zipf_exponent)
system.time(weighted <- sample(hobbies$hobby, nrow(pop), replace = TRUE, prob = w))
head(sort(table(weighted), decreasing = TRUE))

# How does it work? Cumulative weights cut 0..1 into slices, one per hobby;
# a random number falls into a slice with the probability of its width.
slices <- cumsum(w) / sum(w)
by_hand <- hobbies$hobby[findInterval(runif(nrow(pop)), slices) + 1]
head(sort(table(by_hand), decreasing = TRUE))   # same shape as `weighted`

# The exponent decides how dominant the favourites are:
for (s in c(0, 0.5, 1, 1.5)) {
  ws <- 1 / seq_len(nrow(hobbies))^s
  cat("exponent", s, ": top hobby share", round(100 * max(ws) / sum(ws), 1), "%\n")
}

# 4. Several hobbies per person: a long table ---------------------------------
person_hobbies <- assign_hobbies(pop$person_id, hobbies, w, unlist(cfg$hobbies$count_probs))
person_hobbies                                   # one row per person and hobby
dplyr::count(person_hobbies, person_id) |> dplyr::count(n, name = "persons")
sum(!pop$person_id %in% person_hobbies$person_id)   # persons with no hobby

# Analyse with joins - this is why the long table is useful:
person_hobbies |>
  dplyr::inner_join(pop, by = "person_id") |>
  dplyr::mutate(age_group = cut(age, c(-1, 17, 34, 64, 120), c("0-17", "18-34", "35-64", "65+"))) |>
  dplyr::count(age_group, hobby, sort = TRUE) |>
  dplyr::slice_max(n, n = 3, by = age_group)
# Every age group has the same favourites: the draw ignored age. Exercise b
# below fixes that.

# A text column is handy for viewing or a CSV for Excel, not for analysis:
pop$hobbies <- hobbies_as_text(person_hobbies, pop$person_id)
head(pop[, c("first_name", "last_name", "hobbies")])

# Save the long table next to the population:
write_table(person_hobbies, cfg, "person_hobbies")

# Exercises --------------------------------------------------------------------
#   a) Add a second column to hobbies.xlsx with real popularity figures (for
#      example from a leisure survey) and run the lesson again.
#   b) Make popularity depend on age: give each age group its own weights and
#      sample inside each group (split by age_group, or a loop over 4 groups).
#   c) Children under 7 should not do Wine tasting: set weights to 0 for them.
#   d) Which postal code area has the most beekeepers per 1000 inhabitants?
