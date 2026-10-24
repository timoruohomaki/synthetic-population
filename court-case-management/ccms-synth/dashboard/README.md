# ccms-synth dashboard (Shiny mockup)

An interactive mockup of a court caseflow management dashboard on top of the ccms-synth database. It is a starting point for defining KPIs and metrics. Every view is a pure KPI function (`R/kpi_*.R`) plus a thin Shiny module (`R/mod_*.R`), so metrics can be reused outside Shiny, tested, and replaced one at a time.

The report set follows the *Trial Court Model Output Reports* of the NCSC **Court Case Management Information Systems Manual** (National Center for State Courts, NCJRS microfiche). It is extended with the caseflow-delay views the ccms-synth data makes possible: phase decomposition, delay attribution, adjournments and the calendar queue.

## Run

```r
# from the ccms-synth folder (or open the .Rproj and run this in the console)
shiny::runApp("dashboard")
```

The database is located through these, in order:

1. `CCMS_DB` (environment variable)
2. `../output/ccms_synth.sqlite`
3. `../../output/ccms_synth.sqlite`

The paths are relative to `dashboard/`. If none is found, the app shows an error page with instructions instead of crashing.

Packages: shiny, bslib, plotly, DT, data.table, DBI, RSQLite, yaml (minimum versions are checked at start-up).

## Views and KPIs

The sidebar holds the global filters:

- court
- case category and case type
- reporting period
- as-of date for the pending caseload

The as-of date defaults to the last filing date. After that date the synthetic data contain run-off only, with no new filings.

| Tab | View | NCSC model report | KPI function |
|---|---|---|---|
| Overview | Incoming, resolved, clearance rate, pending, CEPEJ disposition time, share over time standard | 7, 9, 10 | `headline_kpis()` |
| | Incoming vs. resolved per month; pending at month end per court | 7, 9 | `monthly_flow()` |
| Caseload inventory | Pending at start / filed / disposed / pending at end, change, clearance, by type or court × type (CSV export) | 7, 9, 10 | `caseload_inventory()` |
| | Share of filings by case type | 8 | `caseload_inventory()` |
| | Change vs. preceding period of equal length | 14 | `period_comparison()` |
| Dispositions | Manner of disposition per month (number / share) | 11, 17 | `disposition_mix()` |
| | Disposed within time standard | performance measure | `standard_compliance()` |
| | Age at disposition by type × manner (mean, median, p90) | 21, 22 | `age_at_disposition()` |
| Pending & exceptions | Age of pending cases in buckets, median age | 20 | `age_of_pending()` |
| | Status of pending cases (next step awaited) | 23, 26 | `status_at()` |
| | Exception report: cases over their time standard, with status, next hearing and judge (CSV export) | 25, 27 | `exception_list()` |
| Delay & caseflow | Mean days per phase for disposed cases | Fig. 10 | `phase_profile()` |
| | Delay days by responsible party | Jordan-style attribution | `delay_attribution()` |
| | Adjournment rate and hearing-slot wait per month | Fig. 10 | `hearing_monthly()` |
| | Adjournment reasons; median / p90 intervals between events | Fig. 10 | `adjournment_reasons()`, `event_intervals()` |
| Judges & resources | Open cases, hearings held, decisions per judge | 13 | `judge_caseload()` |
| | Judge FTE, clerk FTE, e-filing rate per court-month | resource panel | `resource_panel()` |
| Projection | Pending caseload: actual and linear projection with prediction interval | 19 | `project_pending()` |

## Configuration (`config.yaml`)

- `time_standards`: days per case type, used in the exception report and the compliance view. The defaults are illustrative; replace them with your jurisdiction's standards.
- `age_breaks`: bucket bounds for the age views.
- `projection`: months fitted, months projected, interval level.
- `palette`: a validated categorical order (colours follow the entity, never its rank), a sequential blue ramp for ordinal age buckets, and reserved status colours. Status colours are always shown with an icon and a label.

## Conventions

- **Numbers** use `.` as the thousands separator and `,` as the decimal mark, in tables, tiles, axes and tooltips (plotly `separators = ",."`).
- **Dates** are ISO 8601 (`YYYY-MM-DD`; month axes `YYYY-MM`).
- **CSV downloads** use `;` as the separator and `,` as the decimal mark.

## Tests

```bash
Rscript dashboard/tests/run_tests.R   # from the ccms-synth folder
```

| File | What it checks |
|---|---|
| `test_kpi.R` | KPI functions on a hand-checkable fixture: inventory balance, monthly flow, age buckets, exception list, compliance, projection |
| `test_app.R` | Every module's outputs render without error against the generated database (`shiny::testServer`) |

## Extending

To add a KPI:

1. Write a pure function in `R/kpi_*.R` that takes `cases` and the period / as-of date.
2. Add a test with a fixture.
3. Render it in a module.

Keep each file under about 100 lines. To add a new tab, create `mod_x.R` with `x_ui()` / `x_server(id, d, f, cfg)` and register both in `app.R`.
