# Synthetic Finnish population

Generates realistic but fictional people - names, birth dates, addresses,
personal identity codes (henkilötunnus), bank accounts, e-mail addresses and
phone numbers - by combining Finnish open data at random. A million persons
take about a minute.

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
pop <- generate_population(n = 10000)                 # writes output/ files too
pop <- generate_population(n = 1e6, hetu_mode = "month_offset")
```

Or from a terminal in this folder:

```sh
Rscript generate_population.R --n 1000000 --seed 42 --hetu-mode month_offset
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
| Phone | Random mobile number (040, 044, 045, 050) | **Yes** - Finland has no fictional number range. Never call or text them. |

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
region_code, region, email, phone, iban`. Every run is validated (16 checks)
before anything is written. The same seed and source files always give the same people.

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
| `R/11_pipeline.R` | Everything | composing functions, `set.seed()`, `mutate()` |

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
- **Databases**: write the table to SQLite (`DBI` + `RSQLite`) or PostgreSQL
  and query it with SQL.

## Tests

`Rscript tests/run_tests.R` - checksums against official examples, uniqueness,
the pipeline on small in-memory tables, and the file readers when `data/` has the source files.

## Other folders

- `extras/company-names/`: an older experiment that generates company names
  from Latin words; not part of the pipeline.
- `reference/`: small lookup tables that ship with the repository.
