company_fixture <- function(n_persons = 3000, per_1000 = 100) {
  set.seed(4)
  cfg <- test_config(run = list(n_persons = n_persons),
                     companies = list(enabled = TRUE, per_1000_persons = per_1000))
  inp <- fake_inputs()
  inp$addresses$postal_code <- rep(c("00100", "00200"), length.out = nrow(inp$addresses))
  inp$addresses$municipality_code <- rep(c("091", "049"), length.out = nrow(inp$addresses))
  pop <- draw_people(cfg, inp$names, inp$addresses) |>
    dplyr::mutate(hetu = make_hetu(birth_date, sex), iban = make_iban(dplyr::n()),
                  email = make_email(first_name, last_name, "example.com"),
                  phone = make_phone(dplyr::n(), list("040" = 1)), business_id = NA_character_) |>
    dplyr::select(dplyr::all_of(POPULATION_COLUMNS))
  list(cfg = cfg, pop = pop, addresses = inp$addresses)
}

test_that("companies are valid and linked to their contact persons", {
  skip_if(length(Sys.glob(file.path(root, "extras", "company-names", "latin_words*.csv"))) == 0)
  f <- company_fixture()
  firms <- draw_companies(f$cfg, f$pop, f$addresses)
  pop <- add_business_ids(f$pop, firms)
  expect_equal(nrow(firms), 300)
  expect_silent(validate_companies(firms, pop, f$cfg) |> suppressMessages())
  tmi <- firms$company_form == COMPANY_FORMS[["tmi"]]
  expect_true(all(firms$contact_role[!tmi] %in% c("Toimitusjohtaja", "Vastuunalainen yhtiömies")))
  expect_true(all(endsWith(firms$company_name[firms$company_form == "Osakeyhtiö"], " Oy")))
})

test_that("a company in another area than its contact fails validation", {
  skip_if(length(Sys.glob(file.path(root, "extras", "company-names", "latin_words*.csv"))) == 0)
  f <- company_fixture()
  firms <- draw_companies(f$cfg, f$pop, f$addresses)
  pop <- add_business_ids(f$pop, firms)
  firms$postal_code[1] <- "99999"
  expect_error(validate_companies(firms, pop, f$cfg), "postal code")
})

test_that("random addresses stay inside the requested area", {
  addr <- tibble::tibble(postal_code = c("1", "1", "2", "2", "2"), municipality_code = c("a", "b", "a", "a", "a"))
  idx <- address_in_area(addr, rep(c("1", "2"), 50), rep("a", 100))
  expect_true(all(addr$postal_code[idx] == rep(c("1", "2"), 50)))
  expect_true(all(addr$municipality_code[idx] == "a"))
  expect_error(address_in_area(addr, "3", "a"), "missing")
})

test_that("company names are unique and follow the forms", {
  set.seed(2)
  words <- c("lumen", "ferrum", "aurora")
  nm <- make_company_names(rep(c("oy", "osk", "tmi", "ky"), 25), words, rep("Matti", 100), rep("Virtanen", 100))
  expect_false(anyDuplicated(tolower(nm)) > 0)
  expect_true(all(grepl("Oy$|^Osuuskunta|Virtanen|Ky$", nm)))
  expect_equal(company_slug("Lumen Vitae Oy"), "lumenvitae")
})
