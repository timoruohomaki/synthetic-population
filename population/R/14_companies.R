# Step 14 (companies): companies and their contact persons ------------------
#
# Runs after the persons exist. Each company gets one contact person: the
# managing director of an Oy or osuuskunta, the responsible partner of a Ky or
# Ay, or the sole trader of a toiminimi. The company's address is in the same
# postal code area as the contact person's home, so its home municipality
# (kotipaikka) is where the contact person lives.
#
# What you'll learn:
#   - sampling rows without replacement: nobody heads two companies
#   - drawing a random row inside each group (postal code area) without a loop
#   - lookup tables: named vectors turn codes into labels
#   - joining two tables by a key and writing the key back (business_id)

COMPANY_FORMS <- c(oy = "Osakeyhtiö", ky = "Kommandiittiyhtiö", ay = "Avoin yhtiö",
                   osk = "Osuuskunta", tmi = "Yksityinen elinkeinonharjoittaja")
CONTACT_ROLES <- c(oy = "Toimitusjohtaja", ky = "Vastuunalainen yhtiömies",
                   ay = "Vastuunalainen yhtiömies", osk = "Toimitusjohtaja",
                   tmi = "Elinkeinonharjoittaja")

#' Row numbers of `addresses`, one random address per postal code area and
#' municipality (a postal code area can reach into a neighbouring municipality).
address_in_area <- function(addresses, postal_code, municipality_code) {
  area <- paste(addresses$postal_code, addresses$municipality_code)
  ord <- order(area, method = "radix")
  runs <- rle(area[ord])                                 # one run per area
  starts <- cumsum(c(1L, utils::head(runs$lengths, -1)))
  k <- match(paste(postal_code, municipality_code), runs$values)
  if (anyNA(k)) abort("Area(s) missing from the address table: ", toString(unique(postal_code[is.na(k)])))
  ord[starts[k] + floor(stats::runif(length(k)) * runs$lengths[k])]
}

#' Read the TOL 2008 sections (main lines of business) with weights.
read_business_lines <- function(cfg) {
  path <- file.path(cfg$root, "reference", "tol2008_sections.csv")
  if (!file.exists(path)) abort("Missing reference file ", path)
  readr::read_delim(path, delim = ";", col_types = "cccd", progress = FALSE)
}

#' Draw companies for the persons in `pop`; returns the companies table.
draw_companies <- function(cfg, pop, addresses) {
  cc <- cfg$companies
  n <- round(nrow(pop) * cc$per_1000_persons / 1000)
  ages <- unlist(cc$contact_age)
  eligible <- which(pop$age >= ages[1] & pop$age <= ages[2])
  if (n < 1) abort("No companies: increase companies.per_1000_persons or the number of persons")
  if (n > length(eligible)) abort("Only ", fmt_int(length(eligible)), " persons can be contacts for ", fmt_int(n), " companies")
  contact <- pop[eligible[sample.int(length(eligible), n)], ]   # without replacement

  form_weights <- unlist(cc$forms)
  form <- sample(names(form_weights), n, replace = TRUE, prob = form_weights)
  at_home <- form == "tmi" & stats::runif(n) < cc$sole_trader_home_share
  site <- addresses[address_in_area(addresses, contact$postal_code, contact$municipality_code), ]
  site[at_home, ] <- contact[at_home, names(site)]               # works from home

  adult <- years_before(contact$birth_date, -ages[1])            # 18th birthday
  earliest <- pmax(as.Date(cc$first_registration), adult)
  span <- as.integer(cfg$run$reference_date - earliest)
  registered <- earliest + floor(stats::runif(n) * (span + 1))
  business_id <- sort(make_business_id(n, cc$business_id_first_digit))[rank(registered, ties.method = "first")]

  lines <- read_business_lines(cfg)
  line <- sample.int(nrow(lines), n, replace = TRUE, prob = lines$weight)
  words <- setdiff(read_company_words(cfg), unlist(cc$excluded_words))
  name <- make_company_names(form, words, contact$first_name, contact$last_name)
  slug <- company_slug(name)
  slug <- paste0(slug, ifelse(rank_within(slug) > 1, rank_within(slug), ""))
  in_register <- function(p) stats::runif(n) < p
  reg <- cc$registers

  tibble::tibble(
    business_id = business_id, company_name = name, company_form = unname(COMPANY_FORMS[form]),
    registration_date = registered, main_business_line = lines$section[line],
    main_business_line_fi = lines$name_fi[line],
    street_address = site$street_address, postal_code = site$postal_code,
    post_office = site$post_office, municipality_code = site$municipality_code,
    home_municipality = site$municipality, region = site$region,
    website = paste0("www.", slug, cc$domain_suffix), email = paste0("info@", slug, cc$domain_suffix),
    trade_register = form != "tmi" | in_register(reg$trade_register_tmi),
    prepayment_register = in_register(reg$prepayment),
    vat_register = in_register(reg$vat),
    employer_register = in_register(reg$employer),
    vat_number = ifelse(vat_register, vat_number(business_id), NA_character_),
    contact_person_id = contact$person_id, contact_role = unname(CONTACT_ROLES[form]),
    contact_first_name = contact$first_name, contact_last_name = contact$last_name
  ) |> dplyr::arrange(registration_date)
}

#' Sole traders: copy the Business ID to the person's row.
add_business_ids <- function(pop, companies) {
  tmi <- companies$company_form == COMPANY_FORMS[["tmi"]]
  idx <- match(pop$person_id, companies$contact_person_id[tmi])
  pop$business_id <- companies$business_id[tmi][idx]
  pop
}
