# Data dictionary

Conventions:
- Dates are ISO 8601 (`YYYY-MM-DD`).
- Timestamps are RFC 3339 UTC (`YYYY-MM-DDTHH:MM:SSZ`), generated from Europe/Helsinki business hours.
- Booleans are 0/1 in SQLite and `boolean` in PostgreSQL.
- Everything is observed as of `sim_run.cutoff_date`. Later dates are NULL, and open cases are right-censored.
- Names follow NODS / NIEM / ECF vocabulary where it exists, for example `filing_date`, `disposition_code`, `CourtEvent` → `case_event`.

## Reference tables

| Table | Grain | Key columns |
|---|---|---|
| `sim_run` | one row per generated dataset | `seed`, `start_date`, `end_date` (last filing), `cutoff_date` (extraction), `config_yaml` (full config used) |
| `calendar_day` | day | `is_working_day`, `is_holiday`, `holiday_name` (Finnish holidays by default), `capacity_factor` (hearing capacity share: July recess 0,15, Christmas 0,30) |
| `court` | court | `court_level` (ORDINARY / SMALL_CLAIMS), `population`, `judges_establishment`, `clerks_establishment`, `hearing_weekdays_per_judge` |
| `courtroom` | room | `video_enabled` |
| `judge` | judge | `experience_years_at_start`, `hearing_weekdays` (ISO weekdays the judge sits) |
| `judge_absence` | absence episode | `absence_type` (SHORT_ILLNESS / LONG_LEAVE), dates. Long leave triggers reassignment. |
| `counsel` | lawyer / public defender | `counsel_type`. Caseloads are heavy-tailed; see `truth_counsel`. |
| `litigant` | organisational litigant | `is_bulk_filer`: mass / robot filers of summary claims |
| `case_type` | case type | `category` (CRIMINAL / NON_CRIMINAL), `response_days` (statutory), `presumptive_ceiling_days` (Jordan-style) |
| `attribution_code`, `adjournment_reason`, `disposition_type`, `event_type`, `status_code` | code lists | see `config/codes.yaml` |

## Case tables

**`court_case`** has one row per case.
- `case_number` is Finnish-style, e.g. `DC-SOUTH R 24/000123`.
- `filing_channel`: EFILING / PAPER.
- `registration_date` is when the case was registered after the clerk queue.
- `first_appearance_date` is for criminal cases only. Filing to first appearance is the *queue time*.
- `initiating_litigant_id` points to the prosecution service or a bulk filer.
- Complexity proxies: `claim_amount_eur` (civil), `n_charges` (criminal), `n_respondents`.
- `interpreter_language` is ISO 639-1.
- `in_custody_at_filing`.
- `disposition_code` / `disposition_date` are NULL if the case is open.
- `case_status` is the status at the cutoff. `is_open_at_cutoff` marks open cases.

**`case_party`** has one row per party.
- `party_role`: CLAIMANT / RESPONDENT / PROSECUTOR / DEFENDANT.
- `party_type`.
- `counsel_id` is NULL when the party is self-represented.
- `self_represented`, `interpreter_language`, `in_custody_at_filing`.

**`case_assignment`** records judge assignments over time. `assignment_reason` is INITIAL or JUDGE_LONG_ABSENCE (a reassignment that adds familiarisation delay).

**`case_status_history`** is a gap-free status timeline (`valid_from`, `valid_to`). It is the basis for phase durations and process mining. Phases (from `status_code.phase`):

| Phase | Statuses |
|---|---|
| INTAKE | FILED, AWAITING_FIRST_APPEAR |
| SERVICE | SERVICE, AWAITING_RESPONSE |
| PREPARATION | PREPARATION, MOTION_PENDING, STAYED_APPEAL, AWAITING_EXPERT |
| HEARING | AWAITING_HEARING |
| DECISION | DELIBERATION |
| CLOSED | DISPOSED |

**`case_event`** is the docket / register of actions. It has `event_code` (25 codes), `event_date`, `event_ts`, the acting `judge_id`, an optional `hearing_id`, and `detail` (for example the adjournment reason or disposition). It is suitable as an event log for process mining (case id = `case_id`, activity = `event_code`, timestamp = `event_ts`).

**`document`** is derived from filing events. `document_type` is one of INITIATING_DOCUMENT, RESPONSE, EXPERT_REPORT, MOTION, APPEAL_NOTICE, HEARING_MINUTES or DECISION. `page_count` correlates with latent complexity, so it can serve as an observable proxy.

## Process tables (operational delay drivers)

**`hearing`** has one row per booking.
- `scheduled_on_date` is when the hearing was booked.
- `earliest_possible_date` is the booking date plus statutory notice (plus familiarisation after a reassignment).
- `hearing_date`. The gap `hearing_date - earliest_possible_date` is the pure calendar-queue wait.
- `outcome`: HELD / ADJOURNED / VACATED (case resolved first, capacity released) / SCHEDULED (after cutoff).
- `adjournment_reason_code`, `prior_adjournments`, `video_enabled`, `planned_hours`.
- Judge, room and counsel capacity are enforced: no judge is over-booked, and no counsel has two hearings on the same day.

**`procedural_deadline`** covers RESPONSE, EXPERT_REPORT and JUDGMENT_TARGET deadlines.
- `due_date` vs `met_date`; `extended_days`.
- `responsible_attribution`.
- Response deadlines for e-filed cases include the electronic-act extension (Rocha et al.).

**`motion`** holds PROCEDURAL_OBJECTION and INTERLOCUTORY_APPEAL (dilatory measures). An appeal stays the case.

**`expert_report`**: ordered, due and delivered dates. Late reports create THIRD_PARTY delay.

**`custody_period`**: pretrial custody (remand). `end_reason` is RELEASED or DISPOSITION.

**`delay_period`** holds recorded periods of delay with a responsible party (`attribution_code`) and a `cause_code`:

| `cause_code` | Meaning |
|---|---|
| SERVICE_EVASION | failed service attempts |
| RESPONSE_EXTENSION | response deadline extended |
| DISCLOSURE_LATE | prosecution disclosure late |
| PROCEDURAL_MOTION, INTERLOCUTORY_APPEAL | dilatory measures |
| EXPERT_LATE | expert report delivered late |
| ADJ_\<reason\> | adjournment until the rebooked hearing |
| JUDGE_ABSENT_DRAFTING | judge absent when drafting starts |
| JUDGMENT_OVERDUE | judgment past the target date |

Periods still running at the cutoff are truncated, with `is_ongoing_at_cutoff` = 1.

**`court_resource_month`** is a court × month panel.
- `judges_fte` (after absences), `clerks_fte`, `clerk_vacancy_rate`.
- `budget_eur`, `it_budget_share`.
- `efiling_rate` (observed share of e-filed cases), `population`.

## Analytical views

| View | Purpose |
|---|---|
| `v_case_lifecycle` | One row per case: durations (`registration_lag_days`, `queue_time_days`, `service_time_days`, `duration_days`), censoring flag `event_observed`, counts of hearings, adjournments, reassignments, motions and experts, pages, custody days |
| `v_case_status_duration`, `v_case_phase_duration` | Time spent in each status / phase (censored at cutoff) |
| `v_delay_attribution` | Delay days by responsible party, `net_delay_days` (total minus defence/respondent/joint delay), `exceeds_ceiling` |
| `v_hearing_features` | Observable covariates per decided hearing, including counsel's other hearings within ±3 days |
| `v_court_month_kpi`, `v_court_month_indicators` | Incoming, resolved, pending, clearance rate, CEPEJ disposition time, litigation per 100.000, plus the resource panel |
| `v_judge_month_load` | Open cases at month end, hearings held, decisions issued per judge |

## Ground truth (`truth_*`; PostgreSQL schema `ccms_truth`)

Use these tables only to validate models. Never use them as features.

| Table | Contents |
|---|---|
| `truth_parameter` | Every true effect from `config/simulation.yaml → effects` |
| `truth_case` | Latent complexity, the latent path flags (`contested`, `will_settle`, `needs_main_hearing`, `expert_needed`, `early_resolution`), and the realised delay components: `reg_lag_days`, `clerk_load`, `service_days`, `prep_days`, `motion_delay_days`, `expert_days`, `hearing_queue_days`, `adjournment_delay_days`, `deliberation_work_days`, `backlog_at_deliberation`, `trend_factor` |
| `truth_hearing` | True `counsel_load`, `linear_predictor` and `p_adjourn` of each decided hearing |
| `truth_counsel` | Counsel activity weight (the source of heavy-tailed caseloads) |
