# Overnight plan (2026-11-15)

The user asked, before going to sleep, for two things in order:

1. List every planned feature that is not built yet, then build them.
2. Then check the built screens against the latest design and fix what differs.

The lists are drawn from these sources:
- the design session's backlog, build steps 6b, 6c and 6d;
- its AHEAD-OF-BUILD notes;
- the M2 screens spec (layouts up to v48);
- the morning's status check.

Items marked "Later" in the backlog are not started: sync, diary, drawings, school calendar import, the N-list after the morning, and the parked "Coming up" and "Ended" ideas.

## Phase A: planned, not built yet

Build in this order. One PR each, squash-merged into `develop`. For each:
- run only the test targets the change touches;
- check it on the iPad.

| # | Item | Boards / spec | Notes |
|---|---|---|---|
| A1 | G4 second part. **Terms:** the S2 term rows (MOE calendar switch, term list) inside the G4 card. **School's Bring:** F2, checked in the before-school window. **This day:** School's hours for one date. **The School slice on the clock** opens G4. | G4, F2, spec "G4" | G4 first part is merged (PR #82). |
| A2 | Settings Family tab. **"This iPad" switches.** **"Children" rows** (face, name, age · place, › to that kid's tab). **"+ Add a child"**: the S1 kid card for one new kid, up to 4. **Foot:** "School lists · {date}", Data sources. | G6f (v44) | |
| A3 | Change school. **Pick a school:** the S2 search. **"Starts on":** Next term or a date. **Split:** the School item splits on that date, and terms, hours and the trip refill. **Pending change:** can be changed or cancelled until its date. | G7, spec "change school" | School › on G4 opens it. |
| A4 | C3k leftovers. **Typing:** tighter rows; the side column keeps only the preview heading; Return on Name hides the keyboard. **Time fields:** the field being changed turns pickBlue (v43). | C3k, v43 | |
| A5 | Skip a slice this day. **On the clock:** the slice stays at 30 % with its picture at 35 %. **Hub:** "{name} / Skipped / this day". **Card:** "Bring back". | G1g (v48) | |
| A6 | Home before an outing. **Kid A row:** "Leave in {n} min" with the way picture. **Main button:** "Before {item} →" opens A2 for that outing. **Hub:** the slot now. | A1b (v48) | Check what is already built first. |
| A7 | Second bus choice. **Our buses:** 1st and 2nd tags on the bus pills, the "Ride 2nd" row. **Change-buses screen:** C2c, the 2nd choice that changes buses. **Morning:** the 2nd bus on A2. | C2, C2c, A2 | Largest item, so it goes last in phase A. |
| A8 | Follow-ups from earlier PRs. Check first, then build if missing. **Terms:** MOE term dates fill the holiday list (and international `termDates`). **Row labels:** caption bold on one line on every grown-up form. | backlog change log 2026-11-09 | |

## Phase B: check the built screens against the design

Phase B runs after phase A. For each board up to v48, capture the app screen on the iPad and compare it with the board PNG and JSON:
- **Kid screens:** A1, A1b, A1n, E1, E3, A2, A3.
- **Grown-up screens:** G0–G8, G1c–G1g, G2m, C2, C3, C3g, C3m, C3x, C4, C5.
- **First-run setup:** S1–S4.

For each one, list the differences, fix them in small PRs, and send copy or design questions to the design session.

## Rules for the run

- **Real data on the iPad:** never save. Checks look and then Undo, Cancel or Leave.
- **WDA:** start it only while checking, and stop it after.
- **Design questions:** go to the design session. Where the spec leaves a gap, build the simplest reading and note it in the PR.
- **Art:** picture-only changes come in batches ("art final"). Pull `kit.js` and run `make art` only then.

## Results (2026-11-15, night run)

| # | Result |
|---|---|
| A1 | Merged, PR #86. |
| A2 | Merged, PR #87. The foot's "School lists · {date}" is still to do. |
| A3 | Merged, PR #88. Phase B reworked it into the search plus the G7 card (PR #92). Changing to "at home" or a preschool is not built. |
| A4 | Merged, PR #89. |
| A5 | Merged, PR #90. "Skip this day" sits above "Make this free time" on This day; the design session is asked to confirm. |
| A6 | Already built (the "Before {item}" button, Leave in, A2 for that outing). Nothing new. |
| A7 | Merged, PR #91: tags, Ride 2nd, the faded 2nd on A2. C2c (a 2nd that changes buses) is not built. |
| A8 | Already built: bold caption labels on every form, MOE holidays. Nothing new. |
| B | PR #92: G6 "›" rows and the To school line, G4 Going, the G7 card, the G1g hub colour. Checked G1, G8, C3 and C3k against their boards; open questions went to the design session (G4 one-line rows, the Terms list, G6 Home / evening missions). |

Still to check on the iPad in a daytime session: the kid screens (A1, A1b, E1, E3, A2, A3), C2 with a working stop lookup (it failed at night), S1–S4, and the snapshots (`make snapshots`).
