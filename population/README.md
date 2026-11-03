# Synthetic Finnish population

Generates realistic but fictional people - names, birth dates, addresses,
personal identity codes (henkilötunnus), bank accounts, e-mail addresses and
phone numbers - by combining Finnish open data at random. Optionally it also
creates companies run by those people. A million persons take about a minute.

The project has two goals:

1. **Test data**: large data sets (1 000 000+ rows) that look and behave like
   real population data, with identifiers that pass the official checksums.
2. **Learning R**: every step is a common data task - reading Excel, CSV and
   fixed-width files, cleaning text, joining tables, weighted sampling,
   working with dates, vectorised code, validation and saving. Each file in
   `R/` starts with a *What you'll learn* list.

## Quick start

1. Install R packages: `install.packages(c("dplyr", "readr", "readxl", "tibble", "yaml", "testthat"))`
2. Download the source files into `data/` - see [data/README.md](data/README.md).
3. Open `synthetic-population.Rproj` in RStudio and run:

```r
source("generate_population.R")
res <- generate_population(n = 10000)                 # writes output/ files too
res <- generate_population(n = 1e6, hetu_mode = "month_offset")
res <- generate_population(n = 1e5, companies = TRUE)  # persons + companies
View(res$persons); View(res$companies)
```

Or from a terminal in this folder:

```sh
Rscript generate_population.R --n 1000000 --seed 42 --hetu-mode month_offset
Rscript generate_population.R --n 100000 --companies true
```

To learn step by step, open [walkthrough.R](walkthrough.R) and run it one line at a time.
All settings are in [config.yaml](config.yaml).

## How fictional is the data?

| Field | Method | Can it match a real person? |
|-------|--------|-----------------------------|
| Names | Weighted by how common they are | Yes - real names, random combinations |
| Address | A real residential building address | Yes - real buildings |
| Henkilötunnus, `test_series` (default) | Real birth date, individual number 900-999 | No - 900-999 is reserved for test data |
| Henkilötunnus, `month_offset` | Month + 12 (months 13-24), number 002-899 | No - no real month is above 12 |
| IBAN | Bank code `9`, valid Luhn and IBAN check digits | No - no Finnish bank uses code 9 |
| E-mail | `first.last@example.com/.org/.net` | No - domains reserved by RFC 2606 |
| Phone | Mobile area codes 047 and 048 | No, for now - these codes are in [Traficom's number reserve](https://www.traficom.fi/files/media/regulation/M_32_U_2023.pdf) and not granted to any operator ([granted codes](https://eservices.traficom.fi/LicensesServices/Forms/NureMatkaviestinverkkojenSuuntanumerot.aspx?langid=fi)). Traficom can grant them later, so check the list before relying on it. |
| Business ID (Y-tunnus) | Starts with `9`, valid check digit | Very unlikely - IDs in use start with 0-3 (2026), but no range is officially reserved |
| Company name | Latin words, or the owner's name | Possible, especially sole traders named after the person |
| Company web and e-mail | `www.<name>.example`, `info@<name>.example` | No - `.example` is reserved by RFC 2606 |

`month_offset` is the method of the original
[LinkedIn article](https://www.linkedin.com/pulse/introduction-r-creating-large-synthetic-data-sets-ehr-timo-ruohom%C3%A4ki-ngqjf/):
the checksum is correct, but date checks reject the code. `test_series` codes
pass every check, including the date, which suits testing systems that
validate dates. Only 50 test numbers exist per sex per day, so above about
1,3 million persons use `month_offset` (449 numbers per day); the generator
stops with a clear message if a day runs out of numbers.

## Output

`output/population_<n>_<date>.csv` (semicolon separated, UTF-8 with BOM, opens
in Excel with ä, ö and å intact) and `.rds` (for R; keeps Dates as Dates).
Add `"parquet"` to `run.formats` when the arrow package is installed.

Columns: `person_id, hetu, first_name, given_names, last_name, sex, birth_date,
age, street_address, postal_code, post_office, municipality_code, municipality,
region_code, region, email, phone, iban, business_id`. `business_id` is filled
only for sole traders when companies are generated. Every run is validated
(17 checks) before anything is written. The same seed and source files always
give the same people.

## Companies (optional)

Turn on with `companies.enabled: true` in config.yaml, `companies = TRUE` in R
or `--companies true`. It runs last, after the persons are ready:

- `per_1000_persons` companies (default 50 per 1000 persons) in the forms
  osakeyhtiö, toiminimi, kommandiittiyhtiö, avoin yhtiö and osuuskunta.
- Each company has one **contact person** from the population, aged 18-74,
  and nobody runs two companies: the managing director (toimitusjohtaja) of
  an Oy or osuuskunta, the responsible partner of a Ky or Ay, or the sole
  trader (elinkeinonharjoittaja) of a toiminimi.
- The company's address is in the **same postal code area and municipality
  as the contact person's home**, so its home municipality (kotipaikka) is
  where the contact lives. Most sole traders (70 %) work from home.
- Like the YTJ register: Business ID and VAT number, name, company form,
  registration date (older companies have smaller IDs), main line of business
  (TOL 2008 section), address, web site and e-mail, and the trade,
  prepayment, VAT and employer registers.
- Sole traders' Business IDs are also written to their person row.

Output: `output/companies_<n>_<date>.csv/.rds`, linked to the persons by
`contact_person_id` = `person_id`. 15 more checks run before saving.

Names are built from the Latin word list in `data/latin_words*.csv` (or the
shared copy in `reference/`); `companies.excluded_words` keeps unfortunate
words such as *scelus* (crime) out. The company form shares, register
probabilities and the equal weights of the business lines in
`reference/tol2008_sections.csv` are illustrative defaults, not statistics:
replace them with figures from Statistics Finland's enterprise statistics.

## Learning path

| File | Task | R you'll practise |
|------|------|-------------------|
| `R/00_utils.R` | Helpers | functions, `stop()`, `Sys.glob()`, safe file writing |
| `R/01_config.R` | Settings | YAML, nested lists, `modifyList()`, input checks |
| `R/02_read_names.R` | Name lists | `readxl`, `filter()`, `arrange()` |
| `R/03_read_postcodes.R` | Postcodes | `read_fwf()`, encodings (latin1), `trimws()` |
| `R/04_read_addresses.R` | 2 million addresses | `read_delim()` with `col_select`, joins, `if_else()`, caching with RDS |
| `R/05_people.R` | Persons | `sample(prob = )`, Dates, vectorised code |
| `R/06_hetu.R` | Henkilötunnus | `sprintf()`, `substr()`, modulo, numbering within groups |
| `R/07_iban.R` | Bank accounts | `%/%` and `%%`, Luhn and mod 97 checksums, large numbers in doubles |
| `R/08_contact.R` | E-mail, phone | text cleaning, regular expressions, uniqueness |
| `R/09_validate.R` | Checks | `anyNA()`, `anyDuplicated()`, reporting all failures |
| `R/10_output.R` | Saving | `write_excel_csv2()`, `saveRDS()`, optional packages |
| `R/12_business_id.R` | Business IDs | weighted sums with `%*%`, redrawing invalid values |
| `R/13_company_names.R` | Company names | cleaning a word list, string building, uniqueness |
| `R/14_companies.R` | Companies | sampling without replacement, a random row per group, lookup tables |
| `R/15_validate_companies.R` | Checks across tables | `match()`, `%in%`, relations between tables |
| `R/16_pipeline.R` | Everything | composing functions, `set.seed()`, `mutate()`, optional steps |
| `R/17_hobbies.R` | Enriching (lesson) | weighted `sample()`, Zipf weights, one-to-many long tables |

## Lessons

Optional lessons in `lessons/` build on a generated population (the newest
`output/population_*.rds`, or a fresh 100.000 persons) and are run line by line:

- [`lessons/enrich_hobbies.R`](lessons/enrich_hobbies.R) - give each person
  0-3 hobbies from `reference/hobbies.xlsx`. Shows that `sample(..., prob = )`
  handles a million weighted draws in milliseconds, how the cumulative-weights
  method behind it works, what to do when the list has no popularity figures
  (Zipf's law as a written-down assumption; settings under `hobbies:` in
  config.yaml), and why several values per person belong in a long table
  (`person_id`, `hobby`) rather than a text column.

## Exercises

- **Regional balance**: addresses are drawn uniformly over buildings, so
  Uusimaa gets about 16 % of the people instead of about 32 %. Weight the
  draw by municipality population (Statistics Finland table 11ra).
- **Households**: give people who share an address the same last name; add
  children to adults aged 25-50.
- **Names by generation**: the name statistics cover the living population,
  so a 5-year-old can be called Timo. How would you make names depend on
  birth year?
- **Age pyramid** with ggplot2; **counts per region** with `count()` and a map.
- **Realistic companies**: weight the business lines and company forms with
  Statistics Finland's enterprise counts; give an Oy several board members.
- **Databases**: write the tables to SQLite (`DBI` + `RSQLite`) or PostgreSQL
  and query it with SQL.

## Tests

`Rscript tests/run_tests.R` - checksums against official examples, uniqueness,
the pipeline on small in-memory tables, and the file readers when `data/` has the source files.

## Other folders

- `extras/company-names/`: `extract_latin_words.R` rebuilds the Latin word
  list from a public dictionary page (needs the rvest package).
- `reference/`: datasets that ship with the repository and are meant to be
  shared - region codes, TOL 2008 sections, the Latin word list and the hobby
  list. A file with the same name pattern in `data/` overrides the shared one,
  so you can try your own version without changing the repository.
