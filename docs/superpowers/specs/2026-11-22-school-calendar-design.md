# School calendar (phase 1): design

Design session, 2026-11-22, with the user. Boards K1, K1o, K1n and E3h; the home boards with the
calendar button (layout v71). Screen rules live in the M2 screens spec, section "K1 · School calendar";
this note keeps the why and the choices.

## Why
Grown-ups want to see the year ahead: when the school holiday seasons fall and where the public holidays
are, for each kid. The app already bundles the MOE calendar (terms, vacations, school holidays, public
holidays, days off in lieu, 2026–2027) and each school's own terms, but showed them only as a list
behind Settings → School → Terms. It replaces local issue 014 (G6 had no holiday line).

## Goals, non-goals
- Goal: one read-only year view where each kid's school days off and the public holidays are easy to
  see, with any month opened larger.
- Goal: kids can open it too, without the lock (nothing on it changes the plan).
- Non-goal (phase 2, backlog Later): opening a kid's calendar from Settings → School → Terms, editing
  own terms and preschool closures, family events (birthdays, appointments), Google Calendar sync
  (its own privacy note: the first time kids' appointments leave the iPad).
- Anti-goal: a second calendar app. No events, no editing, no sentences on screen.

## Approaches considered
1. **Year timeline** (one row per kid across 12 months, holiday dots, a "coming up" list). Shows seasons
   at a glance, but no dates; dropped by the user.
2. **Twelve month cards** (picked). A familiar calendar; every date visible; tap a card to open that
   month larger.
3. A separate month screen with its own paging (first version of 2). Dropped after the screen-only
   reviews: two "‹" controls with different jobs confused every reviewer; opening the card in place
   removes the second screen and its arrows.

## Decisions (user unless marked as the designer's call)
- One screen. Year tabs "2026 | 2027" (the data's years), no arrows. Tap a month card → that month
  opens over the year (numerals 32, cells 104); "×" or a tap outside closes it.
- Marks, three only: a kid's school day off in the kid's colour (Kid A sky, Kid B apricot, both split
  diagonally); a public holiday in red numerals on a light red cell; today as a dark disc behind the
  numeral (the cell keeps its colour). Weekday letters "Mo … Su" on cards, "Mon … Sun" when open;
  weekend columns lightly shaded.
- Legend: the kids' faces with "Kid A off", "Kid B off", "Both off", "Public holiday", "Today".
- Entry: a `RoundButton` 96 with a calendar picture on every kid home, left of the pencil
  (1128–1224, y 36–132). The right panel moves down 36 so the weekday line passes under both buttons.
  No Settings entry in phase 1 (the user: home is enough while there is nothing to edit).
- Holiday weekday on home: a public holiday turns the weekday line red, with the holiday's name
  under it as a caption ("Deepavali"); a school holiday keeps the weekday ink with the break's name
  under it ("June holidays"). The "· Holiday" suffix goes.
- Designer's calls: day-off colours follow the kid colours already used on home; red only for public
  holidays (everyone off; preschools too); the opened month's title sits in the card, not in the
  header, so the header keeps one back control; data years only, no empty future years.

## Reviews
Three screen-only reviews by a fresh reviewer (harness UX review tool, #241): round 1 on sketches,
round 2 on boards, round 3 on the simplified screen (reports in the design notes folder). Round 3's
points taken: legend meaning, light red public-holiday cells, a smaller today disc on cards, the
"×" on an open month, a neutral year tab, night contrast. Not taken: a countdown (kept simple),
current month first (Jan–Dec order). Left to the iPad: whether kids mis-tap the two buttons, read
their colour, or find today.

## Left to the builder
- The calendar picture is a placeholder on the boards; the crayon kit picture comes with the next art
  batch.
- Data: `SchoolCalendar` / `FamilyCalendar` already give each kid's days off and the public holidays.
