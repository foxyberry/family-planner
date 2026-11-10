# M2 repeats, dates and changes (build row 6c)

Spec: `2026-11-07-m2-screens-spec.md` › "Repeats, dates and changes" and "Keep it as plain as the
built screens"; boards G2 (All days), G3 (This day), G5 (Change from when?), layout v25.
Grown-up mode (G1, the C6 slice card tabs, G4 School) is 6d.

## Where things stand

- Holidays are Singapore public holidays only (`HolidayProviderLive`). School terms, vacations,
  MOE school holidays and days off in lieu are in `SchoolDirectoryLive/Resources/moe-calendar.json`
  but nothing reads them, so a weekday in the school vacation still shows School.
- Every-week items are `.weekly(days, from:, until:)`; "Skip school holidays" skips public holidays.
- E5 edits a series from the next run (`SeriesEdits.applying`), skips one day (`skippedDays`), and
  has no This day / All days tabs.

## PR 1: the school calendar

- Port `SchoolCalendarClient` + Live: for a kid's school, the terms (start/end, inclusive) and the
  closed days (vacation, MOE school holiday, public holiday, day off in lieu) of a year, from
  `moe-calendar.json` by level (primary, secondary, MOE kindergarten); a school with its own
  `termDates` (international list, private) uses those. Public holidays keep coming from
  `HolidayProvider` for kids with no school.
- `DayPlanner`: a kid's weekday is a day off (the Sunday template, as a public holiday is today) when
  the kid's school is closed that day. Kids without a school follow public holidays only.
- Home, Missions, Our day and the editors read the kid's closed days instead of public holidays.

## PR 2: Runs and school holidays (G2)

- `ScheduleItem.runsEnd`: `term` and `count` are worked out when the days are (`FamilyCalendar.resolving`,
  so a calendar update moves a term end), `date` is the recurrence's `until`, `none` runs on. Items
  saved before Runs keep their `until`.
- `FamilyCalendar` (Domain) replaces PR 1's days-off map: each kid's school calendar and the public
  holidays, days off per kid or audience, and the runs' ends.
- E5 All days and C3: **Days** (chips) and **Runs** ("{start}" → "End of term" / a date / "After n
  times" / "No end"; the end opens a small card, a tap outside puts it back). A new item runs to the
  end of term when the kid's school has terms. "Skip school holidays" skips the kid's days off; it is
  off by default for an activity and turns on when the item follows School.
- New parts `FieldButton` and `DateField` (TimeField now uses FieldButton).

## PR 3: This day / All days (G3, G5)

- `ScheduleItem.dayChanges` (`DayChange { day, start?, end?, title?, iconName? }`): a day changed on its
  own; only the fields given override the series (`ScheduleItem.on(day)`, used by `DayPlanner`).
  A skipped day stays in `skippedDays`.
- E5 side column: tabs "This day" (default) / "All days". This day hides Days, Runs, holidays and the
  event rows, reads "{Day d Mon} only" and "Skip this day" / "Bring back this day"; its Save keeps the
  change to that day (`SeriesEdits.changing`). All days reads "Every {days}" and "Remove every week".
- Save on All days opens G5 "Change from when?" (Today / Next {weekday} / Date): `SeriesEdits.splitting`
  ends the old part the day before and starts a new one; a day on or before the start changes the series
  in place. Changed and skipped days that no longer fit are listed in the card and dropped.
- The old automatic split ("today keeps the old times") and the E5 captions are gone.

## PR 4: linked time and no-school days

- The Time row of a linked item: "School end + {n} min" (0–60, step 5), length kept, with today's
  worked-out time as the caption.
- "No school days": Skip (default) or "At a set time" with its own time and Going row.

## Later in 6c

Repeat every 2–4 weeks / every day; monthly, yearly, multi-day and extra sessions; Notes row.
