# M2 screen spec: the day and the home clock

Boards: A1, E1, E3, C0, C1, C3, C4, C3k, E5, E6 (design canvas, page "v3 · Crayon").
Public-safe: children are **Kid A** (older, school) and **Kid B** (toddler, at home). No school, stop, route or bus numbers appear here. Times in examples are seed values, not real ones.

## Change log
The repo copy of this file must match this one. Each change is dated; the newest is last.
- 2026-11-07: first version.
- 2026-11-07: hub text on M1 type steps (24 / 48 / 30); midnight day change; sleep stored as two slots and merged; E5 save rule.
- 2026-11-08: E3 shows the day above both kids; C1 "Day" opens C6, "Holidays" opens C7 (later); new C6 and C7 sections.
- 2026-11-08: seed templates with exact times (Mon–Fri, Sat, Sun) and every-week items; day types are only Mon–Fri / Sat / Sun; a weekday school holiday uses Sun (E3, C6, model); free time drawn as plain paper; slot picture sizes 104 / 84 / 56 with radii 0.68R / 0.8R; snack and play share green, sky stays for after-school items.
- 2026-11-08: Saturday "Weekend school" 9:00–12:00 as an every-week item (sky); weekend activities are every-week items, not template slots, because holidays use Sun; E3 line "No bus today"; E3 example hub "Weekend school" / "until 12:00".
- 2026-11-08: new E3b (Sunday, Sun template + a Sunday every-week item) and A1n night look (switch at the evening routine and back at wake-up, colours with contrast, lit paper clock face, plated pictures, chalk button).
- 2026-11-08: Sky switch (kid day/night switch on home screens, looks, tap rule, 1.2 s animation, Reduce Motion); Motion catalogue with what is in M2; B2n diary at night (M5).
- 2026-11-08: Sky switch looks are kit slots skyDay / skyDusk / skyNight (kit now 62 slots).
- 2026-11-08: Picture rigs proposed (tap a slot to play its picture; rigid-part rules; 18 rigs + default hop; draft rigs.json). Not decided yet.
- 2026-11-08: Picture rigs approved; pipeline (rig run imagesets + KitRigs.dataset/rigs.json from kit.js); scale 1 by default with a debug slider 1.0–1.5; the dancer now has long hair (part of the head).
- 2026-11-08: rig scale default 1.5 (user checked the × 1.5 board).
- 2026-11-08: Seed data: Kid B day table, picture choices (actPlay on weekends, blocks on weekdays), "Free time" title, school hours 7:30–3:00, birthday over the nap (values set by the main session, accepted).
- 2026-11-08: Hub first line is the weekday instead of "NOW" (A1, A1n, E1, E3, E3b boards). Seed School picture is wolfie (public kit, user choice). Weekend school picture is a swappable flag (8 country flags, kit 0d3).
- 2026-11-08: hub "until" line uses 12-hour time with am/pm.
- 2026-11-08: every time shown on any screen (kid or grown-up) is 12-hour with "am"/"pm"; ranges in the same half may put it once at the end ("3:30–4:30 pm"). Video lengths (0:24) are not times.
- 2026-11-08: home "now and next" is one rule for every kid and every home screen: Kid A now = hub, Next = one row (any kind of slot, start time only, head 36 bold) + time left "in 38 min" (display 96); Kid B now/next circles. `KidFace` replaces `KidDot`.
- 2026-11-08: `KidFace` defined (ringKidA/B kit slots + `Kid.face` slot, sizes 40/34/30); replaces `KidDot` on every screen.
- 2026-11-08: `KidFace` sizes follow the type line heights on the 8 pt grid (48 / 40 / 32), face at 86 % of the box, gaps 16 / 8.
- 2026-11-08: `KidFace` ring moves to `CrayonKit` (UI shapes are drawn in code); kit slots ringKidA/B withdrawn.
- 2026-11-08: "CrayonKit UI parts added on the boards": chevrons, arrows, plus/minus, crayon ring, KidFace ring, KidBand, number plate, card, pill, swatch, small marker icons, with sizes and phase.
- 2026-11-08: A2-MVP mission screen (board A2-MVP, build step 5): A2 layout with no live data, a way strip at the top (home → destination, mover = how the kid goes, placed by the clock), "All done!" per kid.
- 2026-11-08: E3 / E3b right panel = A1 (no day name, no "No bus today"); weekday holiday caption "Holiday · no school today" under Kid A.
- 2026-11-08: hub title may wrap: title 48 on one line, else head 36 on up to two lines (284 wide), else "…" (user decision; "Weekend school" was cut to "Weekend…").
- 2026-11-08: two-line hub spacing: title lines 38 apart (1.05), group gaps 44; baselines 466 / 510 / 548 / 592; alternative numbers if the weekday moves to the right panel.
- 2026-11-08: weekday moves from the hub to the top of the right panel on every kid home screen (head 36, 24 below; "· Holiday" on weekday holidays); hub = title (540, or 512/550) + until (590 / 594). (User decision.)
- 2026-11-08: principle audit of every board. Type sizes off the scale moved onto it (26 → 24, 28 → 30, 32 → 30, 44 → 48); gaps moved onto the tokens, which now include 4 and 12 (inside one part only); bus bubble unit "min" at 24 so "29 min" fits; Next row gap 24; `KidFace` 48 + gap 16 in the A1/E3 kid blocks, 40 in tabs; E3 keeps the weekday line (stale "no day name" removed). New board 00 Principles (rules, also under Shared rules) and 0c2 kid parts; 0a/0b/0c updated (NowRow, KidDot, "for Kid B" and "wakes up once missions are done" removed).
- 2026-11-08: one colour per kid, day and night: `kidA` #56B4E9, `kidB` #E69F00. #2E8FE0 is renamed `pickBlue` (✓, picked, focus, any kid); #F28C28 dropped.
- 2026-11-08: build step 5 data: missions (seed lists, name = circle caption), trips (`way` + `leaveBefore` on any slot or item; an outing = has a trip; seed school bus 5, weekend school car 25, swimming car 10), done state per kid per date (resets at midnight, 14 days kept), "Missions →" on home in the mission morning (wake-up to 12:00 pm, board A1-MVP: "{Place} in" + time left), C5 section, E6 "Cards" shown from step 5. Editing trips is N1.
- 2026-11-08: step 5 review of the main session's calls: full-screen cover, centred C5 editor, mover rule, "1 mission" / "Nothing yet" accepted; changed: C5 footer uses an inline `MarkerGlyph.handle`, way line "on foot" and "· timetable" only for bus and shuttle, "+n" circle in the kid's crayon colour with "{n} more".
- 2026-11-08: A2-MVP back circle on the last page: kid's crayon circle, chevron, caption "Back" (main session's call, accepted).
- 2026-11-08: A2-MVP way strip drawn out in full (boards A2-MVP and A2-MVP-w redrawn: home at the left, as the text said): ground, three hills, four trees, a waving road (ink 28 + green 17, no grey road), stops, stems, labels, mover track and card place; reference `handover/crayon-ui-ref/way-strip.js`. A1 mission-morning panel fit (board stack, pinned button, what shrinks first).
- 2026-11-08: status bar (user decision; replaces a same-day "hide it on kid screens" line): shown on every screen, band y 0–24 empty; board coordinates are full-screen coordinates (the boards already keep the band empty), so the 1032 frame is laid out in full-screen space, not inside the safe area; other sizes scale the whole frame by min(W/1376, H/1032) (12.9": 0.992); snapshot check for the band.
- 2026-11-08: A2-MVP strip shows the family's next outing whichever kid is chosen (user asked why it vanished for Kid B); the card starts with the owner's `KidFace` 40; "leave at" only for a kid with their own outing; strip hidden only when no kid has an outing left (boards A2-MVP, A2-MVP-w updated).
- 2026-11-08: Fixed regions (Shared rules, user): regions are fixed frames from the board and never move up or resize by content; a region with nothing to show uses its empty look. A2-MVP: no outing left keeps the strip region with a meadow, home and "Home all day"; the kids and missions stay at 536–968.
- 2026-11-08: A2-MVP empty look card moved to (120, 38) so it clears the house; `TimeLeft` speaks full words ("38 minutes").
- 2026-11-08: A2-MVP stems start at each stop marker's top edge and run 32 up (same visible length on the wave); pictures sit on the stem by their drawn bottom (boards updated, v127).
- 2026-11-08: sizing formulas for landscape full screen on every iPad replace "Board = screen" and "Other screen sizes": one scale s = min(W/1376, H_safe/1008), positions from the safe top and per-region anchors (left / right / stretch; home panel stretches), type and spacing with floors (caption 24 fixed), pictures and strokes × s. Portrait and windows not covered yet (backlog N10).
- 2026-11-08: A2-MVP last line: live bus, "Leave in", slide to go and medals are build step 6 of the MVP (user scope change); the timetable strip stays as the car / taxi / walk and no-live view.
- 2026-11-08: new A2-live (board A2-live): live strip (our stop in the middle, next two buses placed by minutes, chosen bus = first one you can catch, "too soon" faded), header "Leave in" + On time / Leave now! / Ask a grown-up, 30 s refresh and 2 min fallback to the timetable strip, slide to go for kids with an outing, medals from the time only (L1 / L2 rule), done state gains medal; C2 MVP cut (Plan A only, stop code, buses, walk, ride, late grace, LTA key in the Keychain); "Going" row on C3/C4/E5 [proposed].
- 2026-11-08: **no MVP stage** (user): the morning is one screen, "A2 · Morning", with a timetable look and a live look; ids renamed A2-live → A2, A2-MVP → A2t, A2-MVP-w → A2t-w, A1-MVP → A1m, the old plan-B board → A2b; "MVP data" → "Morning data"; E4 retired (the timetable look replaces it). Change log lines above keep the old names.
- 2026-11-08: way strip back to the first design (user): straight road at y 240, our stop and home in the middle (x 860), destination at 1150, stops at 170 / 380 / 620 by bus, four trees, no hills; the same strip for the live and the timetable look; timetable mover rules and card place updated; stems and drawn-bottom rule kept. 0a gains "Sizes on every iPad".
- 2026-11-08: "Going" row drawn (board C3g): Going slots None / Walk / Bus / Car / Taxi, Leave stepper 0–90 step 5 with the leave time, Bus → "Uses Our buses ›".
- 2026-11-08: answers on the sizing build: the way strip keeps its 1248:340 shape (× s, centred in its region), mission captions take up to two lines in a pitch-wide label (never under 24), "All done!" grows to fit its title (min 400 s).

Markers used below:
- **[board]**: drawn on the canvas, implement as written.
- **[proposed]**: the board does not show it; this is the design decision for M2. Change it here first if you disagree.
- **[later Mx]**: on the board but owned by a later milestone. In M2 the part is hidden, not shown disabled, unless stated.

---

## 0. Shared rules

### Principles (board 00, 2026-11-08)
Every board and the app follow these. Change them here and on board 00 first.
- **Time**: every time is 12-hour with am / pm. One now and one next per kid, never a list; Next skips free time and slots that only resume. Medals come from time only.
- **Kids**: never locked (Slide to go and All done! are always on). Each kid finishes on their own. Kid screens never scroll; more turns a page ("+n"). No shame: late = no medal, never a sad face.
- **Who is who**: a kid = face + name, colour never alone. One colour per kid day and night (#56B4E9 / #E69F00). Pick blue #2E8FE0 = ✓, picked, focus, for any kid. 2+ kids: list on the left, chosen kid's missions on the right.
- **Type and space**: Playpen Sans, six sizes (144 · 96 · 48 · 36 · 30 · 24), nothing under 24. Gaps 4 · 8 · 12 · 16 · 24 · 40 · 64 (4 and 12 inside one part). 12 columns, margin 64; header 48–128, content 176–968.
- **Drawing**: UI shapes are CrayonKit Shapes; pictures come from the kit only (`KitIcon`); the kid's own drawings swap into the same slot later. Motion 1.2 s, rigid parts; reduced motion = still.
- **Privacy**: public repo uses Kid A / Kid B; no home, stops, routes, school names or keys; real family times stay on the canvas. Wolfie is public; the home drawing is not.
- Parts: board 0b (controls), 0c (content), 0c2 (kid parts: `KidFace`, `MissionCircle`, `KidList`/`KidBand`, `NextRow`/`KidNowNext`, `WayCard`, `DonePill`).

### Grid and frame (iPad landscape 1376 × 1032 pt)
- 12 columns of 82, gutter 24, margin 64 (`GridMetrics`). Column n (1-based) starts at x = 64 + (n − 1) × 106.
- Header band y 48–128. Content y 176–968. Main button bottom edge at y 968.
- **Fixed regions** (2026-11-08, user): every screen is a fixed frame of named regions taken from its board (for example header 48–128, strip 176–516, kids and missions 536–968). A region's place and size never come from its content, and a region never disappears so that the regions below can move up: when it has nothing to show, it shows its empty look (each screen names one). Content inside a region is top-aligned (or aligned as the board shows) and capped to the region; it never pushes, centres or resizes the frame. The y values are board coordinates, which already sit below the 24 pt status bar band (see "Status bar"); on other iPads they turn into screen values through "Sizing formulas" below.
- Spacing tokens: **4 · 8 · 12 · 16 · 24 · 40 · 64** (changed 2026-11-08). 4 and 12 are for the inside of one part only (icon to label, chip padding, caption under a picture); between parts use 16 or more. No other gaps (2, 6, 10, 14, 20, 32, 48, 56 were mapped to the nearest token on every board). Line pitch inside a text block (e.g. the two-line hub, 38) is type, not spacing.
- Type: `CrayonType` hero 144, display 96, title 48, head 36, body 30, caption 24. Nothing smaller than 24.
- Kid screens use `KidScreen` (no scrolling; cap content). Grown-up screens use `GrownupScreen` (header and main button pinned; only the named area scrolls).
- **Status bar** (user decision, 2026-11-08): the iPad status bar shows on **every** screen, kid and grown-up. Its band, y 0–24, holds nothing; only full-bleed backgrounds (paper, night sky) run under it. Status bar text is dark on day screens and light on night screens (A1n, B2n).
- **Sizing formulas: landscape, full screen, every iPad** (2026-11-08, user: "the design language is fixed to the 13 inch"; research report "아이패드 화면 크기 대응 레이아웃"). The boards stay drawn at 1376 × 1032; these formulas turn a board value into a value on any landscape iPad, from the mini (1133 × 744) to the 13" (1376 × 1032). At 13" every formula gives the board value back.
  - **Inputs**: W = window width, H = window height, `safe.top` = the top safe-area inset (the status bar, 24 on current iPads). H_safe = H − safe.top. Lay the screen out in full-screen space; the band 0 … `safe.top` holds nothing but full-bleed backgrounds.
  - **One scale**: s = min(W / 1376, H_safe / 1008). 13": 1.0 · 12.9" (the family's, 1366 × 1024): 0.992 · iPad Pro 11" (1210 × 834): 0.804 · iPad / Air 11" (1180 × 820): 0.790 · mini (1133 × 744): 0.714. The reference height is 1008 (the 13" safe area), not 1032: this is the fix for the overflow bug. Never `scaleEffect` the whole screen (blurry text, wrong hit areas); multiply each value by s instead.
  - **Floors**: `fluid(ref, lo) = max(lo, ref × s)`. Floors are design choices, not research values: check them on the family iPad and on a mini simulator [proposed].
  - **Vertical position**: y = safe.top + (y_board − 24) × s. Header top 48 → 24 + 24 s; main button bottom 968 → 24 + 944 s (mini: 41 and 698, leaving 46 below).
  - **Horizontal position**: every region has an anchor. Default, when a screen does not name one: a region that spans both margins (64 … 1312) **stretches** (left = 64 s, right = W − 64 s); otherwise it is **left**-anchored (x = x_board × s) when its board centre is left of 688, else **right**-anchored (x = W − (1376 − x_board) × s). Named exceptions: the home right panel (A1, A1n, E1, E3, E3b) stretches from 928 s to W − 64 s, so the extra width of a narrower-but-taller iPad goes to the text, not to a gap.
  - **Type**: hero `fluid(144, 96)`, display `fluid(96, 64)`, title `fluid(48, 36)`, head `fluid(36, 30)`, body `fluid(30, 24)`, caption **24 fixed** (still nothing under 24). Mini: 103 / 69 / 36 / 30 / 24 / 24. Use `Font.custom(_:size:relativeTo:)` with the scaled size so Dynamic Type still works on top; do not also use `@ScaledMetric` on the same size. Text that may not fit at its floor wraps or uses `ViewThatFits`; it never shrinks below the floor.
  - **Spacing**: 4, 8, 12 fixed (inside one part). 16 → `fluid(16, 12)`, 24 → `fluid(24, 16)`, 40 → `fluid(40, 28)`, 64 → `fluid(64, 40)`. Grid: margin `fluid(64, 40)`, gutter `fluid(24, 16)`, column = (W − 2 margin − 11 gutter) / 12 (82 at 13").
  - **Pictures and drawn parts**: sizes × s (clock R 372 s, centre (448 s, safe.top + 504 s); mission circle 112 s; way strip 1248 s × 340 s, keeping its shape, centred in its stretch region; the paper shows on both sides when the region is wider; labels and the card sit on top at their own type sizes). Kid tap targets stay ≥ 64 [proposed]. Crayon outlines × s; focus rings and hairlines fixed.
  - **Not covered yet**: portrait and resizable windows (iPadOS 26 cannot be refused). Until they are designed (backlog), the same formulas run with s floored at 0.70; content may clip in small windows.
- **Bottom**: the main button bottom (968 on the board) stays above the home indicator area.
- **Check**: snapshot tests render with a 24 pt status bar band and fail if any part other than a full-bleed background starts above y 24 (in board coordinates, after scaling). Test 1376 × 1032, 1366 × 1024, 1180 × 820 and the mini 1133 × 744 (largest and smallest first), and fail if any text is under its floor or a kid tap target under 64.
- Colour never carries meaning alone. **One colour per kid, day and night** (changed 2026-11-08): Kid A `kidA` #56B4E9, Kid B `kidB` #E69F00 (the `KidFace` ring, the `KidBand` edge; fills use sky #8FD3F4 / apricot #FBC97A crayon), always with the face and name (`KidFace`). `pickBlue` #2E8FE0 (was `kidABlue`) marks ✓ done, picked and focus for any kid; it is not a kid colour. #F28C28 (`kidBOrange`) is dropped.

### Grown-up form layout (C3, C4, E5, C3k)
- Form card: `PaperCard`, columns 1–8 (x 64, w 818 to keep the marker stroke inside 824), y 176–968.
- Label column inside the card: x 88, caption-weight body text in `softText`, label tops align with their control tops.
- Controls start at x 232.
- Side column: columns 9–12 (x 930, w 382, the 400 span inset 18 so the crayon spill stays inside).
- Main button: `InkButton`, side column, y 872–968.

### Seed data in M2
- Two kids from a fixed seed, editable through C3, C4, E5 and C6. Adding a child is M4 (S1).
- **Kid A, Mon–Fri template** (user-approved 2026-11-08; generic canvas values, safe for the public repo). It matches boards A1, E1 and C6:

  | slot | time | kind (colour) | picture |
  |---|---|---|---|
  | Sleep | 20:00–6:30 | sleep | actSleep |
  | Breakfast | 6:30–7:30 | morning routine | actBreakfast |
  | School | 7:30–15:00 (includes the trip) | school, edges locked | wolfie |
  | Snack | 15:00–16:00 | play / free (green) | snack |
  | free | 16:00–17:00 | free time (paper) | — |
  | Play | 17:00–18:30 | play / free (green) | blocks |
  | Dinner | 18:30–19:15 | dinner | actDinner |
  | Shower | 19:15–20:00 | evening routine | actShower |

- **Kid A, every-week items**:
  - "Swimming", Mon and Wed 15:30–16:30, after-school (sky), actSwim, skip school holidays on.
  - "Art club", Fri 15:00–16:00, actArt.
  - "Weekend school", Sat 9:00–12:00, actLanguageSchool, skip school holidays off (its breaks are not the school's).
    - actLanguageSchool is a flag on a pole with a plain cloth. Grown-ups can swap it for a country flag in C3: flagKR, flagJP, flagCN, flagUK, flagFR, flagIN, flagTH, flagVN (kit 0d3). The seed keeps the plain flag.
  - Weekend activities are **every-week items, not template slots**. A weekday holiday uses the Sun template, so anything in it would also appear on holidays. A Sunday activity (e.g. church, actChurch) is added by grown-ups as an every-week item; the seed has none, on purpose.
  - On a Monday the clock shows snack 15:00–15:30, swimming 15:30–16:30, free 16:30–17:00.
- **Kid A, just-once item**: "Birthday", the coming Saturday 14:00–16:00, for both kids, star on.
- **Kid B** (one template for every day; morning cards Wake up · Milk (babyBottle) · Shoes; no every-week items):

  | slot | time | picture |
  |---|---|---|
  | Sleep | 19:30–6:30 | actSleep |
  | Breakfast | 6:30–7:30 | actBreakfast |
  | Play | 7:30–13:00 | blocks |
  | Nap | 13:00–15:00 | teddy |
  | Snack | 15:00–16:00 | snack |
  | Play | 16:00–18:00 | blocks |
  | Dinner | 18:00–18:45 | actDinner |
  | Shower | 18:45–19:30 | actShower |

  - On the seed Saturday the Birthday (14:00–16:00) covers the second half of the nap; that follows the priority rule.
- Pictures: Kid A weekday Play = blocks, weekend Play = actPlay, Snack = snack. The empty slot is titled "Free time" and has no picture.
- School hours (C4 "Hours") in the seed: 7:30 am – 3:00 pm, the same as the School slot.
- **Sat and Sun templates** (seed; the same for both days; matches board E3):
  - Sleep 20:45–7:30, Breakfast 7:30–8:30, Play 8:30–19:00, Dinner 19:00–20:15, Shower 20:15–20:45.
  - On the seed Saturday, Weekend school (9:00–12:00) and the Birthday (14:00–16:00) sit on top. At 9:15 the hub says "Weekend / school" (head 36 on two lines, because it does not fit 260 on one) / "until 12:00 pm", as on E3.
  - Real Sunday activity times are not in the repo; grown-ups add a Sunday every-week item in C3 (e.g. with `actChurch`).
- Debug time machine: at 6:52 on a Monday, A1 shows "Breakfast" / "until 7:30 am" and Kid A "Leave in 34 min" (M3), as on the board.

### Schedule model the screens assume [proposed]
- Each kid has **three day templates**, one per day type, plus **every-week items** and **just-once items**. A template covers sleep, routines, the school or nursery block, dinner, evening and bedtime.
  - Day types: **Mon–Fri**, **Sat**, **Sun**. There are no others.
  - **A weekday school holiday uses the Sun template** (user decision, 2026-11-08). Holidays come from the holiday list (seed in M2, C7 later).
  - "Free time" is a real template slot with no picture; it is drawn as plain paper.
- Priority when two things share time on one kid's clock: just-once > every-week > day template. The higher one is drawn and named; the lower one is cut around it. Nothing is deleted by an overlap.
- "Skip school holidays" on an every-week item hides it on dates in the holiday list. M2 uses seed holidays; importing them is later.
- The clock's day changes at **midnight**. A just-once item is on the clock on its date only, so it leaves at midnight. The C1/E6 "Just once" list keeps it until the kid's next wake-up time, so a grown-up can still see last night's event in the morning. (Agreed with the main session, 2026-11-07.)
- **Sleep across midnight** is stored as two slots, 0:00–wake and bedtime–24:00. The clock merges touching slots of the same kind into one sector with no edge line between them, and the merged slot is what "current", the 6 pt outline and "until" use (at 23:00 the hub says "until 7:00 am").

---

## A1 · Home, two kids (Kid A's 24-hour clock) [board]

### Layout
- Screen: `KidScreen` with an **empty header**. The clock uses the full height.
- Clock area: x 0–900, y 0–1032 in full-screen coordinates (see "Grid and frame": the status bar band y 0–24 stays empty; the labels start near y 100). It is not on the grid; the disc centre is at (448, 528).
- Right panel: x 928–1312 (w 384), y 96–968, one vertical stack.
- Long-press anywhere on the clock disc for 2 s → C0.

### Pie clock
- Disc radius R = 372 (diameter 744), centre (448, 528).
- **Angle**: 0:00 at the top (12 o'clock position), clockwise, 15° per hour. angle(h) = h × 15° measured from straight up; x = cx + r·sin, y = cy − r·cos. Noon is at the bottom.
- **Hour ticks**: every hour, a marker line from r 378 to r 392, 3 pt.
- **Hour labels**: 24 labels around the rim, reading 12, 1 … 11, 12, 1 … 11 (12-hour numbers on a 24-hour face).
  - Label radius about 410; use the label positions on the board.
  - 12 (midnight, top), 6 (right, 6 am), 12 (noon, bottom) and 6 (left, 6 pm) are 30 pt semibold `ink`. The rest are 24 pt semibold `softText`.
  - A 40 pt moon picture sits above the top 12, and a 44 pt sun below the bottom 12.
- **Slots**: one sector per schedule slot, from its start angle to its end angle. Touching slots of the same kind (the two halves of sleep) are merged into one sector first.
  - Fill: crayon fill (wash + flicks, as in M1 `CrayonSurface`) in the slot colour. **Free time has no fill**: plain paper with the normal radial edges, and no picture.
  - Edges: radial marker line 2.5 pt between slots, outer ring 4.5 pt.
  - The **current slot** gets a 6 pt outline.
- **Slot colours** (new token group `ClockSlot`; hex from the board):

  | kind | colour | hatch angle |
  |---|---|---|
  | sleep | goYellow #FFD23F | −40° |
  | morning routine | mint #7FD6B5 | 60° |
  | school / nursery | orange #F7A84B | −55° |
  | after-school item | nowSky #8FD3F4 | 40° |
  | play / free | green #A8DB7A | −30° |
  | dinner | coral #F9A88A | 50° |
  | evening routine | lilac #B9A3F0 | −60° |
  | just-once event | pink #F7A8CF | 50° |

  - Snack and play share the green; sky is kept for after-school every-week items (2026-11-08).
  - Free time has no colour (paper).

  - mint, orange, green, coral, lilac and pink are new palette entries.
  - Text is never placed on these fills, so contrast rules do not apply to them.
- **Slot pictures**: each slot's kit picture (`KitIcon`, from the item's slot) at the slot's middle angle. Keep it between the hub (r 160) and the rim (r R − 8).
  - Size by slot length: ≥ 3 h → 104; 1–3 h → 84; 30–60 min → 56; under 30 min → no picture. (Board A1, 2026-11-08: 68 overflowed a 45-minute slice.)
  - Radius: 0.68R (about 253) for 104 and 84; 0.8R (about 298) for 56, where the slice is wider.
- **Hub**: white disc r 152, 4 pt marker outline, on top of the slots.
- **Hand**: the "lollipop" in `handRed` #E5484D.
  - Line 9 pt from r 154 to r 312 at the current time's angle.
  - Disc r 24 at r 336, crayon-filled red with a 4 pt outline.
  - Moves once a minute (`TimelineView(.everyMinute)` / `@Dependency(\.date)`).
- Accessibility label for the whole clock: "Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. {weekday} {h:mm}, {slot}." On a school morning, M3 appends " Leave at {h:mm}.".

### Hub text (changed 2026-11-08: the weekday moved to the right panel)
- The hub has two parts only: the slot title and "until {end h:mm am/pm}" (body 30 `softText`).
  - One line: title 48 `ink`, baseline 540; "until" baseline 590.
  - Two lines (title fitting below): head 36, lines at 512 and 550 (pitch 38); "until" at 594.
- **Weekday**: the first line of the right panel on every kid home screen (A1, A1n, E1, E3, E3b): head 36 (ink by day, `nightText` at night), then 24 to the Kid A name row. On a weekday school holiday it reads "{Weekday} · Holiday". It replaced "NOW" in the hub (2026-11-08) and moved out of the hub the same day so a two-line title has room.
- Slot title = the item's name (e.g. "Breakfast", "School", "Swimming", "Sleep").
- Title fitting (user decision, 2026-11-08; replaces "never wrap"):
  1. Title 48 on one line if it fits in 260 pt.
  2. Otherwise head 36, up to **two lines** in 284 pt, broken at a word.
  3. Still too long: the second line ends with "…".
  - **Two-line spacing** (checked on iPad 2026-11-08; Playpen Sans has tall built-in ascent and descent, so the default 1.2 line height looks loose):
    - The two title lines are 38 pt apart, baseline to baseline (1.05 × 36). Build them as two `Text` lines in a 38-pt-tall box each (or a font with line height 38), not as one wrapped `Text` with the default leading.
    - Last title line → "until": 44, baseline to baseline. Baselines: see the hub layout above (one line 540 / 590; two lines 512 / 550 / 594).
- **Gap (no slot covers now)** [proposed]: title "Free time", second line "until {next start}". If nothing else is planned today: "Free time" with no second line.
- **No schedule at all** [proposed]: the disc is plain paper with ticks and labels, no slots and no hand change. Hub: "{weekday}" / "Nothing planned". No instruction to the child.

### Overlap and short slots [proposed]
- Overlaps resolve by the priority in section 0 before drawing, so sectors never overlap.
- A slot shorter than 10 minutes (2.5°) is drawn with 10 minutes' width, centred on its real time. It still shows no picture.
- Two short slots next to each other keep their order and push apart by up to 5 minutes each. If they still collide, the lower-priority one is dropped from the drawing; it stays in the data and in the side lists.

### Now and next on home: one rule (2026-11-08)
- Every kid shows **now once and next once**. Never a list.
  - Kid A, the kid whose clock is shown: now is the hub. The right panel shows only **Next**.
  - Kid B (and any other kid without the clock): the now / next circles.
- **Next** = the next thing on that kid's clock after the current one, of any kind (template slot, every-week, just-once), after the priority rule. Skip free time (no picture) and a slot that only continues after an item ends (Play after Weekend school). On E3 at 9:15 that gives "Birthday · at 2:00 pm".
- **Kid A block** (right panel, x 928–1312):
  - `KidFace` 48 (face in the kid's colour ring, replaces `KidDot`), gap 16, name head 36.
  - 24 below: "Next" caption 24 `softText`.
  - 8 below: Next row: `KitIcon` 104, gap 24, then the title **head 36 bold** over "at {h:mm am/pm}" body 30 `softText`. Both lines are one line: start time only (the range is on the clock), no wrap; a long title ends with "…". A just-once item keeps its star sticker on the picture.
  - 24 below: time left to that thing: "in" body 30 `softText`, then `TimeLeft` display 96 ("38 min"). Over 60 minutes: "1 h 20 min" in the same size; over 3 h: leave the time left out.
  - **With the live bus (build step 5, "A2 live look")** on bus mornings the time left becomes "Leave in" + `TimeLeft` to the leave time + "On time" (boards A1, E1). Same place and sizes; only the words and the target time change. On A1 (two kids) the Next row is hidden on school mornings to leave room for Kid B; E1 (one kid) keeps it under "On time".
- **Night** (A1n look): the same rule. Next is usually Sleep ("at 8:00 pm") and the time left reads "Bed in" instead of "in". The "Tomorrow · School, leave 7:25 am" row comes with the live bus (build step 5).
- Kid B block: unchanged (now 160 / next 104 circles, captions "now" / "next").

### Right panel
- **Kid A block** (spacing from the board):
  - `KidFace` 48 (Kid A), gap 16, name head 36.
  - **With the live bus (build step 5)** bus mornings: "Leave in" (body, `softText`) with an 80 pt bus picture at right, then `TimeLeft` at display 96 ("34 min"), then the status "On time" (body bold `onTimeText`, 24 pt green dot).
  - **M2 instead**: Next row + time left, see "Now and next on home".
- **Kid B block**, 64 below:
  - `KidFace` 48 (Kid B), gap 16, name head 36.
  - Row with gap 40:
    - "now": 160 circle in crayon `kidApricot` with a 104 picture inside, caption "now" under it.
    - "next": 104 white circle with a 64 picture inside, caption "next".
  - Bottom-aligned.
- **Main button**: `InkButton` "Missions →", full panel width, 96 tall, bottom of panel → A2. Shows only in the mission morning (below).
- **Mission morning (board A1m)**: from the earliest kid's wake-up (end of their Sleep slot) until 12:00 pm, on A1, E3 and E3b:
  - "Missions →" shows at the bottom of the panel (E3's "Diary →" is M5, so there is no clash).
  - Kid A block: face + name, then, if Kid A has an outing (see "Morning data") that has not started and starts within 3 h: "{Place} in" (body `softText`) with the way picture 80 at the right (bus, car, taxi, shoe), then `TimeLeft` display 96 to the outing's start ("38 min", "1 h 20 min"). This is the A1 board layout with "{Place} in" instead of "Leave in" and no "On time" line. Otherwise: the Next row without the time left.
  - Kid B block unchanged.
  - **Panel fit** (board A1m; 2026-11-08): the panel is the column x 928–1312, y 96–968. Stack from the top: weekday head 36, 24; Kid A face row 48; 24; "{Place} in" row 72 (the 80 way picture may stand 8 above the row); 8; "38 min" display 96 (line height 1.0, so the box is 96 tall, not 115); 64; Kid B face row 48; 24; now/next row 160 + 8 + caption. That ends at about y 650. "Missions →" (96) is pinned to the panel bottom (968) by flexible space, so about 220 pt are free. Nothing should move the home up: check line heights first (display and title boxes use line height 1.0–1.15, not the font's default), and never let the panel grow the screen. If a longer case still does not fit, shrink in this order: the flexible space down to 24, then the Kid B gap 64 → 40. The clock never moves.
  - After 12:00 pm the panel goes back to the "Now and next on home" rule and the button hides. On a bus morning with live times the Kid A block shows "Leave in" + "On time" instead (see "A2 live look").

### States
- Weekend or holiday → E3 layout. One child → E1 layout.
- Kid B has no slot now: the "now" circle shows the play picture with caption "now"; if nothing is next, the "next" circle is not shown. [proposed]

---

## A2 · Morning: missions and the way there (new 2026-11-08) [boards A2t, A2t-w (timetable look), A2 (live look), A3 (done), A2m (many missions)]
One morning screen. Its strip region has two looks: the **timetable look** (this section: car, taxi, on foot, and the bus when there are no live times) and the **live look** (the bus with live times, see "A2 live look" below). Going somewhere is the point of the morning, so the top shows the way there (user, 2026-11-08).
- **Header** (48–128): `RoundButton` 80 with `MarkerGlyph.chevronLeft` 40 → home; "Good morning!" title 48; right: "{Place} in" (body, `softText`) + "{n} min" (title 48), counting to the start of the next outing.
- **Way strip** (x 64–1312, y 176–516; boards A2, A2t, A2t-w, A3; the first design, back by user request 2026-11-08): a straight crayon road with our stop and home in the middle and the destination on the right. Reference: `handover/crayon-ui-ref/way-strip.js` → `svg/way-bus.svg` (with stops), `svg/way-car.svg` (no stops). Coordinates are in the strip's own frame (0–1248 × 0–340). Everything is one `CrayonKit` `WayStrip` view except the home, destination and mover pictures (`KitIcon`s). No new kit slot.
  - **Layers, back to front**: ground → trees → stems → road → stops → pictures → labels → movers and bubbles → legend or card.
  - **Ground**: crayon rounded rectangle (4, 4, 1240 × 332, radius 36), fill #D6ECC3 (wash 0.22, hachure −35°, gap 12), marker edge 4 ink.
  - **Trees**: four lollipop trees, crown (crayon #3FAE5A, hachure −40°, gap 4, marker 4 ink) on a trunk (marker 5 ink, from the crown centre + r − 4 down 22): (745, 150, r 26), (1010, 120, r 24), (300, 300, r 20), (980, 300, r 22).
  - **Road**: straight, y 240 from x 28 to 1220. Two strokes, round caps, one pass each: ink #1E1B22 28 wide (roughness 1, bowing 0.6), then green #3FAE5A 17 wide on top (roughness 1.3).
  - **Our stop / home** at x 860, **destination** at x 1150. Each stands on a dotted stem that starts at the top edge of its stop marker and runs 32 up (marker 5 ink dashes 5 long every 10); the picture's drawn bottom (opaque bounds, not its box) sits on the stem top. Home picture 150 (`home`; the canvas shows the private drawing), destination picture 120: `wolfie` for school, the flag school for weekend school, `actChurch`, `actSwim`, …
  - **Stops**: home stop = white r 28, marker 6, ink dot r 11. Destination stop = white r 15, marker 4.5. By bus, three stops before ours at x 170, 380, 620 (white r 15, marker 4.5). By car, taxi or on foot: no stops.
  - **Labels** (caption 24 bold, `ink`, centred on the stop, top at y 274): "Our stop" by bus, "Home" otherwise; the place name under the destination. A label that would cross the strip's right edge (x 1232) is right-aligned to it ("Weekend school").
  - **Timetable look, mover** (no live times):
    - By bus: one bus (120, no number) on the road before our stop at x = 860 − min(minutes to "leave", 30) × 800 / 30 (30 min or more sits at x 60); it reaches our stop at "leave". Box bottom at y 260.
    - By car, taxi or on foot (car or taxi 104, `shoe` 96): waits right of home at x 990 until "leave", then moves linearly to x 1070 at the start time. Box bottom at y 260.
    - It rocks as on A2 (Reduce Motion: still).
  - **Timetable look, card**: `CrayonCard` with the outing owner's `KidFace` 40 (gap 16), "{Place} at {h:mm am}" (head 36) over the way line (caption): "by bus · timetable", "by shuttle · timetable", "by car", "by taxi", "on foot". At (236, 38) by bus, (56, 30) otherwise; never over a picture or the mover.
  - **Empty look** (no outing left for any kid): ground and trees only, no road; home picture 150 in the middle (x 624) on its own short stem; `CrayonCard` "Home all day" at (120, 38), no face.
  - **Whose outing** (changed 2026-11-08, user: the road should not vanish when Kid B is chosen): the strip and the header countdown show **the family's next outing**: the earliest slot or item today, of any kid, that has a trip and has not started. It stays the same whichever kid is chosen (a younger kid goes along to the stop, so the morning has one road). "leave at {h:mm am}" next to the chosen kid's name shows only when the chosen kid has their own outing left today; otherwise nothing is there. No outing left for any kid today: the header countdown is empty and the strip region keeps its place and size (Fixed regions) with its **empty look** (see "Way strip") [proposed]. The kids and missions stay at 536–968.
- **Kids and missions** (536–968): the A2 family layout. Kid list on the left (`CrayonRing` 76 + face, `KidBand` on the chosen kid), the chosen kid's name + "leave at {h:mm am}" and one row of 112 mission circles on the right (6 a kid; fold / "+n" rule of A2m beyond that).
- **All done!** (bottom right, 96 tall, at least 400 s wide and as wide as its title needs, so "Back to the clock" fits at head 36; `KidPillButton` in the chosen kid's colour, star sticker 56): always active; missions help but never lock it. Tap: the kid's row turns "Ready!" (full ring, check badge, no medal), crayon confetti (Reduce Motion: none), then the next unfinished kid is chosen. Everyone ready: the button reads "Back to the clock".
- **Presentation**: A2 opens over home as a full-screen cover, not on the grown-up stack (no relock, no app-switcher hiding). Ways out: "←" and "Back to the clock". (Main session's call, accepted 2026-11-08.)
- **Folded and "+n" circles** (board A2m): the folded circle is the kid's 112 crayon circle with the done tick, caption "{n} done". The "+n" circle is **also the kid's crayon circle** (not paper), "+{n}" title 48 bold, caption "{n} more"; tapping it turns the page. On the last page that place holds the back circle: the kid's crayon circle with `MarkerGlyph.chevronLeft`, caption "Back"; tapping it returns to the previous page (with at most 8 missions that is page 1).
- **Tapping a mission** toggles it (undo allowed); the check draws itself in 0.35 s (Reduce Motion: appears).
- **Spoken times** (all screens): `TimeLeft` speaks full words, not the shown text: "38 minutes", "1 hour 20 minutes", "1 minute".
- **VoiceOver**: the strip reads "Kid A's way to school, by bus, 38 minutes, school starts at 7:30 am"; kid rows are tabs; missions are toggles.
- **Live look**: on a bus morning with live times the same region shows the live look (below); the timetable look is its fallback.


### Morning data: missions, trips, done state (2026-11-08) [proposed]
- **Missions**: `Mission { id, kid, name, picture: KitSlot, order }`. Morning only, at most 8 per kid, kept in the local store with the schedule.
  - The circle caption is the name itself: caption 24, centred under the circle in a label as wide as the circle's column (pitch 136 s, never under 112), **up to two lines**, broken between words; "…" only if it still does not fit after two lines. The first mission not done is bold. C5 limits a name to 14 characters, which fits two lines at 24 on every iPad. Never shrink below 24.
  - Seed Kid A: Wake up (`sun`) · Brush teeth (`toothbrush`) · Get dressed (`shirt`) · Breakfast (`actBreakfast`) · Pack bag (`backpack`) · Shoes on (`shoe`).
  - Seed Kid B: Wake up (`sun`) · Milk (`babyBottle`) · Shoes (`shoe`).
- **Trip** (what makes something an outing): an optional `Trip { way, leaveBefore }` on a template slot, an every-week item or a just-once item. **An outing is anything with a trip**; the picture or the name does not decide it.
  - `way`: walk, bus, car, taxi, and shuttle (shuttle stays hidden until N1b). Mover picture: walk `shoe`, bus `busDouble`, car `car`, taxi `taxi`, shuttle `busShuttle`.
  - `leaveBefore`: minutes, 0–90 in steps of 5. leave = start − leaveBefore. The clock still draws the slot or item from its start; the start is the time at the place.
  - Seed: Kid A School slot (Mon–Fri) bus, 5 → "leave at 7:25 am". Kid A Weekend school (Sat) car, 25 → "leave at 8:35 am". Kid A Swimming car, 10. Art club, Birthday and all of Kid B: no trip.
  - Editing trips: C1 "Getting there" → C2 for the bus, and the "Going" row on C3/C4/E5 (below). Until those are built, trips come from the seed; an item without a trip shows no strip.
- **Done state**: per kid **per date**: `{ kid, date, doneMissionIds, ready: Bool }`, in the local store. A new date starts at **midnight**, like the clock, so every morning starts empty. Keep 14 days (N2 medals and the M5 diary can read it later); drop older ones. Renaming a mission keeps its done state (it is keyed by id); removing it drops it.
- **Entry**: home "Missions →" in the mission morning (A1 above). Grown-ups reach C5 from C1 "More → Morning missions" (Kid A) and E6 "Cards" (Kid B).

### A2 live look: the bus with live times (new 2026-11-08) [board A2; A3 for the done state; C2 for settings]
The same screen with live bus arrivals: same fixed regions, same kids-and-missions block; only the strip region, the header right and the bottom control change. Shuttle (A2s), crowding, the plan B buses (A2b) and the plan B screen come later (backlog).
- **When**: the family's next outing (see "Whose outing" above) goes by bus, and live times for its stop are fresh (last good answer under 2 min old). Otherwise: the timetable look, whose card line reads "by bus · no live times"; the header then counts to "leave" from the trip's "leave before" with no status.
- **Header right**: "Leave in" (body, `softText`) + "{n} min" (title 48, unit 24) + status (head 36 with a 28 dot, gap 16):
  - "On time" (`onTimeText` #17744D, green dot) while the chosen bus still reaches the place by its start.
  - "Leave now!" (`hurry`) once "Leave in" reaches 0, until the kid slides or the bus is gone.
  - When the chosen bus can no longer be caught, the next one becomes the chosen bus and "Leave in" counts to it (no "late" word, no red face). No bus reaches the place by the latest time: status "Ask a grown-up" (`softText`), no dot.
  - "Leave in" = the chosen bus's minutes to our stop − walk minutes (C2). "leave at {h:mm am}" next to the kid's name = now + "Leave in", rounded down to the minute.
- **Strip region** (176–516), live look: the same way strip (straight road, our stop and home at x 860, stops at 170, 380, 620, destination at 1150; see "Way strip" above).
  - **Buses**: the next two arrivals of the kid's bus numbers at our stop (LTA gives up to three per number). x = 860 − min(minutes, 30) × 800 / 30 (30 min or more sits at x 60); box bottom at y 260. Picture from the LTA bus type: double deck `busDouble`, single `busSingle`, bendy or mini `busMini`; 120 pt; no passengers (crowding is N1a). Wheels turn and the bus rocks as on A2 (Reduce Motion: still). Between refreshes a bus glides linearly to its new x over 1 s (Reduce Motion: jumps).
  - **Chosen bus** = the first arrival whose minutes ≥ walk minutes. Bubble (`bubble` art, 220 × 132) above it: number plate (white, 76 × 40, 30 bold) + "{n} min" (head 36, unit 24); second line `KidFace` 32 + "my bus" (caption bold). An earlier arrival that cannot be caught: the bus at 50 % opacity with a small bubble (190 × 104: cream plate + "{n} min" body bold, caption "too soon"). Bubbles sit 8 above the bus, centred on it, kept inside the strip (x 8 … 1240 − width); if the two bubbles would overlap, the "too soon" bubble is left out.
  - **Legend** at (946, 16): white plate + "my bus" (caption bold). No `CrayonCard` on the live look.
  - A bus that has reached our stop leaves the map on the next refresh.
  - VoiceOver: "Live bus map. Bus 1 in 29 minutes, your bus. Leave in 19 minutes, on time." (numbers from the data; full words, see "Spoken times").
- **Refresh**: every 30 s while the screen is open, and on open; nothing in the background. A failed call keeps the last answer until it is 2 min old, then the timetable fallback shows (no error text for kids; C2 shows the state for grown-ups).
- **Bottom control** (536–968 region, bottom 968, right-aligned 864 wide): for a kid with an outing today, `SlideToGo` 864 × 96, label "Ready? Slide to go", knob = the way picture (bus). Always awake; missions help but never lock it. A kid with no outing keeps "All done!" (above). On the timetable fallback the slide stays.
- **After the slide** (board A3): the kid's row turns "Ready! Gold" / "Ready! Silver" / "Ready! Bronze" / "Ready!" (caption bold, `onTimeText`), the medal sits on the progress ring, the header title becomes "Ready, {name}!", crayon confetti (Reduce Motion: none), and the next unfinished kid is chosen. The header keeps counting "Leave in" for the family's outing. Undo: tap the ready row, "Not yet" (one confirm), the medal is dropped.
- **Medal from the time only** (missions never count):
  - arrive-by = the outing's start (seed school 7:30 am); latest = start + late grace (C2, default 15 min).
  - L1 (ideal leave) = the leave time of the last bus (live, at the moment of the slide) whose arrival at our stop + ride minutes ≤ arrive-by. L2 = the same with latest.
  - Gold: slid at or before L1 − 5 min. Silver: at or before L1. Bronze: at or before L2. After L2: "Ready!" with no medal, never a sad face.
  - Timetable fallback: L1 = start − leave before; L2 = L1 + late grace.
- **Done state** gains `readyAt` and `medal: gold | silver | bronze | none` (per kid per date, as in "Morning data").
- **Home (A1)** on a live bus morning: the Kid A block shows "Leave in" with the 80 pt bus picture, `TimeLeft` display 96 and the status line (the A1 board look) instead of "{Place} in"; the fallback keeps "{Place} in".

### Bus settings (C2 "Our buses") [board C2; first cut proposed]
- One route per kid with a bus outing ("Plan A · usual"). The Plan B card and "+ Add a route" are hidden (plan B is Next).
- Rows: **Stop**: type the 5-digit stop code; the app shows the stop's name from the LTA stop list to confirm ("Opp Blk 123" style). **My buses**: chips of the numbers that call at that stop; pick one or more. **Walk to the stop**: −/+ in minutes (S3 stepper, default 10). **Ride**: −/+ minutes (default 10). **Late grace**: 0–30, step 5 (default 15).
- **Live bus times** row: "Add key" → a secure field for the LTA DataMall key; then "Working ✓" or "Not working · last tried 7:12 am" (caption). The key lives in the Keychain; the stop, numbers and minutes live in the local store.
- Privacy: stop codes, bus numbers and the key never go into the repo, the seed or tests (tests use made-up values such as stop "00000", bus "1").
- Entry: C1 "Getting there" (Kid A) → C2.

### Trips on items: the "Going" row [board C3g]
- C3, C4 and E5 get two rows at the end of the form, under "Skip school holidays" (the form card scrolls to them; board C3g shows it scrolled down, with the top edge fading into the card):
  - **Going** (label as the other rows): five 88 slot circles with a caption under each, gap 24: None ("–" in `softText`), Walk (`shoe`), Bus (`busDouble`), Car (`car`), Taxi (`taxi`). The chosen one has the pick-blue ring and a bold caption, like "What". Default None.
  - **Leave** (shown when Going is Walk, Car or Taxi): `−` 72 · "{n} min" (body bold, 112 wide) · `+` 72 · "before · {h:mm am}" (body `softText`, the leave time from the item's start). 0–90 in steps of 5; default 10.
  - By Bus the Leave row reads "Uses Our buses ›" (body) and opens C2: the stop, buses and walk time come from there.
- The preview line under the day list adds "Leave {h:mm am} by {way}."
- Until it is built, trips come from the seed.

## E1 · Home, one child [board]
- Same clock and hub as A1.
- Right panel: Kid A block, then **Next**:
  - Next row + time left exactly as the A1 Kid A block ("Now and next on home"). One row only (changed 2026-11-08; was 2 rows).
- No Kid B block. Main button as A1 (hidden in M2).
- Empty Next [proposed]: "Next" + "Nothing else today" (body, `softText`).

## E3 · Home, weekend or holiday [board]
- Same clock. Slots come from the **Sat** or **Sun** template. A weekday school holiday uses the **Sun** template (2026-11-08).
- Right panel (changed again 2026-11-08): **the same as A1** — Kid A block (Next row + time left, "Now and next on home"), then the Kid B block. The weekday is the panel's first line, as on A1. No "No bus today" (the line only appeared on weekends and read oddly).
  - **Weekday school holiday**: the panel's weekday line reads "{Weekday} · Holiday" (see Hub text). That is the only holiday sign on the kid screen; the clock already uses the Sun template.
  - Kid B block as A1.
- Main button "Diary →" → B2. **[later M5]**: hidden in M2.
- No item left today [proposed]: leave out the item row.

## E3b · Home, Sunday (new 2026-11-08) [board]
- Same layout as E3, with the **Sun** template; a Sunday every-week item (the board's example uses `actChurch`) sits on top in sky. The board's real times stay on the canvas only.
- Example on the board: during that item the hub shows its name / "until {end}". Kid A's Next is "Dinner · at 7:00 pm" (Play only continues after the item, so it is skipped); over 3 h away, so no time left is shown.
- The seed has no Sunday item (see Seed data), so in the app the seed Sunday shows the plain Sun template until a grown-up adds one.

## A1n · Home at night: the night look (new 2026-11-08) [board + proposed]
Applies to the kid screens of M2 (A1, E1, E3, E3b). Board A1n shows A1 at 7:40 pm.
- **When**:
  - Kid screens switch to the night look at the start of the kid's **evening routine** (the first evening-routine slot of the day's template, 19:15 in the seed).
  - They switch back at the kid's **wake-up**.
  - The change is a 2 s crossfade, never a flash.
  - Grown-up screens follow the iPad's own light/dark setting instead.
- **Colours** (contrast on #22213A):

  | role | colour | contrast |
  |---|---|---|
  | page | `night` #22213A | — |
  | text | `nightText` #F4EFFF | 13.8:1 |
  | soft text | #C9C3E0 | 9.2:1 |
  | Kid A dot | #56B4E9 | 6.8:1, non-text |
  | Kid B dot | #E69F00 | 6.9:1, non-text |
  | link | #56B4E9 | — |

  - The night kid colours and the chalk outline already exist as the B1 night parts.
- **Clock**:
  - The disc keeps a **lit paper face** (#EFE8D8) under the slots, so the crayon colours read as by day. It is not dimmed.
  - Hour ticks and hour numbers turn chalk: #F4EFFF for the 12/6 labels, #C9C3E0 for the rest.
  - The hub stays white with ink text.
  - The red hand is unchanged.
- **Kit pictures off the clock** sit on a paper plate: a 104 circle in #FBF8F1 with a 3.5 pt chalk ring. Their black outlines need a light ground.
- **Main button**: chalk fill (#F4EFFF) with `night` text. It is the inverse of the ink button.
- **Right panel at night** (board):
  - Kid A: "Bed in" (body, soft) and `TimeLeft` display 96 "20 min" until bedtime.
  - Then a "Tomorrow" row: plated 64 picture, "Tomorrow" (body bold) over "School, leave {h:mm}" (caption).
  - Kid B: now/next circles as by day; next = wake-up (sun).
  - Button "Diary →". **[later M5]**: hidden in M2, as by day.

## Sky switch: the kid's day/night switch (new 2026-11-08) [board 0g, on A1 and A1n]
- On every kid home screen (A1, E1, E3, E3b): top-left of the clock area at x 40, y 36, 160 × 96. That is clear of the hour labels and is a ≥ 96 pt target.
- **Looks**: `SkySwitch` shows kit slots `skyDay`, `skyDusk` and `skyNight` with `KitIcon` (5:3 pills in the 240 box, aspect-fit into 160 × 96):
  - day: a sky pill with a smiling sun on the left and a cloud
  - mid: a sunset pill with the sun half down in the middle (used during the animation)
  - night: a navy pill with a sleepy crescent moon on the right and three stars, with a chalk outline for the dark page
- **What a tap does**:
  - It swaps the look between day and night. It never changes the clock, the plan or the time.
  - The swap lasts until the next planned change (night at the evening routine, day at wake-up), which clears it.
  - One tap is one change; taps during the animation are ignored.
- **Animation, day → night, 1.2 s**:
  - 0 ms: soft haptic.
  - 0–300 ms: the sun rolls right and sets, and the pill turns sunset, then navy.
  - 300–900 ms: the night colour spreads over the page as a circle growing from the switch. The clock face stays lit paper.
  - 900–1200 ms: three stars pop in (staggered 80 ms) and the moon blinks once. Success haptic at the end.
  - Night → day reverses it: the moon rolls left, the sun rises with one ray spin, stars fade, and day spreads from the switch.
- **Reduce Motion**: a 0.3 s crossfade between the two looks, with no wipe and no popping.
- Grown-ups can hide the switch (a C1 setting, "Day/night switch", on by default) [proposed].
- Accessibility: a button labelled "Day. Tap for night." or "Night. Tap for day.".

## Motion: every moment (new 2026-11-08) [board 0g2]
| moment | what moves | time | Reduce Motion |
|---|---|---|---|
| Sky switch | as above | 1.2 s | crossfade 0.3 s |
| New slot | the slot picture hops 1 → 1.15 → 1; hub text slides up | 0.4 s | text changes in place |
| On the hour | the red hand disc pulses once | 0.6 s | none |
| Mission done | the check draws itself, 6 crayon sparks | 0.35 s | check appears |
| Slide to go (build step 5) | bus wheels spin while dragging; a hop and a green wash at the end | while dragging | colour change only |
| Gold (M3) | medal drops in and swings, crayon confetti | 1.5 s | medal fades in |
| Living lines (later, ST-8) | outlines redraw in 3 frames at 6 fps, celebration screens only | 2 s | still |
| Idle wink | after 20 s without a touch, the sun or moon picture on the clock blinks | 0.3 s | none |

- In M2: Sky switch, New slot, On the hour and Idle wink. The rest belong to the milestone of their screen.

## Picture rigs: tap a slot, its picture plays (new 2026-11-08) [board 0g3 / 0g3b, approved by the user 2026-11-08; shipped at scale 1.5]
- Tapping a slot on the kid clock (A1, E1, E3, E3b) plays that slot's picture once: ≤ 1.2 s, then still. A second tap during the play is ignored.
- **Rules**, so nothing looks strange:
  - Only rigid parts move: a part is rotated or moved whole, never bent or stretched.
  - Faces move only with their head part; eyes may blink once.
  - Rotation ≤ 15°; movement ≤ 20 units in the 240 box.
  - Pivots sit where the part is attached (flag on the pole, spoon at the handle end, arms at the shoulders).
- **Data**: inside kit.js (`RIGS`), so `make art` writes it as `KitRigs.dataset/rigs.json`. For each slot it lists parts (kit layer indices), a pivot, and moves from a small set: hop, rock, bob, slide, spin, rise, fall, press, blink, flicker, twinkle.
  - 18 slots have rigs.
  - Any other slot gets "hop": up 14 and down, with a 5 % squash on landing.
- **Pipeline**:
  - For each rigged slot, `make art` splits the picture into ordered **runs** (consecutive layers that belong to the same part, or to no part). It writes one imageset per run, named `rig-<slot>-<n>`, drawn with the same seeds. Stacked in order, the runs equal the normal picture exactly; this is checked for all 18.
  - `rigs.json` lists, per slot, `runs` (`{image, part}` in draw order, `part: null` = still), and `parts` (`{origin, moves}`).
  - The app stacks the runs and animates every run of a part with that part's moves.
  - The dancer's head part has two runs (hair behind the arms, face in front), which move together.
- **Size**:
  - The user liked the motion and wants to try bigger moves. Board 0g3b shows every move × 1.5 (≈ 21°, ≈ 27 units).
  - The user checked × 1.5 and finds it fine, so `rigs.json` ships `"scale": 1.5` (≈ 22° / 30 units at most). The app multiplies rock/bob/slide/rise/fall/press/hop amounts by it.
  - Keep the **debug-menu slider "Rig scale" (1.0–1.5)** for checking on the iPad; its default is the value from rigs.json.
- **Reduce Motion**: no movement; the slot's outline thickens for 0.3 s instead.

## B2n · Diary at night (new 2026-11-08) [board, M5]
- The paper page stays paper with ink text. Only the page around it turns night: header, the "This week" list text and the league text.
- Today's row keeps its white card with ink text. Kid dots use the night colours.
- Recorded here so M5 starts from it; not built in M2.

---

## C0 · Grown-up lock [board + proposed details]

### Entry: hold the clock for 2 s
- The long-press starts on the clock disc only (not the right panel).
- Feedback while holding [proposed]:
  - An ink ring 8 pt grows around the hub, from 0° to 360°, over 2 s (r 160).
  - A light haptic at the start and a success haptic at 2 s.
- Releasing before 2 s drains the ring back in 0.2 s; nothing else happens.
- At 2 s: the dim overlay appears and Face ID starts at once.

### Layout [board]
- Overlay: marker colour #1E1B22 at 60 % over the home screen. The home stays visible underneath.
- Line above the card: "Held the clock for 2 seconds" (body, `nightText`), centred, y 248.
- Card: `PaperCard`, 818 × 352, centred horizontally, y 320. Padding 40 × 64, gap 24.
  - Lock icon + "Grown-ups only" (title 48).
  - Message line (body).
  - Buttons row, gap 24: `RoundButton`-style tabs 240 × 72.
- The caption under the card on the board ("Opens C1 · Our kids. Locks again after 2 minutes.") is a design note, not UI text.

### Face ID only
- Use `LAContext` with `.deviceOwnerAuthenticationWithBiometrics`.
- Set `localizedFallbackTitle = ""` so the system sheet shows no passcode button.
- On iPads with Touch ID, the same flow says "Touch ID" (read `biometryType`).

| state | message line | buttons | next |
|---|---|---|---|
| scanning | "Look at the iPad to unlock." | "Cancel" | success → C1 |
| not recognised (system gave up) | "That didn't unlock." | "Try again", "Cancel" | Try again → scan |
| cancelled by the user or the system sheet | — | — | overlay closes, back to home |
| Face ID not set up / not available | "Face ID is off on this iPad. Turn it on in Settings to open grown-up screens." | "Open Settings", "Cancel" | Settings app |
| locked out (too many tries) | "Too many tries. Unlock the iPad with its passcode, then try again." | "OK" | back to home |

- The board's "Use passcode" button is removed (Face ID only).

### Relocking after 2 minutes [proposed]
- Grown-up screens stay open while they are used. After **2 minutes without a touch**, the app returns to the home screen; the next grown-up entry needs Face ID again.
- From 30 s before that, the header caption "Grown-ups only" changes to "Locks in 0:30", counting down in `hurry` colour.
- Any touch resets the timer and restores the caption.
- Unsaved form changes are discarded on relock; this is the only exit without the "leave without saving?" question.
- Backgrounding the app also relocks at once.

---

## C1 · Our kids, Kid A [board]

### Layout
- `GrownupScreen`. Header row at x 64, y 48, h 80, gap 24:
  - `RoundButton` "←" 80 → home.
  - "Our kids" (title 48).
  - `CrayonTabs` with Kid A and Kid B, each 200 × 72 with its `KidFace` 40. Exactly one is on.
  - "Grown-ups only" caption at the right end.
- Left: `PaperCard` columns 1–8, y 176–968. **This card scrolls; the header and tabs stay pinned (0f).**
  - Section headings at x 104 (head 36): "About", "School", "Getting there".
  - Rows: `ListRow`, 60 tall (72 for the day chips row):
    - key in the left column (body `softText`, w 160)
    - value (body)
    - optional "›" at the right (only on rows that open something)
- Right: side column, columns 9–12, from y 176, gap 8. Scrolls with its own content if long.

### Rows (Kid A)
- **About**:
  - "Age" → "{age} · {school year}".
  - "Day" → wake picture "Up {h:mm} · " + sleep picture "Bed {h:mm}", "›" → **C6 Our day**.
- **School**:
  - "School" → school picture + school name (from settings).
  - "Days" → seven read-only `DayChip` 56 (on = school day).
  - "Hours" → "{start} – {end}" in "h:mm am" form.
  - "Holidays" → "Term {n} ends {Day d Mon}" or "No holidays set", "›" → C7 (later; hidden in M2).
- **Getting there** → C2 (build step 5, with the live bus); hidden until then.
  - "To school" → bus picture, bus plate, "leave about {h:mm} · in by {h:mm}", "›" → C2.
  - "Home time" → "{h:mm} · pick-up at the gate", "›" → C2.
- **More** (board, 2026-11-08): "Morning missions" → "{n} missions" ("1 mission"; "Nothing yet" at 0), "›" → **C5** with this tab's kid; shown from build step 5. "Drawings" → "ask for a picture", "›" → D1 **[later M6]**: hidden.

### Side column
- "After school" (head, h 52), then one `ListRow`-style item per every-week item:
  - 56 picture, title (body) over "{days} {start}–{end}" (caption), "›" (body `softText`).
  - Tap → **E5** for that item.
  - Days text: "Mon · Wed"; all weekdays → "Every school day".
- "Add every week": 56 plus-picture + link text (body, `link`) → **C3** with "For" set to this tab's kid.
- "Just once" (head, h 52), then upcoming just-once items for this kid, nearest first, at most 5. Each shows "{Day d Mon} · {start}–{end}". Tap → **C4 in edit mode** (see C4).
- "Add once" link → **C4**.
- Caption: "Everything here feeds the clock, the morning bus and the diary."
- Empty lists [proposed]: under the heading, "Nothing yet" (body `softText`), then the add link. Same as E6.

### States
- Seed data cannot fail to load, so there is no loading screen. If storage fails to save, see C3 errors.

## E6 · Our kids, Kid B [board]
- Same screen with the Kid B tab on.
- **About**:
  - "Age" → "{age} · at home".
  - "Day" → nap picture "Nap {start}–{end} · Bed {h:mm}". **[later M4]** editing.
- **Nursery**:
  - "Nursery" → "Not yet" (`softText`).
  - Next row: link "Add when they start" → S2. **[later M4]**: hidden in M2.
  - Use "they" in public copy.
- **Morning**:
  - "Cards" → "Wake up · Milk · Shoes" ("Nothing yet" when empty), "›" → C5 with the Kid B tab. Shown once missions are built; hidden before.
  - "Taps" → "A grown-up taps for now".
- Side column: "Every week" with "Nothing yet" when empty, "Add every week", then "Just once" with items and "Add once". Same rules as C1.


## C5 · Morning missions (grown-up editor) [board C5, details proposed]
- `GrownupScreen`. Header: `RoundButton` "←" 80 → C1 (or E6), "Morning missions" (title 48), kid `CrayonTabs` (Kid A, Kid B with `KidFace` 40) at the right.
- Left: `PaperCard` columns 1–8, y 176–968:
  - Caption "Same order as {Kid}'s morning screen".
  - One row per mission, 72 tall, divider lines: drag handle `MarkerGlyph` ≡ (soft), `KitIcon` 48, name (body), "›" (body `softText`). Drag ≡ to reorder; the order is the circle order on A2t.
  - "+ Add a mission ({n} of 8)" (`MarkerGlyph.plus` in a 40 ring + body `link`). At 8 the row is replaced by "8 is the most" (caption).
  - Footer caption: "Drag {handle} to change the order. Tap a row to rename it or change its picture. Up to 8 fit on the morning screen; fewer is easier." {handle} is `MarkerGlyph.handle` drawn inline at the text size (24, `softText`), the same rule as inline arrows; never the ≡ character, which Playpen Sans lacks.
- Tap a row or "Add" → a `ConfirmCard`-style editor, **centred over a dimmed screen** (tapping the dim area cancels without saving; main session's call, accepted 2026-11-08): Name `CrayonField` (max 14), `IconPicker` (kit pictures, no "+" until M6), "Remove" (`lateText`, edit only; asks "Remove {name}?" / "Remove" / "Keep") and "Save" (`InkButton`). A new mission defaults to `star` and an empty name; Save is off while the name is empty.
- Right column (cols 9–12): Kid B note "Picture cards. A grown-up taps them for now." (on the Kid B tab) and "Evening · coming later". The board's "Ready by" block is **N2** (hidden).
- Main button "Done" → back. Changes save at once and show on today's morning screen; done marks of kept missions stay.

---

## C3 · Add to the day, every week [board]

### Layout
- `GrownupScreen` header:
  - `RoundButton` "←" 80.
  - "Add to the day" (title 48).
  - Caption "Grown-ups only · behind the parent lock".
- Form card rows (label at x 88, control at x 232, tops given):

  | y | label | control |
  |---|---|---|
  | 200 | For | `CrayonTabs` single-select, 3 options of 180 × 72: Kid A, Kid B (each with `KidFace` 40), "Both" |
  | 296 | What | `IconPicker`: slots 88 with gap 16. The picked one gets a 104 ring. The last slot is "+". |
  | 412 | Name | `CrayonField` 610 × 80 |
  | 524 | When | `TimeField` 200 × 80, "→" (head `softText`), `TimeField` 200 × 80, then the duration caption ("1 hour", "1 hr 30 min", "45 min") |
  | 636 | Repeat | `CrayonTabs` 2 options of 220 × 72: "Just once", "Every week" (on) |
  | 732 | — | seven `DayChip` 72, multi-select, M T W T F S S |
  | 836 | — | `CheckMark` 48 + "Skip school holidays" (body) |

  - What: the "+" slot asks for a drawing (D1). **[later M6]**: hidden in M2.
  - What: the picker slides sideways when the kit grows (0f).
- Side column:
  - Preview heading "{Kid}'s {weekday}" (head, h 56), e.g. "Kid A's Monday". The weekday is the first picked day. For "Both", the heading is the weekday only.
  - `TodayRow`s, 72 tall: start time (caption `ink`, w 72), 48 picture, title (body).
  - The new item's row uses the today style (paper card + bold) and sits in time order.
  - Summary caption: "On the clock every {Monday and Wednesday} from {d Mon}."
    - Day lists: "Monday", "Monday and Wednesday", "Monday, Wednesday and Friday", "school day" (Mon–Fri).
- Main button: `InkButton` "Add to the clock".

### Defaults when opened [proposed]
- For = the kid of the C1 tab (Kid A from home).
- What = none picked. Name empty.
- When = the next full hour, for 1 hour.
- Repeat = Every week. Days = today's weekday. Skip school holidays = on.
- Picking a picture fills an empty Name with that picture's label ("Swim" → "Swim"). It never overwrites a typed name.

### Transitions
- Repeat → "Just once" switches the same screen to the C4 layout. Values kept: For, What, Name, When.
- "Add to the clock" → save, pop back to the screen that opened it (C1 or home). The new item appears there and on the clock.
- "←" with changes → confirm (`PickerPopover`-style small card pointing at "←"):
  - title "Leave without adding?"
  - buttons "Keep editing" / "Leave"
- "←" without changes → back at once.

### Validation [proposed]
- The button is disabled until valid. The first problem shows as a caption in `lateText` under its row:
  - Name empty: "Give it a name"
  - End not after start: "Ends before it starts"
  - No day picked: "Pick at least one day"
- **Overlap** with another item for the same kid: caption (not blocking) under When, in `softText`: "Overlaps {Name} {start}–{end}. This one shows on the clock then."
  - The new item wins only if it has higher priority (section 0); otherwise the caption says "{Name} shows on the clock then."
- **Save failed** (storage error): the button stays, and a caption under it in `lateText` says "Couldn't save. Try again." Nothing is lost from the form.

## C4 · Add to the day, just once [board]
- Same header and form as C3, with:
  - Repeat → "Just once" on.
  - At y 732, a row of `DateChip` 96 × 104 instead of day chips: weekday (24 `softText`) over date number (36 bold). One date picked.
    - Shows 5 dates starting today; "‹ ›" buttons 80 page by one week (0f).
    - Past dates are not shown.
  - At y 864: `CheckMark` 48 + "A star on the clock that day" (body). On by default for events. It adds a star picture at the slot on the clock.
- Side column:
  - Heading "{Weekday d Mon}" (head), e.g. "Saturday 14 Nov".
  - Caption "Just this day, for {Kid A | Kid B | both kids}. It leaves the clock at midnight."
  - `TodayRow` preview of that date for the chosen kid (Kid A for "Both"), the new item in today style.
- Main button "Add to the clock".
- **Edit mode** (opened from a just-once item in C1/E6) [proposed]:
  - Title "Edit {Name}". Main button "Save changes".
  - Under the preview, a row button 88 tall "Remove {Name}" in `lateText` bold.
    - Confirm: title "Remove {Name}?", body "It leaves the clock on {Weekday d Mon}.", buttons "Remove" (`lateText`) / "Keep".
- Validation and errors as C3, without the day rule. A start time already past today: "That time has passed" (blocking).

## C3k · Add, keyboard open [board]
- When a text field has focus, the iPad keyboard covers about y 612–1032 (≈ 420 pt in landscape).
- The form card shrinks to 818 × 352 at y 176 and becomes a scroll area. It keeps the field with focus in view.
- Inside it, rows are tighter: label at card x 40, controls at card x 168, rows at 20 / 136 / 248 / 360.
- Focus: the focused field gets the blue focus outline (`pickBlue`, 610 wide) and a 3 × 36 caret in `pickBlue`. Its label turns `pickBlue`.
- Side column: the preview heading only; the rows are hidden.
- "Add to the clock" moves up to y 488 (bottom 584, 28 above the keyboard). It is the only control that moves.
- Keyboard return on Name = dismiss keyboard (not submit).

## E5 · Edit an every-week item [board]

### Layout
- Header title "Edit {Name}". Caption "Grown-ups only · behind the parent lock".
- Form: the same rows as C3 with the item's values. Repeat stays "Every week"; turning it to "Just once" is not offered here. [proposed]
- The **"Skip school holidays"** checkbox is in the form, under the day chips (y 836). It applies to the whole series and is saved with "Save changes".
- Side column, gap 16:
  - "Every {Mon and Wed}" (head).
  - "Changes start from the next one." (caption).
  - Row button 88: "Skip just {Day d Mon}" (body). The date is the next occurrence not yet ended.
  - Row button 88: "Remove every week" (body bold, `lateText`).
  - Caption: "Removed by mistake? Add it back from Our kids."
- Main button: `InkButton` "Save changes".

### Skip just one vs remove

| | Skip just {date} | Remove every week |
|---|---|---|
| what it does | adds one exception date; that day the item is not on the clock | ends the series; no future dates |
| scope | that one date | every date from the next occurrence on |
| past days | untouched | untouched (diary keeps them) |
| reversible | yes, in place | no undo; re-add with "Add every week" |
| confirm | none | yes |

- **Skip just {date}** [proposed]: tap → the row turns into "Skipped {Day d Mon} · Undo" (Undo in `link`). Undo removes the exception. It is saved at once, without "Save changes".
  - If the next date is already skipped, the row offers the date after it.
- **Remove every week**: confirm card pointing at the row.
  - Title: "Remove {Name} every week?"
  - Body: "It leaves {Kid A}'s clock from {Day d Mon}. Days before stay in the diary."
  - Buttons: "Remove" (`lateText` bold) / "Keep".
  - After Remove: pop back to C1; the item is gone from the list.
- **Save changes** (agreed 2026-11-07): if today's occurrence has already started (or finished), the old series ends today and a new series with the edits starts tomorrow. Otherwise the edits apply to the series at once, today included.
  - Skip exceptions dated after today move to the new series.
  - C1/E6 show one item, the new series. The old one only lives on in past days (diary).
- "←" with unsaved edits → "Leave without saving?" with "Keep editing" / "Leave".
- Validation and errors as C3.

---

## Navigation summary (M2)

```
A1/E1/E3 home --hold clock 2 s--> C0 lock --Face ID--> C1 Our kids (tab Kid A | Kid B = E6)
C1/E6 --"Add every week"--> C3 --Repeat: Just once--> C4
C1/E6 --"Add once"--> C4
C1/E6 --every-week item--> E5
C1/E6 --just-once item--> C4 (edit mode)
C3/C4/E5 --save / remove--> back to C1/E6
any grown-up screen --2 min idle or app backgrounded--> home
```

## New parts for M2 [proposed]
- `PieClock` (the A1 disc). Inputs:
  - slots: start, end, kind, picture, isCurrent
  - now
  - hold progress 0–1 for C0
- `ClockSlot` colour tokens (table above). They extend `CrayonPalette`.
- `KidNowNext` (Kid B's 160 "now" circle and 104 "next" circle with captions).
- `KidFace` (2026-11-08, replaces `KidDot` everywhere a kid is named; the only colour-only circles left are the S1 colour swatches):
  - Layers: a `CrayonKit` crayon ring in the kid's colour (the same Shape as the progress ring at 100 %, stroke about 9 % of the box, fixed seed per kid), then the kid's face `KitIcon` centred at **86 %** of the box (the face drawing fills about 68 % of its own box, so it nearly fills the ring without touching it). The ring is a UI shape, so it is drawn in code like every other crayon UI part (roadmap rule); only the face is a kit picture.
  - Face source: a new `Kid.face: KitSlot`, seed Kid A = `kidGirl`, Kid B = `kidBoy`. S1 (M4) sets it ("Girl face" / "Boy face"); M6 can swap in the kid's own drawing later, same slot.
  - Size = the line height of the text beside it, rounded up to the 8 pt grid: **48** beside head 36 (home names, panel headers), **40** beside body 30 (tabs, rows, fields), **32** beside caption 24 (bubbles). Gap to the name: 16 beside a 48 face, 8 beside 40 / 32 (space tokens). Ring stroke is part of the picture (about 9 % of the box).
  - Kid list chips (A2 family layout): the 76 progress ring takes the place of the colour ring, with the face at the same 86 %.
  - Night: same pictures. The ring colours are the night-safe pair already (#56B4E9 / #E69F00, ≥ 6.8:1 on `night`).
  - Accessibility: one element, label = kid name; the face picture is decorative.

### CrayonKit UI parts added on the boards (2026-11-08)
UI shapes are drawn in code by `CrayonKit` (roadmap rule); only pictures are kit SVGs. Common rules: marker stroke = one wobbly pass (seeded, same look every time), round caps and joins; crayon fill = 30–35 % wash + hachure (gap 4–6, weight 2.2–2.6). Stroke widths stay fixed when a part is resized. Look reference (scripts + SVGs, not assets): `handover/crayon-ui-ref/` in the design session folder.

| Part | Geometry (in its own box) | Stroke | Colours | Sizes and use | Phase |
|---|---|---|---|---|---|
| `MarkerGlyph.chevronLeft` | 48 box: M30 10 L16 24 L30 38 | 5 | ink | back button (inside `RoundButton` 80): 40 | M2 |
| `MarkerGlyph.chevronRight` | M18 10 L32 24 L18 38 | 5 | soft #625D6E | row end "›": 28 | M2 |
| `MarkerGlyph.arrowRight` | M10 24 H38 M26 12 L38 24 L26 36 | 5 | white on ink buttons, ink or soft in text | "Missions →", "Next →": 32 after the label, gap 12; inline arrows at the text size (24 / 30 / 36) | M2 |
| `MarkerGlyph.plus` / `minus` | M24 10 V38 M10 24 H38 / M10 24 H38 | 5 | ink | stepper buttons: 40 | M2 (C3, C4) |
| `CrayonRing` (progress) | circle r 0.43 of the box | track 0.08 (paper-beige #E2D9C6); arc: wash 0.10 at 35 % + line 0.07 | kid colour | 0–100 % from 12 o'clock clockwise; kid chips 76 | M3 (missions) |
| `KidFace` ring | `CrayonRing` at 100 %, seed per kid | as above | Kid A #56B4E9, Kid B #E69F00 | see `KidFace` | M2 |
| `KidBand` (chosen kid) | rounded band r 28 with a 14 pt notch, notch toward the content it controls | soft edge line 3 in a darker tint | wash + hachure in the kid's light tint (Kid A #BFE3F7 / edge #8CCBEE, Kid B #FCD9A6 / #F2B35E) | 340 × 100 kid row (A2 family layout) | M3 |
| `NumberPlate` | rounded rect r 8 | 3 | ink line; fill white (my bus) or cream #FFF0BF (other buses) | bus numbers 64 × 36 (52 for two digits, 76 × 40 in the big bubble) | N1 |
| `CrayonCard` | rounded rect r 18 | 3.5 | ink line, white fill | small floating cards, e.g. "Shuttle at 7:20 am" | N1 |
| `CrayonPill` (status) | rounded rect r = h/2 | 3 | ink line, white fill | status chips, e.g. "Timetable times · live times are off" (48 tall) | N1 |
| Colour swatch | circle r 24 in 56 | 3 | crayon fill in the colour, ink line | S1 colour picker only | M4 |

Small marker icons that were inline SVG on the boards are now marker-drawn too: search (S3), drag handle ≡ (C5, soft), clock (E4), lock (S4, yellow crayon body). They are `MarkerGlyph` cases in the same style.

- `ConfirmCard`: small `PaperCard` with title (head), body, and two buttons, the destructive one in `lateText`. It points at the control that opened it, like `PickerPopover`.
- `LockOverlay` (C0 overlay and card with the state table).
- Everything else uses M1 parts:
  - Screens: `KidScreen`, `GrownupScreen`
  - Controls: `CrayonTabs`, `DayChip`, `DateChip`, `CrayonField`, `TimeField`, `IconPicker`, `CheckMark`, `InkButton`, `RoundButton`
  - Content: `ListRow`, `TodayRow`, `PaperCard`, `KidFace`, `TimeLeft` (M3)

---

## C6 · Our day: drag the times on the clock (new 2026-11-08) [board]

Edits a kid's **day template**: wake-up, routines, school block, dinner, shower, sleep. Opened from the "Day" row in C1/E6.
Every-week and just-once items are not edited here. They sit on top of the template on the real clock.

### Layout
- Header:
  - `RoundButton` "←" → C1.
  - "Our day" (title).
  - `CrayonTabs` Kid A | Kid B.
  - "Undo" button 182 × 72 at the right end.
- Edit clock: `PieClock` in edit mode, columns 1–8 (x 64–888, y 176–968). Centre (476, 572), R 340, hub r 130.
  - Hour labels at R + 40; ticks at R + 4…16. Same 0:00-top, clockwise rule as A1.
- Right column (columns 9–12):
  - Day-type tabs: "Mon–Fri" 150, "Sat" 110, "Sun" 110 (gap 8). Each day type has its own template, so Saturday and Sunday can hold their own morning (weekend school, church).
  - These are the only day types. **A weekday school holiday uses the Sun template**, so editing Sun also changes holidays. Under the tabs, the caption "Sun is also used on school holidays." (caption, `softText`) shows while Sun is selected.
  - Slice card 382 × 440:
    - picture 64 + name (head)
    - "Starts" `TimeField` 170
    - "Ends" `TimeField` 170. The field being dragged is outlined in `pickBlue`.
    - The effect on the neighbour (caption), e.g. "Shower now starts at 7:30 and is 30 min."
    - "Make this free time" (body bold, `lateText`)
  - Hint caption: "Drag a ● on the rim to move a time. Tap a slice to edit it. Tap + to fill free time."
  - "Changes start tomorrow." (caption)
  - `InkButton` "Save the day".

### Drag rules
- Every boundary between two slices has a **knob on the rim**: 36 pt drawn, 64 pt touch target.
- **Dragging a knob moves the shared edge**: the end of one slice and the start of the next move together, so the day stays gap-free unless a slice is made free on purpose.
- **Snap**:
  - Times snap to 5 minutes.
  - Light haptic per step, a stronger one on the hour.
  - At 340 pt radius, 5 minutes is about 7.4 pt along the rim.
- **Feedback**:
  - While dragging, the knob turns `pickBlue` with a ring.
  - A dashed line stays at the old position.
  - **The hub shows the time** ("7:30 pm", title 48 `pickBlue`) between "Dinner ends" and "Shower starts" (caption). The finger covers the knob, so the time is never shown under it.
- **Limits**:
  - A slice cannot get shorter than 15 minutes. The knob stops there with a bump haptic.
  - A knob cannot cross another knob.
- **Locked edges**: the school block's start and end come from School (S2) and Our buses (C2).
  - Those knobs are grey with a padlock and do not move.
  - Tapping one shows "School hours are set in School." (caption) with a link to S2.
- **Tap a slice** → it becomes selected (6 pt outline) and the slice card shows it. Typing a time in the card moves the knob the same way, with the same limits.
- **Free time**:
  - "Make this free time" turns the slice into blank paper with a "+" in the middle.
  - **Tapping "+"** opens a new slice in the card for exactly that free span. The time is prefilled; you pick a picture and a name.
  - Free time on the real clock shows as "Free time" in the hub (A1 day rule).
- **Undo** steps back one change at a time (drag, typed time, make free, add), back to the last save.
- **Save the day** applies the template **from tomorrow**. Leaving with unsaved changes asks "Leave without saving?" (Keep editing / Leave).
- **VoiceOver**: each knob is an adjustable element, "Dinner ends, 7:30 pm", with increment and decrement of 5 minutes.

## C7 · School calendar: add from a photo or PDF (new 2026-11-08) [board, later]
Backlog DA-1; not in M2. Opened from the "Holidays" row in C1.
- Left card:
  - "Found in {file name}" (head).
  - "Read on this iPad. Tick what to add; tap a row to fix it." (caption).
  - Rows 88: `CheckMark` 48, date or range (body bold, 230), title (body, ellipsis), kind (caption: event · change · holiday · other class).
  - Rows the reader is unsure of are marked and start unticked.
- Right column:
  - "Add from" with four buttons 182 × 72: "Photo", "PDF", "Paste text", "Link".
  - Summary "Adds {n} · changes {m}" (head), then two captions:
    - "Holidays hide school mornings and the bus. Every-week items set to skip holidays hide too."
    - "No Apple Intelligence on this iPad? The text is still read, and you pick the dates by hand."
  - `InkButton` "Add {n} dates".
- Reading: PDFKit / Vision `RecognizeDocumentsRequest` → Foundation Models `@Generable` items behind `ScheduleExtractor`.
  - When `SystemLanguageModel.availability` is not available, the rows are empty date fields prefilled with the recognised text lines.
  - This is the only feature that needs Apple Intelligence.
