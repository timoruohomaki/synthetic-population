# Simulation model

The generator is a **day-stepped discrete-event simulation** with finite, shared resources. Delay is not drawn from a distribution. It *emerges* from four sources:

- **Queues.** Clerks, the first-appearance docket, judge and courtroom hours, counsel calendars, and each judge's judgment-drafting backlog.
- **Fixed statutory periods.** Response deadlines and notice periods.
- **Party behaviour.** Evasion, extensions, motions, appeals and adjournments.
- **Trends.** Rising filings and lengthening service times.

All causal parameters are in `config/simulation.yaml` (`effects`) and `config/codes.yaml` (adjournment reasons). They are copied to `truth_parameter`.

## Case flow

```
FILED --clerk queue--> REGISTERED --+-- criminal --> AWAITING_FIRST_APPEAR --docket queue--> FIRST_APPEARANCE
                                    |                     (early plea / withdrawal -> DISPOSED same day)
                                    +-- civil ----> SERVICE (failed attempts) -> AWAITING_RESPONSE
                                                         (no response -> default judgment)
  -> PREPARATION [-> preparatory hearing] [-> late disclosure] [-> MOTION_PENDING -> STAYED_APPEAL]
     [-> AWAITING_EXPERT] -> AWAITING_HEARING --judge/room/counsel calendar--> HEARING
        HEARING --adjourned (reason, attribution)--> re-request + rebooking queue
        HEARING --held--> DELIBERATION (judge drafting queue) -> DISPOSED
     settlement may happen between booking and the main hearing (hearing VACATED, capacity released)
```

## Delay drivers and their true form

| Driver | Mechanism (true model) | Literature basis |
|---|---|---|
| Clerk workload | `reg_lag = base(channel) * (1 + 1,20 * max(0, load - 1)) * noise`, where `load` = filings in the last 30 days / (clerk FTE × capacity). Clerk FTE follows a vacancy random walk. | Rocha et al.: resources (clerks, judges, budget) |
| Bulk / robot filing | 3 bulk filers carry 55 % of summary claims, with random 3× surge months that raise clerk load for everyone | Rocha et al.: mass filing by software robots |
| E-filing | Faster registration (1 vs 6 days) and service (2 vs 12 days), but a +10 day electronic-act extension on response deadlines. No effect on hearing or drafting queues. | Rocha et al.: IT helps specific stages, not overall efficiency |
| Queue time (criminal) | First-appearance docket with fixed slots (12 per day, Tue/Thu); custody cases may be booked earlier | Clarke & Metzler: queue time = charge → first appearance |
| Zero-inflated resolution | Guilty plea or withdrawal at first appearance (one-day cases) | Clarke & Metzler: excess one-day resolutions |
| Statutory periods | Response days by case type; minimum notice before hearings (14 / 21 days, 5 days in custody) | Rocha et al.: procedural deadlines are non-compressible |
| Service evasion | Up to 3 failed attempts, 30 days apart; less likely when the respondent has counsel | — |
| Dilatory motions | `logit p = -3,0 + 0,8 log(cx) + 0,9 counsel - 1,0 bulk`; 35 % lead to an interlocutory appeal that stays the case | Rocha et al.: dilatory measures and appeals |
| Expert reports | Ordered at a 90-day due date; 30 % late with exponential lateness | — |
| Hearing capacity | Judge sitting days × hours × calendar factor (summer recess, Christmas), absences, courtroom hours, and no same-day double-booking of counsel | Queueing view (Clarke & Metzler) |
| Adjournments | `logit p = -1,90 + 0,50 log(cx) + 0,80 interp + 0,55 self_rep + 0,25 counsel_load - 0,60 custody - 0,45 video + 0,30 extra_def + 0,35 prior_adj - 0,30 prep` | Delay attribution (Jordan framework) |
| Adjournment reason | Weighted by drivers (counsel load, interpreter, expert, complexity). Each reason has an attribution and an extra lead time. | Defence / prosecution / court / third-party split |
| Judge absence | Short illness and long leave; leave of 30+ days left at booking triggers reassignment with 14 days' familiarisation | — |
| Drafting bottleneck | `work = base × cx^0,8 × (1 + 0,035 × pending judgments) × exp(-0,12 × (experience - 15) / 10) × trend × noise`, in weighted working days | Rocha et al.: the decision phase remains the bottleneck |
| Trends | Arrivals +5 %/yr; preparation and drafting +6 %/yr | Clarke & Metzler: rising, non-stationary service times |
| Pretrial custody | Remand at filing for some criminal cases; 45 % released at first appearance | Clarke & Metzler: congestion and remand population |

## Calibrated scenario (default config)

- **DC-NORTH:** 11 judges, 3 sitting days each. Hearing queues are short, but the first-appearance docket is the bottleneck (criminal queue time p90 ≈ 75 days).
- **DC-SOUTH:** 8 judges, 2 sitting days each. Hearing demand exceeds capacity, so the median main-hearing wait is about 3 months and pending cases double over 2023–2025.
- **SC-EAST:** a small-claims court with spare capacity.

The default run produces about 21.000 cases, 176.000 docket events, 11.600 hearing bookings (about 17 % of decided hearings adjourned) and 9.200 attributed delay periods. About 5 % of cases are open at the cutoff.

## Validation results (default seed)

- **`analysis/01_adjournment_model.R`:** the oracle logistic model recovers all 10 adjournment coefficients within about 2 SE. The observable model shows attenuation from proxies; latent and observed counsel load correlate at about 0,86.
- **`analysis/02_durations.R`:** `nls` recovers drafting parameters (complexity exponent 0,81 vs 0,80; backlog 0,0355 vs 0,035; experience -0,110 vs -0,120). It also fits a Cox model with censoring and decomposes phases by court.
- **`analysis/03_court_panel.R`:** a Rocha-style fixed-effects panel shows *spurious* e-filing coefficients. This is caused by within-court trends, a useful identification caveat. A Little's Law check (L = λW) holds within about 5 % for the stable courts.

## Limitations

- Parameters are illustrative. They are not calibrated to any real court system.
- One judge per case; no panels or lay judges.
- Appeals to higher instances are not modelled beyond interlocutory stays.
- Hearings are single-day.
- Settlement timing is uniform within the booking window.
- Counsel conflicts are checked within a court only. Counsel are court-local.
