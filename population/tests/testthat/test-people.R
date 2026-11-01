fake_names <- function(prefix) tibble::tibble(name = paste0(prefix, 1:200), count = 200:1)

fake_inputs <- function() {
  names_list <- list(first_female = fake_names("Fa"), first_male = fake_names("Ma"),
                     other_female = fake_names("Fb"), other_male = fake_names("Mb"),
                     last = fake_names("L"))
  addresses <- tibble::tibble(street_address = paste("Testikatu", 1:50), postal_code = "00100",
                              post_office = "HELSINKI", municipality_code = "091",
                              municipality = "Helsinki", region_code = "01", region = "Uusimaa")
  list(names = names_list, addresses = addresses)
}

test_that("birth dates stay inside the age bands", {
  set.seed(1)
  ref <- as.Date("2026-01-01")
  bands <- list(list(from = 0, to = 14, weight = 1), list(from = 75, to = 99, weight = 1))
  age <- age_on(draw_birth_dates(5000, bands, ref), ref)
  expect_true(all((age >= 0 & age <= 14) | (age >= 75 & age <= 99)))
  expect_equal(age_on(as.Date("2000-02-29"), as.Date("2026-02-28")), 25)
})

test_that("the whole pipeline works on small in-memory inputs", {
  set.seed(1)
  cfg <- test_config(run = list(n_persons = 2000))
  inp <- fake_inputs()
  pop <- draw_people(cfg, inp$names, inp$addresses) |>
    dplyr::mutate(hetu = make_hetu(birth_date, sex),
                  iban = make_iban(dplyr::n(), cfg$iban$bank_code),
                  email = make_email(first_name, last_name, cfg$contact$email_domains),
                  phone = make_phone(dplyr::n(), cfg$contact$phone_prefixes)) |>
    dplyr::select(dplyr::all_of(POPULATION_COLUMNS))
  expect_equal(nrow(pop), 2000)
  expect_silent(validate_population(pop, cfg) |> suppressMessages())
  expect_true(all(startsWith(pop$given_names, pop$first_name)))
})

test_that("validation reports broken rows", {
  set.seed(1)
  cfg <- test_config(run = list(n_persons = 50))
  inp <- fake_inputs()
  pop <- draw_people(cfg, inp$names, inp$addresses) |>
    dplyr::mutate(hetu = make_hetu(birth_date, sex), iban = make_iban(dplyr::n()),
                  email = make_email(first_name, last_name, "example.com"),
                  phone = make_phone(dplyr::n(), list("040" = 1)))
  pop$hetu[1] <- "131052-308U"
  pop$email[2] <- "someone@gmail.com"
  expect_error(validate_population(pop, cfg), "hetu passes the checksum[\\s\\S]*reserved domain", perl = TRUE)
})
