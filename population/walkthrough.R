# Walkthrough: build a synthetic population step by step in RStudio ----------
#
# Run this file one line at a time (Ctrl+Enter / Cmd+Enter) and look at each
# result in the Environment pane or with View(). generate_population() does
# the same in one call; here every step is out in the open.

source("generate_population.R")          # loads the functions in R/
cfg <- load_config(find_project_root(), list(run = list(n_persons = 1000)))
set.seed(cfg$run$seed)

# 1. Names: five tables of names with counts ---------------------------------
names_list <- read_names(cfg)
names(names_list)
head(names_list$last, 10)                # Korhonen first: the most common surname
View(names_list$first_female)

# 2. Postcodes and addresses --------------------------------------------------
postcodes <- read_postcodes(cfg)
dplyr::count(postcodes, language)        # 1 = Finnish, 4 = Swedish-speaking
addresses <- load_addresses(cfg, postcodes)   # slow the first time, cached after
dplyr::count(addresses, region, sort = TRUE)

# 3. People -------------------------------------------------------------------
people <- draw_people(cfg, names_list, addresses)
dplyr::glimpse(people)
summary(people$age)
hist(people$age, breaks = 0:100, main = "Age distribution", xlab = "Age")

# 4. Identifiers ----------------------------------------------------------------
people$hetu <- make_hetu(people$birth_date, people$sex, cfg$hetu$mode)
head(hetu_parse(people$hetu))            # the code taken apart again
hetu_check_char("131052", "308")         # the official example: "T"

people$iban <- make_iban(nrow(people), cfg$iban$bank_code)
iban_format(head(people$iban))
people$email <- make_email(people$first_name, people$last_name, cfg$contact$email_domains)
people$phone <- make_phone(nrow(people), cfg$contact$phone_prefixes)

# 5. Check and look -----------------------------------------------------------
pop <- dplyr::select(people, dplyr::all_of(POPULATION_COLUMNS))
validate_population(pop, cfg)
View(pop)

# Common questions answered with dplyr:
pop |> dplyr::count(region, sex)
pop |> dplyr::group_by(region) |>
  dplyr::summarise(persons = dplyr::n(), mean_age = round(mean(age), 1)) |>
  dplyr::arrange(dplyr::desc(persons))
pop |> dplyr::filter(age < 18) |> dplyr::count(municipality, sort = TRUE)
pop |> dplyr::mutate(decade = 10 * (as.integer(format(birth_date, "%Y")) %/% 10)) |>
  dplyr::count(decade)

# Exercises (ideas in README.md):
#   a) Uusimaa is under-represented because addresses are drawn uniformly over
#      buildings. Weight the address draw by municipality population.
#   b) Put people into households: share an address and a last name.
#   c) Draw an age pyramid with ggplot2 (geom_col, coord_flip).
#   d) Save the result to SQLite with DBI + RSQLite and query it with SQL.
