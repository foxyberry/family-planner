# Event lists: each outing carries its own lists; pickup and back-home moments

Design session, 2026-11-22, with the user. Local issue 024. It reverses the 2026-11-14 decision "events carry no missions of their own". It builds on the home redesign (2026-11-22-home-redesign-design.md, layout v75). Screen rules go into the M2 screens spec once this note is approved.

## Why
- **Today's model.** Missions live only in routines (C5). Home works out "mission windows" from the day's points (wake, each leave, each home, dinner, bed) to decide which row gets the button.
- **The trouble.** Every special case needs its own rule: a morning with no outing, an afternoon outing, a linked chain.
- **The user's aim.** Make "an outing's list" an explicit thing, so the rule is one line: *a row whose event has a list can be tapped*.
- **Pickup.** The user also wants to see when a grown-up has to leave to fetch a kid.

## Goals, non-goals
- **Goals.**
  - Each outing can carry an optional **before list**: missions and things to bring, in one list.
  - Routines become reusable **bundles** that an event picks.
  - Events can be **linked**.
  - An event can carry two **moments** of its own: **pickup** (a grown-up leaves to fetch the kid) and **back home** (an optional after list).
- **Non-goals.**
  - Missions on a day with no outing. A kid at home all day, or a weekend at home, has no mission rows, and the no-outing slide "All done? Slide!" goes (user, 2026-11-22).
  - Grown-up profiles (who picks up): later, its own issue. Pickup is for "a grown-up".
  - Notifications.
  - Moments on the 24-hour clock.
- **Anti-goals.**
  - A screen full of striped rows.
  - Rows that exist only to say "you came home".
  - Explanatory words on the kid screens.

## Approaches considered
1. **Keep the time windows (today).** Missions stay in routines; home computes windows. Rejected: case-by-case rules, and the windows are invisible to grown-ups editing events.
2. **Lists on events, opened by time.** A list "opens" at wake for the first outing, else N minutes before leaving. Rejected by the user: the list should simply open when the row is tapped. Time only decides which row is highlighted.
3. **Lists on events, always tappable, the nearest unfinished one highlighted, with moments for pickup and back home (picked).** One rule for access and one for emphasis. Pickup and back home are moments of the same event, not separate events, so they move with it.

## The model
- **Bundle** (replaces C5's morning / evening routine lists).
  - Shape: `Bundle { id, kid, name, items: [Mission] }`.
  - A `Mission` keeps today's shape `{ id, name, picture, order }` and its **days** (Library bag: Thursdays).
  - Seed bundles per kid: "Morning routine" (today's morning missions). "Evening routine" stays later.
- **Event lists** only on **outings**. An outing is an item with a trip, or an item linked into a chain that starts with one; template slot, every-week and just-once items all count, and School is included. Items that are not outings carry no lists (user, 2026-11-22: a day with no outing has no event to get ready for, so it has no missions).
  - **before**: `{ bundles: [bundleId], bring: [KitSlot ≤ 4] }`. Bring is the picker inside the Before card, as built (up to 4).
  - **after**: `{ bundles: [bundleId], items: [Mission] }`. Optional; things to do back home.
  - Both are empty by default. Seed: School's before = Morning routine bundle + Backpack.
- **Link** (`From`, as built). The **before** list of the chain's first event shows the Bring of every event linked after it, each picture once. Swimming after school puts the swimsuit on School's list, because the kid packs it in the morning. A linked event still has its own list, which opens from its own row.
- **Way home** (designer's call, replacing a bare pickup switch; the form row is labelled "Back"): a row on the event, `wayHome: pickup | bus | walk | none`, default none.
  - It belongs to the **last** event of a chain, because the kid comes home only after it. A linked event with no trip of its own (Swimming after School) has it.
  - `homeAfter` (built) is its minutes.
  - Only **pickup** makes a home row. Pickup leave = end − `homeAfter`.
  - When the last event is skipped on a day (holiday, "skip this day"), the event before it becomes the chain's end for that day, and its own way home is used.
- **Lists are per kid** (designer's call): on an event for two kids, each kid has a before list (their own bundles + the event's Bring, which is shared). The form's Before card gets kid tabs when the event is for more than one kid. A shared row opens A2 on the first kid in family order, and A2 keeps its kid column to switch.
- **Linked Bring is checked once, on the chain's first list** (designer's call). Swimming's swimsuit shows on School's before list only. Swimming's own list holds only its non-Bring items, and its row is tappable only when that list is not empty. The done mark lives on the list where the item shows.
- **Done state**: per kid, per date, per event, per list.
  - Shape: `{ kid, date, eventId, list: before | after, doneMissionIds }`.
  - The slide and medal stay per outing: `{ kid, date, outingId, ready, medal }`. The mission-window records are dropped.
  - Migration: a window's done ids → the window's outing's before list (the morning window → that day's first outing); records without an outing are dropped (they are kept 14 days only). Kid B's seed morning routine becomes a bundle that no outing uses until Kid B has one.

## Home (A1 "Next things", replaces the mission-row rules)
- **Rows per event** (moments), each at its own time in the time-ordered list:

  | moment | time | who | list | when it shows |
  |---|---|---|---|---|
  | leave (the event row) | leave time (start for no trip) | kid | before | always |
  | pickup | end − homeAfter | a grown-up | none | when pickup is on |
  | back home | end + homeAfter | kid | after | when the after list is not empty |

- **Title**: always the event's name ("Swimming"). The moment is told by the **picture**:
  - leave: the way (bus, car, walk);
  - pickup: a new kit picture, a grown-up with a car (to draw);
  - back home: the kit `home` picture.
- **Faces**:
  - leave and back home: the kids of the event;
  - pickup: the kids being picked up, plus the grown-up picture as the row picture.
- **Long titles**: up to two lines, broken between words (30 bold, line height 1.1); "…" at the end of line two if it still does not fit. The card's title follows the same rule at 36. Applies to every row.
- **Tappable**: a row with a list (before or after, not empty for that kid today) carries the crayon "›" and opens it. A row without a list has no "›" and does nothing.
- **Unfinished** = some item not ticked (the slide does not count). When a row's time passes it leaves the list, and its list lapses with it: there is no carry-over and no reminder (kid independence: natural consequences, designer's call).
- **Highlight**: only the **nearest row with an unfinished list** gets the kid-colour hatch (shared rows: sand). It is the next card when that card has an unfinished list, else that row in the list. Everything else stays plain.
- **Pickup rows**: never tappable, never hatched. The time cell and dots work as for any row; the dots help a grown-up too.
- **Moments are not drawn on the clock.** The clock shows what each time is for; moments live in the list only.

## Build order
- First: bundles, before lists, Back (way home) and the pickup row. **Later** (user, 2026-11-23): the after list, its back-home row and A2h; the model keeps an empty `after` so no second migration is needed. Before that step, decide what fills A2h's top area (a candidate: the rest of the evening as pictures).

## Scope
- Before, After and Back follow the form's **This day / All days** like Bring did (`EventException` gains them).

## A2 (the list screen)
- **A2 follows the opened event** (designer's call):
  - the way strip shows that event's trip, and none for a back-home list;
  - the kid column lists only that event's kids.
- **Opened from a row**: A2 opens on that kid and that event's list (before or after). Its title is the event's name and the list kind, as the existing header style shows it.
- **Before list order**: the bundles' missions (in bundle order, filtered by the mission's days), then Bring (own, then linked events'), each picture once.
- **The slide**: "slide to go" stays on the before list of an outing with a trip. An after list ends with no slide; the last check shows the done view.

## Screens touched
- **G2 / G4 / C3 / C4 (event forms):**
  - the Bring row becomes **Before**, opening a card with bundle chips and the Bring picker;
  - new rows **After** (bundles and the event's own missions) and **Back**, the way home (`ChoiceCircles`: Pickup, Bus, Walk, None, with its minutes);
  - G4 (School) gets the same rows.
- **C5:** becomes the bundle editor. It keeps the mission editor, `Days` and the 8-per-kid cap per bundle.
- **Home A1 / E1 / E3 / A1n:** the row rules above.
- **A2:** opened per event list.
- **Kit:** one new picture, pickup (a grown-up and a car).

## Left to the builder
- Storage of bundles next to missions.
- The exact migration code.
- How the form's Before card lays out its bundle chips: follow `ChoiceCircles` / `DayChip` patterns, then board it.
- Boards (drawn): G2b and G4 rows, cards F2 / F2k / F6 / F7, C5 as bundles, A2h opened from a back-home list (layout v77); A1p with the moment rows (v76). The kit `pickup` picture comes with the next art batch.

## To check on the iPad
- Do kids tell the three moments apart by picture alone?
- Does a grown-up notice the pickup row in time?
- With two kids on the same outing, is one shared row with two faces clearer than two rows?
