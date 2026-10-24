# ccms-synth: a synthetic court case management dataset

ccms-synth generates a realistic **court case management system (CCMS)** dataset for building and validating analytical models of the judicial process. In particular it is meant for models that explain **why cases are delayed**.

The output is an operational database with these parts:

- **Case registry and parties:** cases, parties, counsel, judge assignments.
- **Docket:** status history, docket events, documents.
- **Hearings:** bookings with outcomes, adjournments and reasons.
- **Process records:** deadlines, motions, expert reports, pretrial custody.
- **Delay attribution:** recorded delay periods with the responsible party.
- **Resource panel:** a court × month table of staffing and budget.

Every delay is produced by an explicit mechanism with **known true parameters**, which are stored in `truth_*` tables. You can therefore check whether a model recovers the real drivers.

The design draws on:

- **Clarke & Metzler (2025)**, *Estimating the Delay of Criminal Trials: Evidence From Canada*: queue vs. service time, zero-inflated quick resolutions, congestion and remand, non-stationary trends, and Jordan-style ceilings and delay attribution.
- **Rocha et al. (2026)**, *The Impact of CCMS on Judicial Efficiency*, IJCA 16(3): e-filing effects confined to specific stages, fixed procedural deadlines, dilatory measures, robot mass filing, the decision-phase bottleneck, and a court resource panel.
- Naming from **NCSC NODS**, **OASIS ECF / NIEM Justice** and **CEPEJ GOJUST** indicators (clearance rate, disposition time).

## Quick start

```bash
# R >= 4.1 with DBI, RSQLite, data.table, yaml (testthat, survival for tests/analysis)
Rscript run.R --overwrite                 # -> output/ccms_synth.sqlite + output/csv/*.csv
Rscript run.R --overwrite --postgres      # also output/postgres/{csv/,load.sql}
cd output/postgres && psql -d mydb -f load.sql   # schemas ccms + ccms_truth (PostgreSQL >= 13)

Rscript tests/run_tests.R                 # unit + end-to-end invariants
Rscript analysis/01_adjournment_model.R   # recover adjournment effects
Rscript analysis/02_durations.R           # survival, phases, drafting bottleneck
Rscript analysis/03_court_panel.R         # Rocha-style panel + Little's Law
```

### Options

| Option | Default | Description |
|---|---|---|
| `--config` | `config/simulation.yaml` | Simulation configuration |
| `--codes` | `config/codes.yaml` | Code tables and adjournment reasons |
| `--out` | `output` | Output directory |
| `--cases N` | — | Cases per year |
| `--seed N` | — | Random seed |
| `--overwrite` | off | Replace an existing database |
| `--no-csv` | off | Skip the CSV export |
| `--postgres` | off | Also write the PostgreSQL bundle |

A default run (about 21.000 cases over 2023–2025, cutoff 2026-06-30) takes about 35 s.

Exit codes:

| Code | Meaning |
|---|---|
| 0 | OK |
| 1 | Other error |
| 2 | Configuration error |
| 3 | I/O error |

## Output formats

| Output | Format |
|---|---|
| SQLite | `output/ccms_synth.sqlite`. Foreign keys, CHECK constraints (ISO 8601 dates are validated with `date(x) = x`) and 8 analytical views. Built under a temporary name and renamed only after the FK, integrity and row-count checks pass. |
| EU CSV | `output/csv/`: `;` separator, `,` decimal mark, UTF-8, ISO 8601 dates, RFC 3339 UTC timestamps |
| PostgreSQL | `output/postgres/`: a self-contained bundle (`ddl/`, machine CSV with `,` / `.`, `load.sql`) that loads in one transaction. Ground truth goes to schema `ccms_truth`, so analysts can be granted `ccms` only. |

## Project layout

```
config/         simulation.yaml (all true effects), codes.yaml (code lists, adjournment reasons)
R/              generator; every file under ~100 lines
  util_*.R      logging, classed errors, atomic file I/O, EU CSV
  config.R      load + validate configuration
  calendar.R    Finnish holidays, recess capacity, working-day arithmetic
  gen_*.R       courts, judges, absences, counsel, resource months, case arrivals
  sim_*.R       event engine, booking engine, intake / prep / hearing / decision handlers
  build_*.R     censoring at cutoff, ISO/RFC 3339 formatting, output tables
  db_write.R    SQLite schema + transactional load + verification
  export_postgres.R, pipeline.R
sql/sqlite/     001-004 tables, 005-006 views
sql/postgres/   same model in PostgreSQL types (date, timestamptz, boolean, numeric)
analysis/       example models that check recovery of the true effects
tests/          testthat: unit tests + end-to-end invariants (FK, ordering, capacity, censoring)
docs/           data_dictionary.md, simulation_model.md, er_diagram.mmd (Mermaid)
```

## Using it for a delay model

1. **Case level.** `v_case_lifecycle` (durations with a censoring flag) joined with `v_case_phase_duration` (where the time went) and `v_delay_attribution` (who caused it).
2. **Event level.** `v_hearing_features` for adjournment models; `case_event` as a process-mining event log.
3. **Court level.** `v_court_month_indicators` for clearance rate, disposition time and pending cases, with resource controls.
4. **Validation.** Compare estimates with `truth_parameter`, `truth_case` and `truth_hearing`. Exclude `truth_*` from features.

To change the scenario, edit `config/simulation.yaml`: court staffing, sitting days, adjournment coefficients, e-filing adoption, bulk-filer surges, trends. Then regenerate. For example, giving DC-SOUTH a third sitting day cuts its mean main-hearing wait from about 107 to 25 days (default seed).

## Dependencies

| Package | Role | Maintainer |
|---|---|---|
| DBI | database interface | r-dbi |
| RSQLite | SQLite driver | r-dbi |
| data.table | data handling, in-place state updates | data.table team |
| yaml | configuration | R yaml maintainers |
| testthat | tests | r-lib |
| survival | analysis only; recommended package shipped with R | — |

All are on CRAN and actively maintained. PostgreSQL loading uses only `psql`, so no R driver is needed.
