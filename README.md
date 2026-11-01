# Synthetic Population
Creating models to generate test data with the characteristics of live population

## Subprojects

- [`population`](population/README.md): synthetic Finnish persons (names, addresses, henkilötunnus,
  IBAN, e-mail, phone) and optionally companies with Business IDs and contact persons, combined at random from open data, with checksums that validate. Scales to
  millions of rows and doubles as a step-by-step R/RStudio learning project. Source data and output
  are not committed; see [`population/data/README.md`](population/data/README.md).
- [`court-case-management/ccms-synth`](court-case-management/ccms-synth/README.md): synthetic court case
  management (CCMS) data with operational delay drivers and ground-truth parameters, for building and
  validating analytical models of the judicial process. Generated data (`output/`) is not committed;
  regenerate it with `Rscript run.R` inside the project folder.
- [`pseudonymizer`](pseudonymizer/README.md): GDPR pseudonymization helpers for R (hashing,
  encryption and random replacement of identifiers).

## Guides

- [Packaging R code](guides/r-packaging.md)
