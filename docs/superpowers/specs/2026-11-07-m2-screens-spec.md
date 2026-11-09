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
- 2026-11-08: full check after the cleanup: stale M3 / N2 / E4 / "Next" wording fixed; board 0c2 re-cut from the current boards; home "Missions →" points to A2. "{Place} in" is gone: home and the morning header always say "Leave in" (to start − "leave before", or to the chosen bus when live). A kid with an outing slides to go on the timetable look too (boards A2t, A2t-w, A1m, 0b, 0c2 updated).
- 2026-11-08: bus setup (user): the LTA key is built into the app from a git-ignored local config; C2 only offers "Change key". The stop and buses are set in first-run setup: new S3 "Getting to school" (stop code with name check, bus pills, walk, ride); the old map step is archived.
- 2026-11-09: after the slide (user): the slide stays green "Ready!" and a tap offers "Not yet"; "All done!" turns "Ready!" the same way; no "Back to the clock" button (← is the way back). The local config holds the LTA key only; no pre-filled route.
- 2026-11-09: medal badge size and place on the kid row ring written out (from board A3).
- 2026-11-09: A2 redlines (shared lines x 64 / 448 / 1312, baselines 107 / 584 / 757, kid rows, KidBand notch, circle pitch = (column − 112) / 5, slide and pill boxes); missions column stretches; boards A2, A2t, A2t-w, A3 now place circles on that even pitch (v135).
- 2026-11-09: done view restored (user: it was on the earlier A3, around canvas v40): medal 200 + "Gold!" in the missions area, the slide stays green "Ready!" (board A3r, new); the next kid is chosen after 3 s. Undo is dragging the knob back past the middle (no tap, no dialog).
- 2026-11-09: mission taps play the picture's rig (user); new rigs shirt, backpack, shoe, babyBottle in kit.js RIGS (boards 0g3 / 0g3b redrawn smaller to fit 35 tiles).
- 2026-11-09: Layout contract (board → layout JSON → redlines page → layout test); canvas page "Redlines" added; layout v2 adds A3r.
- 2026-11-09: "All done!" pill retired (user): every kid slides; a kid with no outing reads "All done? Slide!" with a star knob, done look "Ready!" with the check picture, undo by dragging back (boards A3, 0b, 0c2, 00, 0f).
- 2026-11-09: the slide's knob picture animates while it is held and dragged (bus rocks, wheels turn with the finger; star twinkles) (user; boards A2, 0b, 0g2).
- 2026-11-09: done view geometry and Kid B's done view written out; safe top is read from the system (12.9" under iPadOS 26 reports 32, s 0.984); the way strip fills its region (x proportional, sizes by s, nothing stretched).
- 2026-11-09: home boards put on fixed panel lines (132 / 187 / 301 / 402 / 446 / 584 / 825, circles bottom 792); layout v5.
- 2026-11-09: first-run setup S1–S4 brought to the current rules and moved to "Building now" (new section "S1–S4"; S3 moved there; S1 uses the kit home picture, no draw-a-face slot; S4 rows for later features hidden, side summary and "Start →"). A1n night order written as on the board (time left, then Tomorrow). C3/C4 "What": 5 slots + "More" popover. C4 date paging (‹ at 104, › at 772). C6 bottom stack placed from the button up. Layout v6 (adds S1–S4).
- 2026-11-09: copy from the user's iPad review (PR #21): "Grown-ups only" without "· behind the parent lock"; C2 board redrawn to the built screen with "5 digits", "Type the stop code first", "Walk", "Late up to"; C4 note without the midnight sentence; C5 footer "Drag ≡ to reorder. Tap a row to change it.", no Evening note; C6 hint without "Tap +", day tabs label + 16 inset; C1/E6 side without the footer caption and without "›" on schedule rows, days over time when the line does not fit. Layout v7.
- 2026-11-09: morning strip after the outing has started: new "arrived look" (road kept, mover at the destination, no countdown); the empty look only on a day with no outing (user's iPad review). C2 "Live bus times" card and "Change key" removed (user, PR #22). Crown kit picture replaces the check for a kid who is ready with no time rule.
- 2026-11-09: home Kid B block follows Kid A (name box 40 below Kid A's last box, never below baseline 584) instead of the fixed 584 line (user: the Next row and Kid B looked too far apart); A1n Tomorrow plate 80. Layout v8.
- 2026-11-09: user review PR #24: stop field searches by name or code (C2, S3; list of up to 8, tap to pick); morning kid list face has no colour ring of its own (colour only from the progress arc); C6 new slice takes the first hour of free time, any day picture (sleep too) sets the slice kind, picture grid 3 per row, freeing joins free neighbours. Layout v9.
- 2026-11-09: S2 school search (boards S2 picked, S2s list open): MOE and international schools searched together, last row "Not in the list?", hours prefilled from the school website with a source caption, MOE terms row set from `followsMoeTerms` (own dates / ask when unknown). Layout v10 adds S2s.
- 2026-11-09: new-slot motion (0g2): the hub title swipes sideways inside the hub disc, new from the left (from the right when time goes back), 0.45 s, not at launch; it no longer slides up (user, PR #26).
- 2026-11-09: time left over an hour reads "1h 20m" / "2h" (was "1 h 20 min", cut off in the home panel; PR #27). First run: the app starts empty and runs S1–S4; the seed family is only the debug action "Load sample family", which overwrites after a confirm (user).
- 2026-11-09: S1–S4 build details accepted from the setup session (starter templates and missions, school default by age with a switch, Latest on the school record for every way of going, S3 leave-before rule, Data sources screen, debug links).
- 2026-11-09: S2 asks where each kid goes in the day (School · Preschool · At home) instead of guessing from age (user: preschool from about 2).
- 2026-11-09: A2 is a navigation push over home, not a full-screen cover; "←" only, no edge swipe; kid-screen rules; stays open in the background (user, PR #29).
- 2026-11-09: slide knob motion made visible (user): the bus bobs 6 pt; the star gets a rig (trail + star parts, new move `dash`) and flies forward with its lines; all knob boards (0c2, A2, A2t, A3, A3r) animate.
- 2026-11-09: bus 1st and 2nd choice (user): the 2nd (another direct bus or one that changes) shows faded on the same road, never switched to; Leave in and medals from the 1st. C2 redrawn (1st/2nd tags, Ride 2nd, link), new board C2c (change buses), A2 shows a faded 2nd. Layout v12.
- 2026-11-09: S1–S4 build notes (PR #30): labels caption-size on one line; MOE question row fits in one row; S4 says Face ID only with the MarkerGlyph lock; unpicked face = colour dot; debug setup links need no unlock but Start over a family confirms; Data sources link at the foot of C1.
- 2026-11-09: S1 remove-a-kid is a round × (RoundButton 48, MarkerGlyph.close) on the card corner with a confirm when the card has data; a face is required for Next (user); crayon rounded boxes keep 6 samples per corner. Layout v13.
- 2026-11-09: events get one shape (user): From home or after another event (linked events skip when the event before them does not happen), trip with its own bus route and a way back (`homeAfter`), Bring, missions before/after, medal on/off per event (School on by default); mission windows replace the wake–12:00 rule; slide and done state per outing. New section "Events: one shape for every item".
- 2026-11-09: result list card fixed (610 wide, rows 72, opaque, veil behind, rows that fit then scroll); map stop picker planned as a later item (spec "Pick the stop on a map", backlog N11). Layout v14.
- 2026-11-09: S3 becomes one screen with kid tabs ("Getting there", Next goes to S4 once every tab is done) and a Home card (map picker, kept only on this iPad); S2 Preschool searches the bundled ECDA preschool list (private resource), drop-off / pick-up typed, "Closed on public holidays". Layout v15 (S3 header and side).
- 2026-11-09: S4 becomes a list of feature switches (user): Grown-up lock, Live bus times, Medals now (new part CrayonSwitch, row kinds switch / permission / link); lock off keeps the 2 s hold as the gate, keeps the idle return home, drops the app-switcher cover; turning it on asks Face ID once; later screen C9 "This iPad" from the foot of C1. Layout v16.
- 2026-11-09: home Kid A block takes look ① (user): picture on the left (96 way picture / 104 Next picture), label over the time (72) or Next title stacked to its right, status under the words; Kid B follows 40 below as before. Layout v17.
- 2026-11-09: S2 Preschool uses the researched ECDA list (address as the second line, international early years too), hours prefilled from the ECDA listing or type default, closures by centre type (child care: public holidays + Teachers' / Children's Day; kindergarten: MOE terms), Development Days added by the grown-up.
- 2026-11-09: v17 build notes accepted: S3 Home card ships with N11 (hidden until then); S3 tab finished rule (bus = has a stop; numbers optional); Live bus times off stops live arrivals only, stop search keeps using LTA stop data; S4 captions may wrap to two lines within the 140 pitch; caption without "› This iPad".
- 2026-11-09: school data delivery planned (user): public lists bundled, all lists refreshed from the CloudKit public DB with a manifest and schema check, a "School lists" refresh row with its states on S2 and C9 (sketch SK5), remote data safety rules. Later, N14.
- 2026-11-09: drift-sweep calls: crayon outlines 6 pt inside every box; body/caption weight 500; clock fill = long hachure at −50° over a light wash (boards); sky switch on every kid home (E1, E3, E3b added) with the night pill the same size as the day pill; DayChip 56 for read-only rows. Layout v19.
- 2026-11-09: CrayonSwitch track is a 92 × 28 pill centred in its 96 × 52 box; line heights are total line boxes (title 1.15, head 1.2, body 1.25, caption 1.3), not added to the font leading; A2 legend plate shows the 1st-choice bus number (PR 34, 35).
- 2026-11-09: "Repeats, dates and changes" (user): Repeat, Runs (start + end: end of term / date / count / none), Skip school holidays from the term data, linked time "School end + n" worked out per day, "No school days" (Skip or At a set time), two edit tabs with "Change from when?" on Save, exception rule on series change, skipped slices fade with "Bring back" (no change list, no undo; SK6 hub shows "Mon", day tabs 140/200 without ›); SK7 School card drops "Skip today" from the "School days" tab. Sketches SK10–SK11.
- 2026-11-09: built copy from the drift-sweep fixes (PR 37/38) written in: C2 has no route heading or "For {kid}", side column adds "On the morning map", row captions "to the stop" / "on {bus}" / "still Bronze", "Buses"; C1 "Getting there" is a section with "To school", "More" in the side column; S3 side copy; A2 weekend greeting; C5 rows 88 and Add ring 56; no problem caption before the first change. Main session's calls: S2/S3 kid tabs follow the title (boards fixed); C4 star row = CheckMark 48 + star picture 40 + text (board fixed); S2 medal caption shortened to "Later: just “Ready!”. No medal, no sad face." Layout v20.
- 2026-11-09: one scope rule (user): every item except a just-once event (template slots, School, every-week items) edits with "This day" / "Every week" and "Change from when?" on Save; a clock drag changes this day; tab renamed "This day".
- 2026-11-09: plain again (user): scope tabs renamed "This day" / "All days"; edit screens reuse E5 (All days: Days + Runs + holidays; This day: "Skip this day") and the C6 slice card; Runs only on repeating items, type fixed after adding; no explanatory text on screen; no divider lines inside any card (C5 mission rows and the S2s/S3 result lists lose theirs). Sketches SK6–SK10 redrawn, SK11 retired. Layout v21.
- 2026-11-09: School keeps its terms (Terms row, no Runs); changing where a kid goes (transfer, preschool → school, → at home) uses "Starts on" (Next term / Date), splits the School item, refills terms, hours and medals, then opens S3 for the new trip (user). Sketch SK7b.
- 2026-11-09: the way in (user): a pencil `RoundButton` 80 at the top right of every kid home (mirror of the sky switch) → Face ID → grown-up mode; the 2 s clock hold stays, and on a slice it opens with that slice picked; grown-up header adds "Settings". New kit picture `pencil` (yellow; handover/crayon-art/pencil.svg). Sketch SK5b.
- 2026-11-09: a pending place change can be changed ("Pick another school") or cancelled ("Cancel the change" → "Stay at {old place}?") until its date; after the date, going back is another change (user).
- 2026-11-09: night mapping table (user): every day token maps to one night token; no pure white at night; `nightText` #D8D2E8, `nightSoft` #A6A0C2, white surfaces → `moonPaper` #D8D2E8, buttons → `nightControl` (#2E2C4A fill, chalk #E9E4F5 outline, same shapes). Replaces the chalk-filled main button and the white hub at night.
- 2026-11-09: School edits on the E5 screen like any event (Terms instead of Runs, plus Going, Bring, Missions, Medal); only day-template slots use the C6 slice card. Fixes a clash between the plain-screens rule and "Events: one shape".
- 2026-11-09: grown-up mode final (user): boards G0–G8; C6 absorbed into G1, C1 becomes Settings (G6), a List view (G8) is kept; School edits on G4; sketches SK1–SK11 archived.
- 2026-11-10: event form rows for 6b (main session asked): From / Bring / Missions / Medal rows and what each opens, the home button labels per window, C5 days per mission; board G2b in layout v24.

Markers used below:
- **[board]**: drawn on the canvas, implement as written.
- **[proposed]**: the board does not show it; this is the design decision for M2. Change it here first if you disagree.
- **[later Mx]**: on the board but owned by a later milestone. In M2 the part is hidden, not shown disabled, unless stated.

---

## 0. Shared rules

### Principles (board 00, 2026-11-08)
Every board and the app follow these. Change them here and on board 00 first.
- **Time**: every time is 12-hour with am / pm. One now and one next per kid, never a list; Next skips free time and slots that only resume. Medals come from time only.
- **Kids**: never locked (every kid's slide is always on). Each kid finishes on their own. Kid screens never scroll; more turns a page ("+n"). No shame: late = no medal, never a sad face.
- **Who is who**: a kid = face + name, colour never alone. One colour per kid day and night (#56B4E9 / #E69F00). Pick blue #2E8FE0 = ✓, picked, focus, for any kid. 2+ kids: list on the left, chosen kid's missions on the right.
- **Type and space**: Playpen Sans, six sizes (144 · 96 · 48 · 36 · 30 · 24), nothing under 24. Gaps 4 · 8 · 12 · 16 · 24 · 40 · 64 (4 and 12 inside one part). 12 columns, margin 64; header 48–128, content 176–968.
- **Drawing**: UI shapes are CrayonKit Shapes; pictures come from the kit only (`KitIcon`); the kid's own drawings swap into the same slot later. Motion 1.2 s, rigid parts; reduced motion = still.
- **Privacy**: public repo uses Kid A / Kid B; no home, stops, routes, school names or keys; real family times stay on the canvas. Wolfie is public; the home drawing is not.
- Parts: board 0b (controls), 0c (content), 0c2 (kid parts: `KidFace`, `MissionCircle`, `KidList`/`KidBand`, `NextRow`/`KidNowNext`, `WayCard`, `DonePill`).

- **Crayon rounded boxes** (main session, 2026-11-09): every rounded rect keeps at least 6 outline samples per corner so corners draw round (at 12 pt sampling a 24 pt corner had only 3 and looked cut off). Small circles such as the 28 step dots use a calmer line: width 3, roughness 0.4.

- **Crayon part inset** (2026-11-09, drift sweep): every crayon outline (InkButton, RoundButton, CrayonTabs, TimeField, cards, chips) is drawn **6 pt inside its box on every side**, so the spill of the crayon stays inside and the touch area is the whole box. Some boards show extra side margins (InkButton ≈ 337 × 90 in 382 × 96, tabs ≈ 173 × 54 in 180 × 72): that is an artwork aspect artefact on the canvas, not intended; do not copy it.
- **Text weights**: body and caption 500 (Playpen medium), labels and emphasis 700. The boards set 500 too; a heavier look there comes from the web font rendering, not from the spec.
- **DayChip** sizes: 72 in editors, 56 (pitch 64) in read-only rows (C1 / E6 "Days").
- **Line height is total** (boards, 2026-11-09): the type steps' line heights are the whole line box, font size × factor: title 1.15, head 1.2, body 1.25, caption 1.3 (caption 24 → 31.2 per line). Never add the factor on top of the font's own leading (that made iPad captions about 25 % taller per line than the boards).

### Grid and frame (iPad landscape 1376 × 1032 pt)
- 12 columns of 82, gutter 24, margin 64 (`GridMetrics`). Column n (1-based) starts at x = 64 + (n − 1) × 106.
- Header band y 48–128. Content y 176–968. Main button bottom edge at y 968.
- **Fixed regions** (2026-11-08, user): every screen is a fixed frame of named regions taken from its board (for example header 48–128, strip 176–516, kids and missions 536–968). A region's place and size never come from its content, and a region never disappears so that the regions below can move up: when it has nothing to show, it shows its empty look (each screen names one). Content inside a region is top-aligned (or aligned as the board shows) and capped to the region; it never pushes, centres or resizes the frame. The y values are board coordinates, which already sit below the 24 pt status bar band (see "Status bar"); on other iPads they turn into screen values through "Sizing formulas" below.
- **Layout contract** (user, 2026-11-09: screens kept drifting off the board lines). One source, three views, one check:
  1. **Source**: the board. Every part of every screen sits on a named line or in a named region; a part that needs a new line gets the line named first (board + this spec), never an ad-hoc offset.
  2. **Machine copy**: `handover/layout/<board>.json` (exported from the boards, versioned `layout vN`; public-safe). The app copies it as its layout table and places every listed part from it through one modifier. Inside a part, padding is the part's own; between parts, only the table decides. No stack spacing, no centring, no guessed offsets for anything that is in the table.
  3. **Human view**: the canvas page "Redlines" shows every screen with its lines, regions and part boxes, generated from the same JSON (do not edit by hand). Read a screen's redline before building or fixing it.
  4. **Check**: the app's layout test compares part frames with the table (shared lines ±1 pt after scaling) on 1376 × 1032, 1366 × 1024, 1180 × 820 and 1133 × 744, and a debug overlay draws the same lines on the device.
  - Any board change re-exports the JSON and the redlines together and bumps `layout vN`; the message to the main session names the version and the changed ids. A part missing from the table is a question to the design session, not a guess.
  - Global lines (all screens): status band 0–24, margins 64 / 1312, header 48–128 with baseline 107, content 176–968. Screen lines (home 928; morning 172 / 448, baselines 584 / 757; grown-up 104 / 232 / 930) belong to their screens and are listed in each JSON.
- Spacing tokens: **4 · 8 · 12 · 16 · 24 · 40 · 64** (changed 2026-11-08). 4 and 12 are for the inside of one part only (icon to label, chip padding, caption under a picture); between parts use 16 or more. No other gaps (2, 6, 10, 14, 20, 32, 48, 56 were mapped to the nearest token on every board). Line pitch inside a text block (e.g. the two-line hub, 38) is type, not spacing.
- Type: `CrayonType` hero 144, display 96, title 48, head 36, body 30, caption 24. Nothing smaller than 24.
- Kid screens use `KidScreen` (no scrolling; cap content). Grown-up screens use `GrownupScreen` (header and main button pinned; only the named area scrolls).
- **Status bar** (user decision, 2026-11-08): the iPad status bar shows on **every** screen, kid and grown-up. Its band, y 0–24, holds nothing; only full-bleed backgrounds (paper, night sky) run under it. Status bar text is dark on day screens and light on night screens (A1n, B2n).
- **Sizing formulas: landscape, full screen, every iPad** (2026-11-08, user: "the design language is fixed to the 13 inch"; research report "아이패드 화면 크기 대응 레이아웃"). The boards stay drawn at 1376 × 1032; these formulas turn a board value into a value on any landscape iPad, from the mini (1133 × 744) to the 13" (1376 × 1032). At 13" every formula gives the board value back.
  - **Inputs**: W = window width, H = window height, `safe.top` = the top safe-area inset as the system reports it (24 on the 13"; 32 on the 12.9" under iPadOS 26, measured on the family's iPad 2026-11-09). Never hard-code it. H_safe = H − safe.top. Lay the screen out in full-screen space; the band 0 … `safe.top` holds nothing but full-bleed backgrounds.
  - **One scale**: s = min(W / 1376, H_safe / 1008). 13": 1.0 · 12.9" (the family's, 1366 × 1024, safe top 32): 0.984 · iPad Pro 11" (1210 × 834): 0.804 · iPad / Air 11" (1180 × 820): 0.790 · mini (1133 × 744): 0.714. The reference height is 1008 (the 13" safe area), not 1032: this is the fix for the overflow bug. Never `scaleEffect` the whole screen (blurry text, wrong hit areas); multiply each value by s instead.
  - **Floors**: `fluid(ref, lo) = max(lo, ref × s)`. Floors are design choices, not research values: check them on the family iPad and on a mini simulator [proposed].
  - **Vertical position**: y = safe.top + (y_board − 24) × s. Header top 48 → 24 + 24 s; main button bottom 968 → 24 + 944 s (mini: 41 and 698, leaving 46 below).
  - **Horizontal position**: every region has an anchor. Default, when a screen does not name one: a region that spans both margins (64 … 1312) **stretches** (left = 64 s, right = W − 64 s); otherwise it is **left**-anchored (x = x_board × s) when its board centre is left of 688, else **right**-anchored (x = W − (1376 − x_board) × s). Named exceptions: the home right panel (A1, A1n, E1, E3, E3b) stretches from 928 s to W − 64 s, so the extra width of a narrower-but-taller iPad goes to the text, not to a gap.
  - **Type**: hero `fluid(144, 96)`, display `fluid(96, 64)`, title `fluid(48, 36)`, head `fluid(36, 30)`, body `fluid(30, 24)`, caption **24 fixed** (still nothing under 24). Mini: 103 / 69 / 36 / 30 / 24 / 24. Use `Font.custom(_:size:relativeTo:)` with the scaled size so Dynamic Type still works on top; do not also use `@ScaledMetric` on the same size. Text that may not fit at its floor wraps or uses `ViewThatFits`; it never shrinks below the floor.
  - **Spacing**: 4, 8, 12 fixed (inside one part). 16 → `fluid(16, 12)`, 24 → `fluid(24, 16)`, 40 → `fluid(40, 28)`, 64 → `fluid(64, 40)`. Grid: margin `fluid(64, 40)`, gutter `fluid(24, 16)`, column = (W − 2 margin − 11 gutter) / 12 (82 at 13").
  - **Pictures and drawn parts**: sizes × s (clock R 372 s, centre (448 s, safe.top + 504 s); mission circle 112 s; way strip: the ground and the road fill the strip region (64 s … W − 64 s) and its height is 340 s; stop, stem and picture **x** positions are proportional to the strip width, every **size and y** uses s, and nothing is stretched (a tree stays round); labels and the card sit on top at their own type sizes (changed 2026-11-09 from keep-aspect, which left a 6 pt gap per side)). Kid tap targets stay ≥ 64 [proposed]. Crayon outlines × s; focus rings and hairlines fixed.
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
- **First run** (user, 2026-11-09): the app starts empty on every build and runs first-run setup S1–S4, where the grown-up enters the real kids and settings. Nothing below is loaded on its own.
- **"Load sample family"** is a debug-tools action only. It loads the seed below and **overwrites** the stored family, so it asks first: "Replace your family with the sample family? Everything you entered here is deleted." with "Replace" (`lateText`) / "Cancel". Tests and previews use the seed directly.
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
- Debug time machine: at 6:52 on a Monday, A1 shows "Breakfast" / "until 7:30 am" and Kid A "Leave in 34 min" (live look, build step 5), as on the board.

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
  - Fill (matched to the boards, 2026-11-09): a light wash plus long parallel hachure strokes at about −50° with paper showing between them (the boards' look), in the slot colour; not a dense wash with short flicks. **Free time has no fill**: plain paper with the normal radial edges, and no picture.
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
  - 24 below: time left to that thing: "in" body 30 `softText`, then `TimeLeft` display 96 ("38 min"). Over 60 minutes: "1h 20m" in the same size, whole hours "2h" (user, PR #27, 2026-11-09: "1 h 30 min" was 503 wide and cut off in the 384 panel; "1h 30m" measures 356, "38 min" 330). VoiceOver still says "1 hour 20 minutes". Over 3 h: leave the time left out. The A2 header uses the same format ("2h 59m" at title 48 is 177 wide).
  - **With the live bus (build step 5, "A2 live look")** on bus mornings the time left becomes "Leave in" + `TimeLeft` to the leave time + "On time" (boards A1, E1). Same place and sizes; only the words and the target time change. On A1 (two kids) the Next row is hidden on school mornings to leave room for Kid B; E1 (one kid) keeps it under "On time".
- **Night** (A1n look; board order confirmed 2026-11-09): the time left comes first: "Bed in" (first line, baseline 301) + `TimeLeft` (baseline 403) to Sleep. Then the "Tomorrow" row: a 64 picture on a 104 plate at y 436, "Tomorrow" (body bold, baseline 484) over "School, leave {h:mm}" (caption, baseline 516). There is no Next row at night: Next would be Sleep, which the time left already says.
- Kid B block: unchanged (now 160 / next 104 circles, captions "now" / "next").

### Right panel
- **Home panel lines** (all home boards A1, A1m, A1n, E1, E3, E3b; fixed 2026-11-09, Kid B rule changed the same day after the user's iPad check: the fixed Kid B line left about 140 empty under a short Kid A block): panel x 928 … 1312, top 96.
  - **Kid A block, look ①** (user, 2026-11-09, board "Home right panel: every look side by side"; replaces the label line with the way picture at the far right): weekday baseline **132**, Kid A name **187** (face 48 at y 163), then one row, 24 below the name: the picture on the left, the words stacked to its right.
    - **Leave / Bed shape**: picture 96 at (928, 241): the way picture (bus, car, taxi, shoe); at night the moon on a 96 paper plate (picture 64). Text left **1040** (928 + 96 + 16): "Leave in" / "Bed in" (body, `softText`) baseline **265**, the time left (**72 bold**, line height 1.0) baseline **337**. Status "On time" (body bold, `onTimeText`, dot 24) at x 1040, baseline **374**. "1h 20m" measures 267 at 72, inside the 272 beside the picture.
    - **Next shape** (E3, E3b, and the second block on E1): picture 104 at (928, 238), text left **1048**: "Next" (caption) baseline **259**, title (head) **300**, "at {h:mm am/pm}" (body, `softText`) **338**.
    - A1n: the Tomorrow row (80 plate, 56 picture) follows 24 below the row.
  - **Kid B block, one rule**: the Kid B block (name, now/next circles, captions) moves as one unit. Its name box top = the bottom of Kid A's last box + **40**, and its name baseline is never lower than **584**. Inside the block: circles top = name baseline + 48 (now 160, next 104, bottom-aligned), captions baseline = circles bottom + 33. Board values (layout v17, name baseline / circles bottom / captions): A1 464 / 672 / 705, A1m 428 / 636 / 669, A1n 514 / 722 / 755, E3 and E3b 416 / 624 / 657.
  - A1n's Tomorrow row uses an 80 plate with a 56 picture (was 104 / 64), so the night block ends at 516 and Kid B sits on 584.
  - Main button 872–968 stays pinned; the space a short Kid A block leaves now sits above the button, not between the kids. On E1 (one child) the second "Next" sits on 584.
- **Kid A block** (spacing from the board):
  - `KidFace` 48 (Kid A), gap 16, name head 36.
  - **With the live bus (build step 5)** bus mornings: "Leave in" (body, `softText`) with an 80 pt bus picture at right, then `TimeLeft` at display 96 ("34 min"), then the status "On time" (body bold `onTimeText`, 24 pt green dot).
  - **Otherwise**: Next row + time left, see "Now and next on home".
- **Kid B block**, 64 below:
  - `KidFace` 48 (Kid B), gap 16, name head 36.
  - Row with gap 40:
    - "now": 160 circle in crayon `kidApricot` with a 104 picture inside, caption "now" under it.
    - "next": 104 white circle with a 64 picture inside, caption "next".
  - Bottom-aligned.
- **Main button**: `InkButton` "Missions →", full panel width, 96 tall, bottom of panel → A2. Shows only in the mission morning (below).
- **Mission morning (board A1m)**: from the earliest kid's wake-up (end of their Sleep slot) until 12:00 pm, on A1, E3 and E3b:
  - "Missions →" shows at the bottom of the panel (E3's "Diary →" is M5, so there is no clash).
  - Kid A block: face + name, then, if Kid A has an outing (see "Morning data") that has not started and starts within 3 h: "Leave in" (body `softText`) with the way picture 80 at the right (bus, car, taxi, shoe), then `TimeLeft` display 96 to the leave time (start − "leave before") ("38 min", "1h 20m"). This is the A1 board layout; the "On time" line shows only with live bus times. Otherwise: the Next row without the time left.
  - Kid B block unchanged.
  - **Panel fit** (board A1m; 2026-11-08): the panel is the column x 928–1312, y 96–968. Stack from the top: weekday head 36, 24; Kid A face row 48; 24; "Leave in" row 72 (the 80 way picture may stand 8 above the row); 8; "33 min" display 96 (line height 1.0, so the box is 96 tall, not 115); 64; Kid B face row 48; 24; now/next row 160 + 8 + caption. That ends at about y 650. "Missions →" (96) is pinned to the panel bottom (968) by flexible space, so about 220 pt are free. Nothing should move the home up: check line heights first (display and title boxes use line height 1.0–1.15, not the font's default), and never let the panel grow the screen. If a longer case still does not fit, shrink in this order: the flexible space down to 24, then the Kid B gap 64 → 40. The clock never moves.
  - After 12:00 pm the panel goes back to the "Now and next on home" rule and the button hides. On a bus morning with live times the Kid A block shows "Leave in" + "On time" instead (see "A2 live look").

### States
- Weekend or holiday → E3 layout. One child → E1 layout.
- Kid B has no slot now: the "now" circle shows the play picture with caption "now"; if nothing is next, the "next" circle is not shown. [proposed]

---

## A2 · Morning: missions and the way there (new 2026-11-08) [boards A2t, A2t-w (timetable look), A2 (live look), A3 (done), A2m (many missions)]
One morning screen. Its strip region has two looks: the **timetable look** (this section: car, taxi, on foot, and the bus when there are no live times) and the **live look** (the bus with live times, see "A2 live look" below). Going somewhere is the point of the morning, so the top shows the way there (user, 2026-11-08).
- **Header** (48–128): `RoundButton` 80 with `MarkerGlyph.chevronLeft` 40 → home; "Good morning!" title 48 ("Good morning! {Weekday}" on a weekend, built PR 38); right: "Leave in" (body, `softText`) + "{n} min" (title 48), counting to the family outing's leave time (start − "leave before"); the live look adds the status (below).
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
  - **Arrived look** (2026-11-09, user's iPad review): once today's family outing has started and no other outing is left, the strip keeps that outing's road and pictures, with the mover parked at the destination (bus at the school, car or taxi at its end). The header countdown is empty. It stays until midnight or until the next outing of the day becomes the one shown.
  - **Empty look** (only on a day with no outing at all): ground and trees only, no road; home picture 150 in the middle (x 624) on its own short stem; `CrayonCard` "Home all day" at (120, 38), no face.
  - **Whose outing** (changed 2026-11-08, user: the road should not vanish when Kid B is chosen): the strip and the header countdown show **the family's next outing**: the earliest slot or item today, of any kid, that has a trip and has not started. It stays the same whichever kid is chosen (a younger kid goes along to the stop, so the morning has one road). "leave at {h:mm am}" next to the chosen kid's name shows only when the chosen kid has their own outing left today; otherwise nothing is there. When the last outing of the day has started, the strip shows that outing's **arrived look** and the header countdown is empty. Only a day with no outing at all uses the **empty look** (see "Way strip"); the strip region keeps its place and size either way (Fixed regions). The kids and missions stay at 536–968.
- **Kids and missions** (536–968): the A2 family layout. Kid list on the left (`CrayonRing` 76 + face, `KidBand` on the chosen kid), the chosen kid's name + "leave at {h:mm am}" and one row of 112 mission circles on the right (6 a kid; fold / "+n" rule of A2m beyond that).
- **Every kid slides** (user, 2026-11-09; the "All done!" pill is retired): the bottom control is always `SlideToGo` 864 × 96 on the missions column. A kid with an outing: "Ready? Slide to go", knob = the way picture. A kid with no outing (Kid B at home): "All done? Slide!", knob = the star sticker, no medal. Always on; missions help but never lock it. Done look and undo are the same for both (see "After the slide"): green, knob at the end, "Ready!", drag back past the middle to undo. A kid with no outing gets the crown picture (kit `crown`, with its rig; 2026-11-09, user) and "Ready!" in the done view and no time-based medal.
- **Presentation** (user, PR #29, 2026-11-09): A2 is pushed over home (navigation push), not a full-screen cover. The way out is "←" in the header only: no system back bar and no edge swipe. It is a kid screen, so the grown-up rules (idle relock, app-switcher cover) do not apply, and it stays open when the app goes to the background.
- **Folded and "+n" circles** (board A2m): the folded circle is the kid's 112 crayon circle with the done tick, caption "{n} done". The "+n" circle is **also the kid's crayon circle** (not paper), "+{n}" title 48 bold, caption "{n} more"; tapping it turns the page. On the last page that place holds the back circle: the kid's crayon circle with `MarkerGlyph.chevronLeft`, caption "Back"; tapping it returns to the previous page (with at most 8 missions that is page 1).
- **Tapping a mission** toggles it (undo allowed); the check draws itself in 0.35 s (Reduce Motion: appears). The tap also plays the mission picture's rig once, as on the clock (see "Picture rigs": ≤ 1.2 s, taps during the play still toggle but do not restart it; Reduce Motion: no play). New rigs for the seed mission pictures (user, 2026-11-09): `shirt` swings on its collar (rock 8°, origin 120, 40), `backpack` bounces (bob 10, twice), `shoe` taps its toe (rock 10° about the heel, 40, 200), `babyBottle` tips to drink (rock 12°, origin 120, 220); other pictures use the default hop.
- **Spoken times** (all screens): `TimeLeft` speaks full words, not the shown text: "38 minutes", "1 hour 20 minutes", "1 minute".
- **VoiceOver**: the strip reads "Kid A's way to school, by bus, 38 minutes, school starts at 7:30 am"; kid rows are tabs; missions are toggles.
- **Live look**: on a bus morning with live times the same region shows the live look (below); the timetable look is its fallback.


### A2 redlines (board values at 1376 × 1032, measured from boards A2, A2t, A2t-w, A3, v135) [board]
Every part sits on these lines; on other iPads apply "Sizing formulas" (y = safe.top + (y − 24) s; the anchors named here).
- **Shared vertical lines**: **x 64** = ← button left = strip left = kid list left. **x 448** = missions column left = name line left = first circle left = slide left. **x 1312** = header right = strip right = last circle right = slide and pill right. **x 172** = text left inside the kid rows.
- **Anchors**: the kid list is left-anchored; the missions column **stretches** from 448 s to W − 64 s (named exception, like the home panel); the circle pitch, the slide width and the pill's right edge follow the column.
- **Header** (48–128): ← `RoundButton` (64, 48, 80 × 80). Title left 168 (button + 24), **baseline 107**. Right group, right edge 1312, all on **baseline 107**: "Leave in" (body) · gap 12 · "{n} min" (title 48, "min" 24) · gap 16 · status (head 36 with a 28 dot, gap 8; live look only). Without status the minutes end at 1312.
- **Strip**: (64, 176, 1248 × 340), see "Way strip".
- **Kid list** (left-anchored): rows (64, 536 + 108 i, 340 × 100), gap 8. The chosen row's `KidBand` is (64, row y, 354 × 100): the extra 14 is the notch, its tip at x 418, centred on the row (y + 50), pointing at the missions column. Ring 76 at (80, y + 12) (16 in from the row edge); face 66 at the ring's centre (118, y + 50). The face here is the bare kid picture, **no colour ring of its own** (user review PR #24, 2026-11-09: two rings read as confusing): at 0 missions only the beige track shows, and the kid's colour arrives with the progress arc. Name (body 30 bold) left 172, baseline y + 48 (584 for row 1); caption (24) left 172, baseline y + 78.
- **Missions column** (448–1312, top 548): name line 48 tall: kid name (head 36) left 448, **baseline 584** (the same line as row 1's name); "leave at {h:mm am}" / "home today" (caption 24) right after the name with gap 12, same baseline.
- **Circles**: six tracks of 112 across the column, **first circle left 448, last circle right 1312, pitch = (column width − 112) / 5** (150.4 at 13"). Fewer than six keep the same pitch and start at 448 (Kid B's three at 448, 598, 749). Circle top 612 (64 below the name line top), so the row is 612–724. Caption: top 732 (circle + 8), baseline 757, centred on the circle in a label one pitch wide, up to two lines.
- **Bottom control** (bottom 968): slide (448, 872, column width × 96). Pill (right edge 1312, 872, 400 s × 96).
- A layout test checks these shared edges (64 / 448 / 1312 and baselines 107 / 584 / 757) on the four sizing-test iPads.

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
- **Done state**: per kid **per date**: `{ kid, date, doneMissionIds, ready: Bool }`, in the local store. A new date starts at **midnight**, like the clock, so every morning starts empty. Keep 14 days (the medal fields come with the live look; the M5 diary can read it later); drop older ones. Renaming a mission keeps its done state (it is keyed by id); removing it drops it.
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
  - **Legend** at (946, 16): white plate **with the kid's 1st-choice bus number** (an empty plate read as broken on the iPad; PR 35) + "my bus" (caption bold); a 2nd choice adds a faded "{n} 2nd" line under it. No `CrayonCard` on the live look.
  - A bus that has reached our stop leaves the map on the next refresh.
  - VoiceOver: "Live bus map. Bus 1 in 29 minutes, your bus. Leave in 19 minutes, on time." (numbers from the data; full words, see "Spoken times").
- **Refresh**: every 30 s while the screen is open, and on open; nothing in the background. A failed call keeps the last answer until it is 2 min old, then the timetable fallback shows (no error text for kids; C2 shows the state for grown-ups).
- **Bottom control** (536–968 region, bottom 968, right-aligned 864 wide): for a kid with an outing today, `SlideToGo` 864 × 96, label "Ready? Slide to go", knob = the way picture (bus). Always awake; missions help but never lock it. A kid with no outing slides too ("All done? Slide!", star knob; see "Every kid slides"). On the timetable fallback the slide stays.
- **After the slide** (boards A3r and A3; restored 2026-11-09 from the earlier A3, user): the kid stays chosen and the missions area becomes their **done view** (board A3r): the medal picture 200 at the column's left line (448) on the circle row, then, 40 to its right, "Gold!" / "Silver!" / "Bronze!" (display 96) over "Ready in good time!" (body 30); a kid with no medal gets the crown picture (kit `crown`, with its rig; 2026-11-09, user) and "Ready!". The medal drops in and swings, crayon confetti (0g2; Reduce Motion: fades in). The slide stays in its done look: green (`slider` done art), knob at the right end with a check, "Ready!" (head 36) to its left. The kid's row turns "Ready! Gold" / "Ready! Silver" / "Ready! Bronze" / "Ready!" (caption bold, `onTimeText`) and the medal sits on the progress ring (medal 36 on the 76 ring, right edge 8 outside it and bottom edge 6 below it, i.e. 0.47 of the ring with offsets 0.1 / 0.08). After 3 s the next unfinished kid is chosen (board A3); tapping the ready kid's row shows the done view again. The header title becomes "Ready, {name}!" and keeps counting "Leave in" for the family's outing. Done view geometry (board A3r, layout v4 ids `missions.doneMedal`, `missions.doneTitle`, `missions.doneSubtitle`, `bottom.slide`, `bottom.knob`, `bottom.knobCheck`, `bottom.doneLabel`): medal 200 × 200 at (448, 612), the circle-row top; title left 688 (448 + 200 + 40), baseline 728; subtitle left 688, baseline 776. A kid with no outing (Kid B) gets the same view with the crown picture (kit `crown`, with its rig; 2026-11-09, user) in the medal's place, title "Ready!" and subtitle "All done for the morning!". Confetti: 24 crayon pieces in the kit colours burst from the medal centre (548, 712) over about 360 × 240, clipped to the missions column, 1.5 s with the medal drop. A kid with no time rule (no outing, or slid after L2) gets the crown on the done knob instead of the check. **Undo by dragging back** (user, 2026-11-09): drag the knob from the right end back toward the start; past the middle it lets go and slides home, the done view turns back into the missions, the medal is dropped. Released before the middle, it springs back to "Ready!". No tap-to-undo and no dialog on the slide.
- **Medal from the time only** (missions never count):
  - arrive-by = the outing's start (seed school 7:30 am); latest = start + late grace (C2, default 15 min).
  - L1 (ideal leave) = the leave time of the last bus (live, at the moment of the slide) whose arrival at our stop + ride minutes ≤ arrive-by. L2 = the same with latest.
  - Gold: slid at or before L1 − 5 min. Silver: at or before L1. Bronze: at or before L2. After L2: "Ready!" with no medal, never a sad face.
  - Timetable fallback: L1 = start − leave before; L2 = L1 + late grace.
- **Done state** gains `readyAt` and `medal: gold | silver | bronze | none` (per kid per date, as in "Morning data").
- **Home (A1)** on a live bus morning: the Kid A block adds the status line under `TimeLeft` (the A1 board look), and "Leave in" counts to the chosen bus; the timetable look counts to start − "leave before" with no status.

### Bus settings (C2 "Our buses") [board C2, redrawn 2026-11-09 to the built screen]
- One route per kid with a bus outing. No route heading and no "For {kid}" line (built, PR 38). The Plan B card and "+ Add a route" are hidden (plan B comes later). The Buses row label reads "Buses".
- Layout: the S3 form without the "Going" row. Header "←" 80 → C1, "Our buses" (title 48), "Grown-ups only" (caption) at the right. Rows (label 104, control 232): **Stop** at 208, **Buses** at 352, **Walk** at 496, **Ride** at 600, **Late up to** at 704.
- Rows (copy from the iPad review, 2026-11-09): **Stop** (search by name or code; user review PR #24, 2026-11-09: families do not know the 5-digit code): a 400 × 80 field, placeholder "Stop name or code". Caption "Type the stop name, or the 5-digit code on its pole". With 2 or more letters, up to 8 matching stops (by stop name or road) list under the field: the caption reads "Tap your stop" (y field bottom + 8) and the list card (400 wide, `CrayonCard` white) starts 40 below the field, over the rows below it. **Result list card** (shared by the stop and school searches; fixed 2026-11-09 after the iPad check: rows overlapped, names were cut, rows below showed through): 610 wide (the whole control column 232–842, wider than the 400 stop field), opaque white `CrayonCard`, padding 12 top and bottom; rows **72** tall: the name (body bold, `link`, one line, "…" only past 610) over the caption (one line), gap 2, divided by a 2 pt paper line. While the list is open, everything outside the field, its caption and the card is veiled with paper at 72 % (no tap goes through; tapping the veil closes the list). The card shows as many rows as fit above the form card's bottom (968 − 16): S3 6, C2 8, S2 6; more rows scroll inside the card. No match: "No stop with that name" (caption `hurry`). Tapping a row closes the list, fills the field with the stop name, shows the check picture 32 + "{road} · {code}" as the caption, and fills the bus pills. Five digits still work as before (the code match fills the same way). Board S3 shows the list open; board C2 shows a stop picked. **Buses**: pills (180 × 72) of the numbers that call at that stop; pick one or more. Before a stop is picked the row reads "Pick the stop first" (caption). **Walk**: −/+ minutes, "to the stop" (default 10). **Ride**: −/+ minutes, "stop to school" (default 10). **Late up to**: 0–30, step 5 (default 15), "still Bronze". Labels stay on one line in the 104–232 column.
- Side column: "{Kid} to school" (head), "“Leave in” = the bus at the stop − the walk." (body), "Arrive by and latest are in School; they set the medals." (caption), then "On the morning map" (body bold) and "{n} is “my bus”: bold, it sets Leave in and the medal." (caption). Row captions: Walk "to the stop", Ride "on {bus}", Late up to "still Bronze". Button "Done" → C1.
- **1st and 2nd choice** (user, 2026-11-09; boards C2, C2c, A2): the kid's route has a **1st choice** ("my bus", one bus number at our stop) and an optional **2nd choice**. The 2nd is never switched to: both show on the same road, the 2nd faded. "Leave in", the status and the medal come from the 1st only.
  - **2nd choice, kinds**: (a) another bus from our stop that also reaches school (often the long way round), with its own ride time ("Ride 2nd"); or (b) a bus that **changes**: a first bus from our stop to a change stop, a walk between, then a second bus to school (board C2c). One 2nd choice per kid, (a) or (b), not both.
  - **C2 rows**: Buses pills: the first tap makes a pill "1st" (`tab-on` + a "1st" tag), a tap on another makes it "2nd" (`tab-off` at 70 % + a "2nd" tag); tapping a picked pill clears it. Caption "Tap your bus (1st). A 2nd choice is optional." Rows: Walk 496, Ride ("on {1st}") 600, **Ride 2nd** ("on {2nd} · the long way") 704 when a direct 2nd is picked, Late up to 808, then the link "+ 2nd choice changes buses…" (y 900) → C2c.
  - **C2c "2nd choice · change buses"**: From (our stop, read-only) 208; First bus (pills of buses at our stop) 296; Change at (the stop search field, 400 × 80) 400 with the picked stop's caption 488; Then (pills of buses at the change stop that reach school) 544; Ride 1 680, Walk between 776, Ride 2 872. Save → back to C2; picking a change route clears a direct 2nd.
  - **A2 strip**: the 2nd choice's next catchable bus is drawn at 50 % opacity like "too soon", with the small bubble (plate + "{n} min") over "or · 2nd"; a changing 2nd reads "or 34 → 33" and its caption shows the change: "wait 3 min" / "tight" / "will miss", from the live arrivals of the second bus at the change stop at the time the first bus gets there. The legend top right adds a faded "{n} 2nd". If its bubble would overlap the my-bus bubble it is left out (the "too soon" bubble goes first).
  - S3 (first run) sets the 1st only; the 2nd is set later in C2.
- **Pick the stop on a map** (later, user 2026-11-09; backlog N11) [proposed]:
  - Entry: a map `RoundButton` 64 at the right end of the Stop field row (S3, C2, C2c "Change at"), x 652 (field end 632 + 20).
  - The screen: a full-screen grown-up sheet "Find your stop" with "←" and a search field at the top ("Search a place or stop"). The map (MapKit, standard style, the crayon paper tint only on the frame) fills the rest; a side card 382 wide on the right shows the picked stop.
  - **At first** the map centres on the school of this kid (lat/lng from the school data) at about 1.5 km across, so no location permission is needed. A "Near me" button (RoundButton 64, bottom right of the map) asks for location only when tapped. The app never stores where the map was.
  - **Stops** are LTA BusStops markers: a small crayon bus-stop pin (new MarkerGlyph `busStop`, 40) for every stop inside the visible area; below about 16 zoom they cluster into a count bubble. Typing searches stop names, roads and codes first (the bundled stop list), then places (MKLocalSearch) to move the map.
  - **Tapping a stop** selects its pin (pick-blue ring) and fills the side card: stop name (head), "{road} · {code}" (caption), the bus numbers that call there (pills, from LTA BusRoutes), and "Use this stop" (`InkButton`).
  - **Back in the form**: "Use this stop" closes the sheet and fills the field exactly as picking a search row does (name in the field, check + "{road} · {code}" caption, bus pills filled). Only the stop code is stored.
- **Get-off stop and worked-out times** (later, same item N11; user 2026-11-09) [proposed]:
  - **Route form** (S3, C2, and the event's bus route): after the Buses row comes **Get off at**: the same search field with its map button. Under it, up to 3 suggestion pills: the stops of the picked 1st bus that come after the boarding stop, nearest to the school (or the event's place) first, each "{name} · {n} m walk". Picking one fills the field like any stop.
  - **Map picker, get-off mode**: the same sheet titled "Where do you get off?", centred on the school. Only the stops of the picked bus after the boarding stop are shown as pins; the bus line between them is drawn as a dashed crayon line; other stops are hidden.
  - **Times are worked out, then editable**: the Walk, Ride and new "Walk at the end" rows each show the computed minutes with a small source caption: "from Apple Maps" (walks, car, taxi: MapKit ETA; car and taxi with the departure time for traffic), "from the bus route" (ride: LTA BusRoutes distance between the two stops along the service, at an average bus speed, rounded up to the minute). The −/+ steppers still work: a changed value reads "set by you" and gets a "↺ use estimate" link. The ride stays an estimate; live arrivals still come from BusArrival at the boarding stop.
  - **Walk from home**: uses the family Home set in S3 (or C1). **Home stays on this iPad only**: a local store entry that is not synced to other iPads, never in seeds, previews, snapshots, logs or the layout JSON; tests use a made-up coordinate. Without a Home the walk and car rows stay manual.
  - **No bus links the two stops** (the picked bus does not call at the get-off stop after the boarding stop, in either direction): the Get off row shows "Bus {n} doesn't stop there after {boarding stop}." (caption `hurry`) and, from BusRoutes, the buses that do link them as pills to switch to; if none, a link "Change buses on the way…" (→ C2c). Save stays on; the Ride row falls back to the plain stepper with no source caption.
  - Medals and "Leave in" use the same numbers: leave = bus at the stop − walk; arrive = bus + ride + walk at the end ≤ arrive-by.
  - Data check before building: confirm the BusRoutes field names (ServiceNo, Direction, StopSequence, BusStopCode, Distance in km from the route start) in the official DataMall guide, and test MKDirections transit ETA in Singapore (it may return no result even where the Maps app has transit), so the ride never depends on it.
- **School data delivery and refresh** (user, 2026-11-09; later, backlog N14, with CloudKit) [sketch SK5]:
  - **Bundled**: every public list ships in the app (MOE schools, calendar, hours, the ECDA preschool list; files that cannot sit in the public repo come in through `make private`), so S2 search works offline from the first run.
  - **Fetched**: the newest version of every list (public and private, including the international list) is published to the CloudKit public database from the private data repo, independent of app releases. The app reads a small **manifest** first (per file: dataVersion, schemaVersion, sha256, size) and downloads only files that are newer **and** whose schemaVersion it can read; otherwise it keeps what it has. Publishing can keep an older schema alongside a new one so older apps still get updates.
  - **Refresh row** ("School lists"): `RoundButton` 56 with a refresh glyph + title (body bold) over a status caption. On S2 at the bottom of the side column above Next, and in C9 "This iPad". States: Idle "Updated {d Mon yyyy}"; Checking "Checking for new lists…" (arrow turns; Reduce Motion: still); Getting "Getting new lists · {n} of {m}"; Done (check picture, `onTimeText`) "Up to date · {date}", back to Idle after 3 s; Offline (`hurry`) "No internet. Using {date} lists."; Failed (`hurry`) "Couldn't update. Tap to retry." A list this app version can't read is skipped quietly ("Up to date for this app version"). The row never blocks Next. Tap = check now; the app also checks at most once a day on its own.
  - **Remote data safety rules** (no crash from data): use a file only after its checksum matches; decode with errors caught (never `try!`), per record (skip bad records, keep the rest), with tolerant enums (unknown → other); no force-unwrap or force-index on fetched data; range-check times and dates; refuse files over the manifest's size cap; swap the whole snapshot at once after it is fully decoded; a stored pick (school id) that is missing from a new list keeps its copied values. The publish job runs `validate.py` and the app's own Swift decoder on the files before upload; unit tests feed truncated, unknown-value and empty files and expect the old data kept.
- **Live bus times** (user, 2026-11-08): the LTA key belongs to the app, not to each family. It is built in from a git-ignored local config file (the repo is public); a build without it (CI, clones) has no live times and every bus morning shows the timetable look. There is no key field and no "Live bus times" card in C2 ("Change key" removed, user decision, PR #22, 2026-11-09): the key is built in only. When live times are off, the morning shows the timetable look.
- Privacy: stop codes, bus numbers and the key never go into the repo, the seed or tests (tests use made-up values such as stop "00000", bus "1").
- Entry: first-run setup step S3 "Getting to school" (below) sets it up; until then, and for later changes, C1 "Getting there" (Kid A) → C2. The stop, buses, walk and ride are each family's own data; the local config holds only the LTA key.

### Events: one shape for every item (user, 2026-11-09) [direction approved; sketches SK1–SK4 on "Sketches (review)"; details proposed]
School is no longer special in the model. Every item that can sit on a kid's clock (template slot, every-week item, just-once item) has the same optional parts. School only differs in where it comes from (S2 and the school data), MOE terms and holidays, and its locked edges in C6.
- **From**: "Home" (default) or "After {event}" (linked). A linked event starts when the event before it ends, at the same place: no trip, no stop at home. Its days can only be days on which that event happens. **When the event before it does not happen** (school holiday, "skip just once", another day), the linked event is skipped too (user).
- **Trip** (only with From = Home): `way` + `leaveBefore` as now, plus **`homeAfter`** minutes (the way back; 0–90, step 5). A chain of linked events uses the last one's `homeAfter`. By bus the trip has its **own route** (stop, 1st and 2nd choice, see C2); the kid-level "Our buses" route becomes the School event's route (migration: move it as is). C1 "Getting there" stays as a shortcut to the School event's route; the C3/C4/E5 Going row by Bus opens that event's route instead of "Uses Our buses".
- **Bring**: things to take (kit pictures). They become missions on the days the event happens: packed the evening before together, checked by the kid in the window before she leaves home for it (see "Mission windows").
- **Missions before / after**: optional short lists on the event ("before": shoes on; "after": unpack bag, hang the swimsuit to dry).
- **Medal**: an on/off switch per event (user). On by default for School, off for others. An event with the medal on needs a trip and uses its own arrive-by (= start) and latest (= start + its late grace; School keeps its S2 values). Several medals a day are fine; each is kept for the diary (M5).
- **Mission windows** (replaces "the mission morning" as the rule for when missions show): from the day's points (wake, each leave, each home, dinner, bed):
  - Morning routine (C5): wake → the first leave (or 12:00 pm when nothing leaves before then).
  - Before an outing: the window that ends at that outing's leave: its "before" missions and Bring checks go there, after the routine ones; the same picture shows once.
  - After coming home: home → the next leave or dinner: "after" missions of the events that just ended.
  - Evening routine: dinner → bed (C5, later), including "Pack for tomorrow" with tomorrow's Bring things.
- **Slide to go and done state are per window and per outing**, not per day. Two records: missions done per window `{ kid, date, windowId, doneMissionIds }` (windowId = morning · before:{outingId} · after:{outingId} · evening), and the slide per outing `{ kid, date, outingId, ready, medal }`. A day with no outing keeps its slide ("All done? Slide!") on the morning window: `{ kid, date, windowId: morning, ready }`, no medal. Each outing with a trip has its own slide; the A2 screen shows the next one.
  - **Migration** of today's per-day records (kept only 14 days): `doneMissionIds` → the morning window of that date; `ready` + `medal` → that day's first outing for the kid (School when there is one); a day with no outing → `ready` on the morning window.
- **Home "Missions →"** shows whenever a window with missions is open (not only wake–12:00 pm); its label names the window ("Missions →", "Before swimming →", "After school →").
- **C5** keeps only the day routines (morning, evening) with days per mission (Library bag: Thursdays). Event missions and Bring are edited on the event (C3/C4/E5 and the School event).
- Build order: the model first (From, `homeAfter`, route per event, done per outing, medal switch), keeping today's screens working; then the event form rows (From, Bring, Before/After, Medal), then the windows and home button. Nothing here is a cut-down version: today's school morning is the first case of the same rules.

### Repeats, dates and changes (user, 2026-11-09) [proposed; sketches SK10–SK11 on "Sketches (review)"]
Research: reports/calendar-event-features.md (Apple, Google, Outlook, RFC 5545 / 9253, family apps). No mainstream calendar links one event's start to another's end, and none skips school holidays. Both are this app's own rules. **One scope rule for everything except a just-once event** (user, 2026-11-09): day-template slots (wake, meals, bed), School and every-week items all open their edit screen with two tabs, **"This day"** (default) and **"All days"** (not "Every week": that is the type picked when adding, so the scope uses other words), and Save on All days asks "Change from when?". For a template slot "All days" means every day of its day type (Mon–Fri, Sat or Sun) and the split makes a new template version from that date; for School it means every school day. A just-once event has no tabs. Dragging a dot on the clock changes this day; the card opens on "This day" and switching to "All days" applies the same change to the series. The parts below (Repeat, Runs, holidays, linked time) are on events; template slots only get the tabs.
- **Repeat**: every week on chosen days (DayChips, in a sub-page of the card), every 2–4 weeks, or every day. Monthly ("2nd Tuesday", "the 15th"), yearly, multi-day all-day events and an extra one-off session (a make-up class) come next in the same plan (backlog 6c).
- **Runs** (sub-page, SK10 ②): **Starts** {date} (default: the next day it happens) and **Ends**: "End of this term" (from the term data: MOE, or the school's own `termDates`; the caption names the date), "On a date" (inclusive), "After … times", or "No end". Stored as `startDate` + `end {kind: term | date | count | none, value}`. A `term` end is resolved when the days are worked out, so a term-data update moves it.
- **Skip school holidays** (switch, in Runs): on by default for School and for events linked to School, off for others. Applied when the days are worked out, from the bundled calendar (vacation, school holiday, public holiday, day off in lieu), never stored as skipped dates, so a data update leaves nothing stale. An event linked to School always follows School's days, so for it the switch is replaced by "No school days".
- **Linked time** (Time row): "School end + {n} min" (0–60, step 5) with the length kept; the caption shows that day's worked-out time ("1:45 – 2:45 pm today"). Worked out per day: a half day or a shorter school day moves the class and the bus home with it. Chains as in "Events: one shape": the bus home follows the last event of the chain on that day (the class when there is one, else School).
- **No school days** (row and sub-page, only on linked events, SK10 ③; user, 2026-11-09): "Skip" (default; today's rule) or "At a set time" with its own time and **Going** row: on those days the event starts from Home and needs a trip.
- **Edit scope** (user, 2026-11-09: two tabs, no third choice; sketches SK6–SK10 redrawn from the built boards, see "Keep it as plain as the built screens"): "This day" changes that day only (the label is "This day", not "Today", so it reads right on Tomorrow or any other day). It is stored as an exception keyed by the original date (`EventException { eventId, originalDate, cancelled?, start?, end?, bring? }`); only the fields changed override the series. "All days" asks one thing on Save: **"Change from when?"**, a small card with tabs "Today" (default), "Next {weekday}" and "Date", one caption when changed days no longer fit, and Save / Cancel (SK10). The series is split there: the old part ends the day before and the new part starts on that date. Days before it never change.
- **Keep it as plain as the built screens** (user, 2026-11-09: the sketches had grown wordy; the built C4, E5 and C6 are the measure):
  - The type (Just once / Every week) is picked once, when adding (C3/C4 Repeat tabs). Every week there adds only **Runs**: two fields "{start date}" → "End of term" (or a date, or "No end"), under the Days chips. A just-once item has no Runs and no scope tabs. The type is not changed later: remove it and add it again.
  - Editing a repeating activity is **E5** with the scope tabs at the top of the side column. **All days** (SK7): the Repeat row becomes **Days** (chips) and **Runs**, then "Skip school holidays"; side column: "Every {days}" (head) and "Remove every week". **This day** (SK8): Days, Runs and holidays are hidden; side column: "{Day d Mon} only" (head) and "Skip this day". "Save changes" as now.
  - Day-template slots (wake, meals, bed) edit in the **C6 slice card** with the same tabs under the title (SK6); the right column's day tabs become "Today" / "Tomorrow" in grown-up mode. "Changes start tomorrow." goes away (Save on All days asks from when).
  - **School is an event, so it edits on the same E5 screen as an activity** (fixes a clash with "Events: one shape", 2026-11-09): All days shows Days, Hours, Arrive by, **Terms** (no Runs), then Going, Bring, Missions, Medal as one-line rows; This day shows the hours and "Skip this day". Tapping the School slice in grown-up mode opens it.
  - **No explanatory sentences on these screens.** Values, pictures and short labels only; rules live in this spec. Sketch notes are drawn outside the screen, never as screen text.
  - Linked time, No school days and the event parts (From, Bring, Missions, Medal) stay as rows further down the E5 form (as C3g), each one line, no caption.
- **School keeps its terms** (user, 2026-11-09): School has no Runs. Its days come from the term data (MOE, or the school's own `termDates`), so its All days screen shows **Days**, **Hours**, **Arrive by** and a **Terms** row ("MOE 2026 · Term 4 ends 20 Nov ›", opening the term and holiday list) instead of Runs.
- **Where the kid goes changes: "from when?"** (user, 2026-11-09). One rule for a school transfer, preschool → school (Primary 1 starts), school or preschool → at home, and adding a place later:
  - Entry: Settings → the kid's School section → the "School" row (Goes to, then the S2 search). After a pick, Save asks **"Starts on"**: tabs "Next term" (default; the first day of the next MOE term, e.g. Term 1 for Primary 1) and "Date". A small card like "Change from when?", with Save / Cancel.
  - The kid's School item is split there: the old place ends the day before, the new one starts that day. Past days never change (the diary keeps the old school).
  - From the new place: terms and holidays, hours, arrive-by and latest (the medals), the medal switch (on for a school, off for a preschool). The trip is new too: after Save, **S3 "Getting there" opens** for that kid; until a route is set the new place has no strip.
  - Kept: items linked "After School" follow the new School's end; every-week items and missions stay.
  - Until the date: the School section shows one extra row "From {d Mon}" → "{new place}" with "›". It opens the same "Starts on" card with the picked place, plus **"Pick another school"** (back to the search; the date stays) and **"Cancel the change"** (`lateText`; user, 2026-11-09: the plan can change or fall through). Cancel asks once ("Stay at {old place}?" Stay / Keep the change), then removes the split and the new trip; the old place simply carries on. Nothing else on screen.
  - After the date has passed there is nothing pending to cancel: going back (or to a third place) is just another change with its own "Starts on". Days already lived keep the place they had.
- **Exceptions when the series changes**: an exception is kept when its original date is still a day of the new series; otherwise it is removed, and the save card lists them first ("2 changed days no longer fit", one caption line each, "They will be removed." in `lateText`) with Save / Cancel.
- **Skipped today** (replaces the "Changed today" list and Undo, user comment 2026-11-09): a skipped slice stays on the clock, faded; tapping it opens the card with **"Bring back"** where "Skip today" was. There is no change list and no undo stack: Bring back and Cancel are the only undo.
- **Notes** row: free text, grown-up screens only.
- **Not in this app**: attendees and invitations, attachments, busy/free, privacy flags, URL field, per-event time zone (the family zone is N4). Live-traffic leave times stay later (the fixed `leaveBefore` covers it); export to Apple Calendar is later and writes plain times (EventKit keeps one rule, no skipped or added dates, no links).
- Order of work: after "Events: one shape" (the anchor model is its `From`), before the grown-up mode boards (SK6–SK9) are redrawn as real boards.

### Event form rows for 6b (2026-11-10; board G2b, layout v24)
At the end of the C3 / C4 / E5 form (the card scrolls, as C3g), one line each, label 104, value 232, "›" at 814, pitch 96: **From**, **Bring**, **Missions**, **Medal**. (No school days and Runs come with 6c.)
- **From** → a centred `ConfirmCard` (like the C5 editor, tap outside = cancel) with `ChoiceCircles`: **Home** (`home` picture) first, then each of the kid's items that ends at or before this item's start on every one of its days (School first, then by end time), up to 5. Picking "After {item}" sets the start to that item's end, hides the Going / Leave rows (same place, no trip) and makes the start field read-only ("after {item}"). Picking Home shows Going / Leave as C3g. Row value: "Home" or "After {item}".
- **Bring** → a centred `ConfirmCard` with an `IconPicker` in multi-pick mode (up to 4): the kit's bring group (today: backpack, lunchBox, waterBottle; the bring kit batch adds swimsuit, goggles, towel, rollerblades, helmet, libraryBag) and a "More" slot for the whole kit. Row value: the first picture 48 + names joined by " · "; "Nothing" (soft) when empty.
- **Missions** → a pushed sub-page in the same form card, header "← Missions · {item}": two sections **Before** and **After**, each with C5 rows (≡, picture 48, name, "›"; reorder by ≡) and "+ Add" (up to 4 per section); add / edit uses the C5 `ConfirmCard` editor. Row value: the names, "before" ones first, the after ones with "(after)"; "Nothing" when empty.
- **Medal** → a `CrayonSwitch` 96 × 52 on the row itself (x 232, centred on the row), no sub-page. Off and at 45 % (not tappable) when the item has no trip (From = After, or Going = None).
- **Home button label per window**: morning "Missions →"; before an outing "Before {item} →"; after coming home "After {item} →"; evening (later) "Pack for tomorrow →". {item} is the item's name as typed; if the label does not fit on one line, it is "Missions →".
- **C5 days per mission**: the C5 editor `ConfirmCard` gets a **Days** row: seven `DayChip` 56 (all on by default). A mission with fewer days shows them as the caption under its name in the C5 list ("Thu", "Mon · Wed"); every day shows no caption.

### Trips on items: the "Going" row [board C3g]
- C3, C4 and E5 get two rows at the end of the form, under "Skip school holidays" (the form card scrolls to them; board C3g shows it scrolled down, with the top edge fading into the card):
  - **Going** (label as the other rows; part `ChoiceCircles`, also usable for any one-of picker with pictures): five 88 slot circles with a caption under each, gap 24: None ("–" in `softText`), Walk (`shoe`), Bus (`busDouble`), Car (`car`), Taxi (`taxi`). The chosen one has the pick-blue ring and a bold caption, like "What". Default None.
  - **Leave** (shown when Going is Walk, Car or Taxi): `−` 72 · "{n} min" (body bold, 112 wide) · `+` 72 · "before · {h:mm am}" (body `softText`, the leave time from the item's start). 0–90 in steps of 5; default 10.
  - By Bus the Leave row reads "Uses Our buses ›" (body) and opens C2: the stop, buses and walk time come from there.
- The preview line under the day list adds "Leave {h:mm am} by {way}."
- Until it is built, trips come from the seed.

## S1–S4 · First-run setup (boards S1–S4 on "Building now", 2026-11-09; build step 6) [board]
- Shown once, on an iPad with no family yet, before any kid screen. Four steps, one screen each, on the grown-up frame and lines (layout `grown`: form card 64–882 from 176, labels 104, controls 232, side column 930–1312, action button 930 / 872, 382 × 96).
- Header: "←" `RoundButton` 80 goes back one step (S2–S4; S1 has none), title (title 48) at 168 (64 on S1), then on the right "Step {n} of 4" (caption) and four 28 dots, filled up to the current step.
- No grown-up lock during setup (there is no family yet). S4 turns it on.
- Going back keeps every value. Nothing is saved until "Start" on S4; if the app quits before that, setup starts again at S1.
- **What "Start" creates** (main session's build, accepted 2026-11-09):
  - Each kid gets starter day templates from the seed shapes. A kid with a school, Mon–Fri: Sleep → Breakfast (wake 6:30) → School (arrive-by … hours end, locked, with the S3 trip) → Free time → Dinner 6:30 pm → Shower → Sleep 8 pm. Sat and Sun: the seed weekend. A kid without a school: Kid B's every-day template. The grown-up then fixes the times in C6.
  - Starter missions: a kid with a school gets Wake up · Brush teeth · Get dressed · Breakfast · Pack bag · Shoes on; a kid at home gets Wake up · Brush teeth · Shoes.
  - Templates apply from 1 January of the setup year, so today already uses them.
- **Where the kid goes in the day** (S2; user, 2026-11-09: kids go to preschool or childcare from about 2, so age decides nothing): each kid's tab starts with a three-way `CrayonTabs` row "School" · "Preschool" · "At home", nothing picked for kids under 7 and "School" picked from 7. "School" shows the school search form. "Preschool" shows the same form, searching **the preschool list** (`preschools-sg.json`, 2026-11-09: 1,784 active ECDA centres plus MOE-registered kindergartens and named upcoming ones; open data, bundled from the private data repo like the international list) together with international schools that have early years. Result rows: the centre name over its **address** (many centres share a brand, e.g. "My First Skool"), tagged "Preschool"; active centres first. After a pick: the field shows the name with the `playground` picture (until a `preschool` kit picture exists), the caption becomes check + "Preschool · {area}". Rows: Days (Mon–Fri on), **Drop-off** and **Pick-up** on one row (time field, "pick-up" caption, time field), **prefilled as a suggestion** from the centre's declared hours ("from the ECDA listing") or the type default (child and infant care 07:00–19:00, "ECDA standard hours"; kindergarten blank); editing removes the caption. Closures, set from the centre type: child and infant care: a check "Closed on public holidays" (on), which also closes Teachers' Day and Children's Day (from `preschool-calendar-rules.json`), no MOE row; kindergarten (incl. MOE Kindergartens): "Use MOE school terms for holidays" on. Both: a link "Add your centre's Development Days" (6 for child care, 3 for kindergarten; each centre picks its own) with the caption "Add other closure days later in Our kids." Never assume an early closing on holiday eves. It makes a "Preschool" block on that kid's clock with its own trip in S3 and no medals. "At home" hides the form and shows "{Name} is at home in the day." Kids at home skip S3.
- **Latest lives on the school record**, for every way of going: late grace = Latest − Arrive by (0–30). The medal's L2 uses it whether the kid walks, rides or takes the bus; C2's "Late up to" row shows and edits the same value. The default 15 min applies only when no school was entered.
- **S3 trip time**: by bus, the school trip's "leave before" = walk + ride, rounded up to 5 (the timetable look; the live look counts from the real bus). Walk, car, taxi: a "Leave {n} min before" stepper (default 10). S3 shows every kid with a trip as a tab (see "S3 · Getting there").
- **Data sources**: a grown-up screen with the data.gov.sg and OneMap attribution, opened from a "Data sources" link under the S2 school caption and from a caption link "Data sources" at the foot of C1 (Our kids), next to the action area.
- **Row labels** on S2 and S3 (and every grown-up form) are caption bold (24, the app ships Playpen medium and bold only) `softText` on one line in the 104–232 column, as on C2 ("Arrive by" wrapped in body type).
- **Debug only**: "Load sample family" (confirm copy in "Seed data in M2"); links familyplanner://s1 … s4 open a setup step (s2–s4 prefilled with the sample family, no unlock, nothing saved unless Start is tapped; over an existing family Start asks first: "Start over with this setup? The family on this iPad is replaced." with "Replace" (`lateText`) / "Cancel").
- Joining a family from another iPad (sync, backlog) comes later. The "Start a new family / Join" choice is not shown yet.

### S1 · Family [board S1]
- Title "Hello! Who's in the family?".
- One form card per kid (64–882, 296 tall, 32 apart):
  - "Name": `CrayonField` 352 × 72 with the kid's `KidFace` 40 inside; "Age": field 112 × 72.
  - "Colour": four swatches 56 (blue, orange, green, purple); picked = ring. Two kids never share a colour: picking a taken one swaps the two kids' colours.
  - "Face": `kidGirl` and `kidBoy` 64; picked = 72 ring. A face the kid draws is M6 (hidden).
  - Defaults: first kid blue, second orange; face not picked until tapped (the field shows the colour dot until then).
- Under the cards: "Add a child" (plus 72 + link body) and the caption "One child? Every screen shows just one panel." Up to 4 kids (3–4 kids use the A2f family layout). **Remove a kid** (board S1, 2026-11-09, replaces the "Remove" text link): a `RoundButton` 48 with `MarkerGlyph.close` (× , two strokes M14 14 L34 34 M34 14 L14 34, width 5, ink, drawn 24) sits on each card's top-right corner, centred 12 in from the corner (x card right − 36, y card top − 12), overlapping the card edge; touch area 64. It shows on every card while there are 2 or more cards, and hides when only one is left. A card with nothing typed is removed at once; a card with a name or age asks first in a small card pointing at the ×: "Remove {name}?" with "Remove" (`lateText`) / "Keep". VoiceOver: "Remove {name}" ("Remove this child" while the name is empty).
- Side column: the kit `home` picture 280, "This iPad is for the whole family." (head), "Names, ages and colours show on every screen." (body). The family's own home drawing is never used here.
- "Next →" is off until every card has a name, an age and a face (user, 2026-11-09: a face is not optional). Until a face is picked the field shows the colour dot.

### S2 · School [boards S2 (picked), S2s (search open)]
- Header: one `CrayonTabs` tab per kid (200 × 72 with `KidFace` 40), as in C1. The tabs follow the title at gap 24 (no fixed x); "Step {n} of 4" and the dots stay at the right end (S2, S2s, S3; board fixed 2026-11-09, layout v20).
- **School** (search, 2026-11-09; data: bundled `schools-sg.json` (MOE, 337) and `international-schools-sg.json` (81), searched together):
  - Field 610 × 80 at (232, 304), placeholder "School name". Caption "Type your school's name" (y 392).
  - From 2 letters: caption "Tap your school"; a list card 610 wide at field bottom + 40 (y 424), over the rows below, with up to 8 matches, rows 64: the school name (body bold, `link`) over a caption: MOE school "MOE primary · {planning area}" (secondary / mixed by level); other school "International · {first curriculum}" plus " · own term dates" when it does not follow MOE terms. The **last row is always** "+ Not in the list? Type the name" (plus 32 + body bold `link`).
  - Matching: every typed word is the start of a word in the school's `searchKeys`, or the whole text equals a key (initials such as "PLMGS"). Order: exact key, name prefix, word prefix; primary before others; then A–Z.
  - No match: only the "Not in the list?" row, caption "No school with that name".
  - **Picked** (board S2): the field shows the school picture 48 + the name (body bold); the caption becomes the check picture 32 + the match caption ("MOE primary · Woodlands"). Days default Mon–Fri.
  - **Hours from the school**: when the school's own website states them (`school-hours.json` / `dailyHours`, status found or partial), Hours, Arrive by and Latest are prefilled, and a caption under Hours reads "From the school website, checked {d Mon}". Arrive by = the stated start; Latest = start + 10 min unless the site gives a later "gate closes" time. Everything stays editable; editing a value removes the caption. Nothing known: the fields stay empty with the seed placeholders.
  - **Not in the list**: the field keeps the typed text as the school name; no picture (school picture slot as before); hours empty; MOE terms off.
- Rows (label 104, control 232; picked state): **Goes to** 208 (School · Preschool · At home, tabs 180 × 72, gap 12), School 304 (caption 392), Days 448, Hours 544 (source caption 632), **Arrive by** 680: time field, "latest" (caption), second time field (one row; both 180 × 80, gap 16), MOE terms row 792. The "no school" line is gone: "At home" replaces it on that kid's tab.
- **MOE terms row**, set from the pick:
  - MOE school, or `followsMoeTerms: true`: `CheckMark` on, "Use MOE school terms for holidays".
  - `followsMoeTerms: false`: off, and the row reads "Uses its own term dates" (body) with "{n} breaks from the school website" (caption) when `termDates` exist; otherwise "Add the school's holidays later in Our kids" (caption). The app fills the holiday list from `termDates`.
  - Not known (`null`) or typed by hand: off, and the row asks "Does your school follow the MOE term dates?" on one row so the card still ends at 968: the question (caption) at y 792, then "Yes" / "Not sure" pills 140 × 64 at y 828 (gap 12); "Yes" turns the check on. Nothing scrolls.
- Side column "Medals come from these times" (head): Gold, Silver and Bronze, each with its medal picture 64, the name (body bold) and one caption filled from the fields ("ready 5 min before it's time to leave", "ready when it's time to leave, in by {arrive by}", "ready in time to be in by {latest}"). Then: "Later: just “Ready!”. No medal, no sad face." (two caption lines at s 0.984) The rule itself is in "A2 live look", Medal.
- Only the chosen school's id and the values the grown-up confirmed are stored, on the iPad. The app never sends which school was picked.
- Data sources are shown on an About / Data sources screen (Singapore Open Data Licence attribution for data.gov.sg and OneMap). **School data in builds** (user, 2026-11-09): the school, preschool and calendar data is public information and **every real build ships with all of it**, so search works offline from the first run. Files that cannot sit in the public repo (the international and preschool lists) are versioned in a **private data repo**, and the build copies them into the git-ignored resource paths (a `make private` step); "private" means not tracked in git, never left out of the build: every build anyone installs (local, device, TestFlight, App Store) must contain them, and a device or release build fails with "run make private" when they are missing. Only CI and public clones, behind an explicit flag, build without them (MOE-only search plus "Not in the list?"). Later the app fetches the latest data from a data store, with the bundled copy as the offline fallback. Before the app goes to other families, the international names and addresses are rebuilt from the schools' own sites (backlog).
- **Side column on the other tabs**: Preschool: "Drop-off and pick-up go on {Name}'s clock." (body) and "No medals for preschool. Missions are picture cards a grown-up taps." (caption). At home: "{Name}'s day is on the clock: naps, meals and play." (body) and "Change the times later in Our day." (caption). The medals list shows only on a School tab.
- **Preschool picture**: kit `playground` until a `preschool` kit picture exists (next kit batch).
- "Next →" goes to S3 for each kid with a school, in tab order. Kids without a school skip S3.

### S3 · Getting there (new 2026-11-08; kid tabs 2026-11-09) [board S3]
- Third first-run step, right after S2. One screen for all kids who go somewhere (School or Preschool); kids "At home" are not in it.
- **Header** (user, 2026-11-09: one kid at a time with Next felt clumsy): "←", title "Getting there" (shorter than "Getting to school", so the row fits), then the kid `CrayonTabs` as on S2 (200 × 72 with `KidFace` 40, gap 12), a 24 space, "Step 3 of 4" (no kid name) and the dots. With 3–4 kids the tabs become face-only (88 × 72). A tab whose route is not finished shows a small `hurry` dot on its face.
- "Next →" goes to S4 once every tab is finished; it does not step through the kids. **Finished** (main session, accepted 2026-11-09): by bus, once the route has a stop (bus numbers stay optional, since a build without live times cannot list them); walk, car and taxi are always finished.
- **Home** (side column, top; also in C1 later; **ships with N11**, hidden until the map picker exists, so there is never a dead button): "Home" (head), a map `RoundButton` 64 with a pin glyph, "Set on the map" (body bold) over "For walk and car times. Kept only on this iPad." (caption). It opens the map picker in "Where is home?" mode: centred on the school, "Near me" asks for location once (the grown-up is usually at home during setup), drag a pin, "Use this place". Set: the row reads "Home · set" with "Change". Skipped: walk and car steppers stay manual. One home for the family, shared by all kids' routes.
- **Going**: `ChoiceCircles` Walk · Bus · Car · Taxi (shuttle comes with N1b). Default Bus.
- **Stop** (Bus only): the same search field as C2 (see "Bus settings (C2)"): name or code, list of up to 8 matches, tap to pick. Board names are made up ("Opp Sunny Park"). No match leaves Next on.
- **Buses** (Bus only): pills (180 × 72) for the numbers that call at that stop; pick one or more. Caption "Buses that stop there. Pick the ones to school."
- **Walk** and **Ride**: −/+ steppers, minutes (default 10 each). Car, taxi or walk: only "Leave {n} min before" (as the Going row).
- Side column: "On school mornings" — "Leave in" = her bus at the stop − the walk; "Arrive by and latest come from the school step; they set the medals." (board copy); change it later in Our kids › Getting there. Next → S4.
- Footnote: "Live bus times are built into the app. If they are off, the morning shows the timetable instead."
- Bus pills on the board read 12 / 34 / 56: made-up numbers. The real list comes from the LTA stop.

### S4 · Almost done [board S4; switch list 2026-11-09]
- **A list of feature switches** (user, 2026-11-09: S4 is where on/off features go, now and later). Rows 120 tall on a 140 pitch from y 216: picture 56 at x 104, title (body bold) over one caption line (what "off" means where that matters), and the control ending at 842. The same list is the grown-up screen **C9 "This iPad"** later; S4 is its first-run view.
- **Row kinds** (one `SettingRow`): switch (`CrayonSwitch`), permission ("Allow" pill that asks the system), link ("Settings ↗"). Rows for features not built yet stay hidden and leave no gap.
- **Rows now**, all on by default:
  - **Grown-up lock** · "Face ID before grown-up screens" (`MarkerGlyph.lock`).
  - **Live bus times** · "Off: the morning shows the timetable" (`busSingle`). Off = no live arrival calls (morning and home use the timetable look). Stop search and the list of buses at a stop in S3 / C2 still use LTA stop data: that is setup, not live times.
  - **Medals** · "Gold, silver and bronze for leaving on time" (`medalGold`). Off = no medal anywhere; the slide still ends on "Ready!". This is the family-wide switch; the per-event medal switch (Events) applies only while it is on.
  - Later rows, hidden until their feature is built: Notifications (the leave-time nudge; permission row), Microphone (M5), Camera and photos (M6), Screen Time (link).
- Caption under the rows: "More switches join this list as features arrive. Change any of them later in Our kids." (Playpen has no "›"; C9 is not built yet.)
- A row caption may take two lines (the lock-off caption does at 738); the row then grows up to 140 and stays on the 140 pitch.
- **`CrayonSwitch`** (new part): box 96 × 52; the drawn track is a pill **92 × 28 centred in the box** (`tab-on` art when on, `tab-off` when off; the art has its own margins), so the knob 44 stands taller than the track; knob 44 (`slot` art) at x 48 on / 4 off with the check picture 28 inside when on; 0.2 s slide; touch area the whole row. VoiceOver: a switch with the row title.
- **Grown-up lock off** (user, 2026-11-09):
  - The 2 s hold on the clock stays the only gate; Face ID is skipped. The caption then reads "Off: anyone who holds the clock for 2 s can change the plan." (caption `hurry`), shown while it is off. No dialog when turning it off.
  - Grown-up screens still go back home after 2 minutes idle (a kid should not find the iPad left on a grown-up screen), but with no Face ID on return. The app-switcher cover is dropped while the lock is off.
  - Turning it **on** (S4 or C9) asks for Face ID once to check it works. If Face ID is not set up or fails, the switch stays off with "Set up Face ID in iPad Settings first."
  - Per iPad: the lock is a setting of this iPad (a parent's iPhone can differ). Live bus times and Medals are family settings.
- **C9 "This iPad"** (later screen, same list): opened from a "This iPad" caption link at the foot of C1 (next to "Data sources").
- Side column "You're set up" (head), gap 24:
  - the kids' faces 40 and names (body);
  - the school picture 56 with "School" (body) over "{start} – {end}" (caption);
  - the way picture 56 (bus, car, taxi or shoe) with "Bus from Our stop" over "walk {n} min · ride {n} min" (car, taxi, walk: "Leave {n} min before");
  - caption "Change any of this later in Our kids."
- "Start →" saves everything, turns the lock on and opens the home (A1, or E1 with one kid).

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
- **Night mapping** (user, 2026-11-09: "map the base design set to dark"). On the canvas the one picture of this table is board **0a2 · Night colours** (next to 0a); board A1n is drawn with it (layout v22). Every day token has one night token, and no screen picks night colours by hand. **No pure white at night.** Contrast is on `night` #22213A.

  | day token | day | night token | night | contrast / note |
  |---|---|---|---|---|
  | `paper` (page) | #F6F2EA | `night` | #22213A | — |
  | `ink` (text) | #2B2833 | `nightText` | **#D8D2E8** (was #F4EFFF) | 10.6:1 |
  | `softText` | #625D6E | `nightSoft` | **#A6A0C2** (was #C9C3E0) | 6.2:1 |
  | white surfaces: hub, picture plates and circles (#FFFFFF, #FBF8F1) | white | `moonPaper` | **#D8D2E8**, ink outline, ink text on it | ink on it 9.9:1 |
  | clock face under the slots | #EFE8D8 | same | #EFE8D8 (lit, not dimmed) | the crayon slot colours read as by day |
  | `InkButton` (ink fill, white text) and white `RoundButton` / off tabs | ink / white | `nightControl` | fill **#2E2C4A**, marker outline `chalk` **#E9E4F5** (4 pt), label and glyphs `nightText` | same shapes and sizes as by day (e.g. `InkButton` 382 × 96, corner ≈ 26) |
  | selected tab (sky crayon) | #8FD3F4 | same | #8FD3F4 | — |
  | Kid A / Kid B dots | blue / orange | night kid colours | #56B4E9 / #E69F00 | non-text |
  | `link` | #2F6FD0 | `nightLink` | #56B4E9 | — |
  | kit pictures | — | same | unchanged; on `moonPaper` plates | the yellow pencil sits on a `nightControl` round |

  - The clock's hour ticks and numbers use `nightText` for 12/6 and `nightSoft` for the rest. The red hand is unchanged.
  - Grown-up screens follow the iPad's own dark mode with the same table (their boards come later).
- **Right panel at night** (board):
  - Kid A: "Bed in" (body, soft) and `TimeLeft` display 96 "20 min" until bedtime.
  - Then a "Tomorrow" row: plated 64 picture, "Tomorrow" (body bold) over "School, leave {h:mm}" (caption).
  - Kid B: now/next circles as by day; next = wake-up (sun).
  - Button "Diary →". **[later M5]**: hidden in M2, as by day.

## Sky switch: the kid's day/night switch (new 2026-11-08) [board 0g; on every kid home: A1, A1m, A1n, E1, E3, E3b]
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
| New slot | the slot picture hops 1 → 1.15 → 1; the hub title swipes sideways inside the hub disc (clipped to the disc): the new title comes in from the left and pushes the old one out to the right; when time goes back (time machine) it comes from the right. Not played for the first slot at launch (user, 2026-11-09) | 0.45 s | text changes in place |
| On the hour | the red hand disc pulses once | 0.6 s | none |
| Mission done | the check draws itself, 6 crayon sparks | 0.35 s | check appears |
| Slide to go (build step 5) | from touch-down to release the knob picture plays (user, 2026-11-09): the bus **bobs up and down** (6 pt at knob size, with a ±2° rock, 0.9 s per bob) and its wheels turn at the finger's speed, backwards when dragged back; the star knob plays its rig: the star **dashes forward** up-right twice with its speed lines following 80 ms later, then twinkles (rig `star`, move `dash`); a hop and a green wash at the end | while dragging | colour change only |
| Gold (build step 5) | medal drops in and swings, crayon confetti | 1.5 s | medal fades in |
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

## Grown-up mode (final design 2026-11-09; boards G0–G8 on page "Grown-up mode (next to build)") [board, ahead of build]
User decisions, 2026-11-09: C6 is absorbed into grown-up mode; C1 becomes Settings; a List view is kept. Screens are as plain as the built ones (values, pictures, short labels; no explanatory sentences; no lines in cards).
- **G0 · Way in**: the pencil `RoundButton` 80 (yellow pencil picture 56) at x 1212, y 44 on every kid home → C0 Face ID → G1. The 2 s clock hold stays; a hold on a slice opens G1 with that slice picked.
- **G1 · The day on the clock** (replaces C6; boards G1, G1c): C6's clock, drag rules and slice card, on a real date. Header: "←" (back to the kid home; locks again), "Our day", kid tabs, then `CrayonTabs` **List** 110 · **Undo** 130 · **Settings** 160 at the right. Right column: one **day button** (382 × 72, `CrayonTabs` off look): "Today" (body bold) + "Mon 9 Nov" (body soft) + a down chevron; on another day it reads "Sat 14 Nov". Tap → **G1c** day picker (user, 2026-11-09: look ahead, e.g. at the weekend): a small card with the month (head) and ‹ › round buttons, two weeks of date chips (62 × 84, today underlined, the picked one in sky), and a "Today" link. Picking a day closes the card and shows that day on the clock. A template slot (wake, meals, bed) opens the C6 slice card with "This day" / "All days" under the title; School and activities open G2/G4. "+" on free time adds (C3/C4). "Save" (InkButton). **Undo** only steps back drags made since the last Save; it is not a change history. **Undo / Redo** (user, 2026-11-09): two `RoundButton` 72 at the bottom right of the clock area (x 722 and 810, y 880), with the new marker glyphs `undo` / `redo` (36, ink). Always shown; **off** = the button at 45 % with the soft glyph (nothing to undo / redo), **on** = full ink. One tap = one step: Undo takes back the last change (one finished drag, one time typed in the slice card, one "Make this free time"), Redo puts it back; they only reach back to the last Save, and Save clears them. Throwing away every unsaved change at once is "Don't save" on G1d. The header right end is always List · Settings. **Leaving with unsaved drags** (List, Settings, ←, a kid tab, another day) asks first (G1d): "Save the changes?" (head), one line naming the change (body soft), then Save (ink) · "Don't save" (`lateText`) · Cancel.
- **G8 · List**: the kid's repeating and one-off items in one card, sections "Every week" (School, activities) and "Just once"; rows: picture 56, title (body) over "{days} · {time}" (caption), "›" → G2/G4/C4. Right column: "Add every week", "Add once" (plus 56 + link). Day-template slots are not listed (they are the day).
- **G2 · Edit an item, All days** (E5): For, What, Name, When, **Days**, **Runs** ("{start}" → "End of term"), Skip school holidays; scrolling on (**G2b**): From, No school days, Bring, Missions, Medal (switch), one line each. Side column: tabs "This day" / "All days", "Every {days}" (head), "Remove every week". "Save changes" → G5.
- **G3 · This day**: Days, Runs and holidays hidden; side column "{Day d Mon} only" and "Skip this day".
- **G4 · Edit School**: School (name ›), When, Days, Arrive by + latest, **Terms**, Going, Bring, Missions, Medal (on). Side column: tabs, "Every school day". Changing the school itself is G7.
- **G5 · From when?**: the small card on Save in All days ("Today" / "Next {weekday}" / "Date", one caption when changed days no longer fit, Save / Cancel).
- **G6 · Settings** (replaces C1): tabs per kid + "Family". Kid tab: About (Age, Face/colour), School (School, Hours, Terms), Getting there (To school, Home), Routines (Missions). Family tab: This iPad (lock, live bus, medals), Add a child, School lists. Foot: "School lists · {d Mon}" and "Data sources".
- **G7 · Change school**: "Starts on" card ("Next term" / "Date"); then S3 for the new trip; pending row and cancel as in "Where the kid goes changes".
- Night: grown-up screens follow the iPad's dark mode through the night mapping table.

## C0 · Grown-up lock [board + proposed details]

### Entry: the pencil button (user, 2026-11-09; proposed with grown-up mode, sketch SK5b)
- Every kid home (A1, A1m, A1n, E1, E3, E3b) gets a white `RoundButton` 80 with the kit picture `pencil` (56: a yellow crayon pencil with wood tip, lead, ferrule and pink eraser; user, 2026-11-09) at the top-right corner, x 1212, y 44 (user, 2026-11-09: its drawn right edge lines up with the main button's drawn edge, ≈ 1288, not the frame; centred on y 84 like the sky switch). Same look by day and night. VoiceOver: "Grown-up mode".
- Tap → C0 (Face ID) → grown-up mode on today's clock (SK6). The 2 s hold on the clock stays as a second way in; a hold that starts on a slice opens grown-up mode with that slice picked.
- Grown-up mode header: "←" (back to the kid home, locks again), "Our day", kid tabs, then "Undo" and "Settings" (SK9) at the right.

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
- **Getting there** (a section; built, PR 38):
  - "To school" → bus picture, bus plate, "leave about {h:mm} · in by {h:mm}", "›" → C2. The built row is plainer; the board's richer rows are ahead of the build.
  - "Home time" → "{h:mm} · pick-up at the gate", "›" → C2.
- **More** (board, 2026-11-08; in the side column, under "Add every week" and "Just once"): "Morning missions" → "{n} missions" ("1 mission"; "Nothing yet" at 0), "›" → **C5** with this tab's kid; shown from build step 5. "Drawings" → "ask for a picture", "›" → D1 **[later M6]**: hidden.

### Side column
- "After school" (head, h 52), then one `ListRow`-style item per every-week item:
  - 56 picture, title (body) over "{days} · {start}–{end}" (caption). No "›": the whole row is the button (iPad review, 2026-11-09).
  - When the caption does not fit on one line, the days go over the time on two caption lines ("Mon · Wed" / "3:30–4:30 pm"). Never cut it.
  - Tap → **E5** for that item.
  - Days text: "Mon · Wed"; all weekdays → "Every school day".
- "Add every week": 56 plus-picture + link text (body, `link`) → **C3** with "For" set to this tab's kid.
- "Just once" (head, h 52), then upcoming just-once items for this kid, nearest first, at most 5. Each shows "{Day d Mon} · {start}–{end}", with the same two-line rule (date over time) and no "›". Tap → **C4 in edit mode** (see C4).
- "Add once" link → **C4**.
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
  - One row per mission, 88 tall (built, PR 38), no divider lines (user, 2026-11-09: no lines inside cards; rows are separated by space): drag handle `MarkerGlyph` ≡ (soft), `KitIcon` 48, name (body), "›" (body `softText`). Drag ≡ to reorder; the order is the circle order on A2t.
  - "+ Add a mission ({n} of 8)" (`MarkerGlyph.plus` in a 56 ring + body `link`). At 8 the row is replaced by "8 is the most" (caption).
  - Footer caption: "Drag {handle} to reorder. Tap a row to change it." {handle} is `MarkerGlyph.handle` drawn inline at the text size (24, `softText`), the same rule as inline arrows; never the ≡ character, which Playpen Sans lacks.
- Tap a row or "Add" → a `ConfirmCard`-style editor, **centred over a dimmed screen** (tapping the dim area cancels without saving; main session's call, accepted 2026-11-08): Name `CrayonField` (max 14), `IconPicker` (kit pictures, no "+" until M6), "Remove" (`lateText`, edit only; asks "Remove {name}?" / "Remove" / "Keep") and "Save" (`InkButton`). A new mission defaults to `star` and an empty name; Save is off while the name is empty.
- Right column (cols 9–12): Kid B note "Picture cards. A grown-up taps them for now." (on the Kid B tab). No "Evening · coming later" note (removed 2026-11-09). The board's "Ready by" block is **N2** (hidden).
- Main button "Done" → back. Changes save at once and show on today's morning screen; done marks of kept missions stay.

---

## C3 · Add to the day, every week [board]

### Layout
- `GrownupScreen` header:
  - `RoundButton` "←" 80.
  - "Add to the day" (title 48).
  - Caption "Grown-ups only".
- Form card rows (label at x 88, control at x 232, tops given):

  | y | label | control |
  |---|---|---|
  | 200 | For | `CrayonTabs` single-select, 3 options of 180 × 72: Kid A, Kid B (each with `KidFace` 40), "Both" |
  | 296 | What | `IconPicker`: 5 slots 88 with gap 16, then a "More" slot. The picked one gets a 104 ring. |
  | 412 | Name | `CrayonField` 610 × 80 |
  | 524 | When | `TimeField` 200 × 80, "→" (head `softText`), `TimeField` 200 × 80, then the duration caption ("1 hour", "1 hr 30 min", "45 min") |
  | 636 | Repeat | `CrayonTabs` 2 options of 220 × 72: "Just once", "Every week" (on) |
  | 732 | — | seven `DayChip` 72, multi-select, M T W T F S S |
  | 836 | — | `CheckMark` 48 + "Skip school holidays" (body) |

  - **What** (board, changed 2026-11-09): one row of 5 picture slots, then a **"More"** slot (88 circle, "More" caption bold). The 5 are the pictures this kid uses most, with the picked one first. "More" opens a `PickerPopover` pointing at it with every item picture, 6 per row (slots 88, gap 16). Picking one closes it and puts that picture, picked, in the row's first slot. The row never wraps or scrolls, so the rows below keep their lines and C3k still fits. Asking for a drawing (D1, the old "+" slot) moves into the popover in M6.
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
- The button is disabled until valid. The first problem shows as a caption in `lateText` under its row, only after the first change (a fresh form shows no problem caption):
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
    - Shows 5 dates starting today. **Paging** (board, 2026-11-09): "‹" `RoundButton` 64 in the free label column at x 104, and "›" `RoundButton` 64 at x 772 (12 after the fifth chip, ending at 836). Both are centred on the chip row (y 752). The chips stay 96 wide and 12 apart, from x 232. "›" moves 5 days on. "‹" moves 5 days back and hides on the first page, since past dates are not shown.
    - Past dates are not shown.
  - At y 864: `CheckMark` 48, the star picture 40 (what it adds; not a state), then "A star on the clock that day" (body); gap 12. On by default for events. It adds a star picture at the slot on the clock.
- Side column:
  - Heading "{Weekday d Mon}" (head), e.g. "Saturday 14 Nov".
  - Caption "Just this day, for {Kid A | Kid B | both kids}." (The midnight sentence was dropped in the iPad review, 2026-11-09.)
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
- Header title "Edit {Name}". Caption "Grown-ups only".
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
  - Kid list chips (A2 family layout): the 76 progress ring takes the place of the colour ring, with the bare face (no ring) at the same 86 %; the colour comes only from the progress arc.
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

Small marker icons that were inline SVG on the boards are now marker-drawn too: search (S3), drag handle ≡ (C5, soft), clock (was E4, retired), lock (S4, yellow crayon body). They are `MarkerGlyph` cases in the same style.

- `ConfirmCard`: small `PaperCard` with title (head), body, and two buttons, the destructive one in `lateText`. It points at the control that opened it, like `PickerPopover`.
- `LockOverlay` (C0 overlay and card with the state table).
- Everything else uses M1 parts:
  - Screens: `KidScreen`, `GrownupScreen`
  - Controls: `CrayonTabs`, `DayChip`, `DateChip`, `CrayonField`, `TimeField`, `IconPicker`, `CheckMark`, `InkButton`, `RoundButton`
  - Content: `ListRow`, `TodayRow`, `PaperCard`, `KidFace`, `TimeLeft`

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
  - Day-type tabs: each as wide as its label + 16 on each side, gap 8, label on one line ("Mon–Fri" never wraps in the 382 column). Each day type has its own template, so Saturday and Sunday can hold their own morning (weekend school, church).
  - These are the only day types. **A weekday school holiday uses the Sun template**, so editing Sun also changes holidays. Under the tabs, the caption "Sun is also used on school holidays." (caption, `softText`) shows while Sun is selected.
  - Slice card 382 × 440:
    - picture 64 + name (head)
    - "Starts" `TimeField` 170
    - "Ends" `TimeField` 170. The field being dragged is outlined in `pickBlue`.
    - The effect on the neighbour (caption), e.g. "Shower now starts at 7:30 and is 30 min."
    - "Make this free time" (body bold, `lateText`)
  - Hint caption: "Drag a dot to move a time. Tap a slice to edit it." (The "+" explains itself on the clock.)
  - "Changes start tomorrow." (caption)
  - `InkButton` "Save the day".
  - **Bottom stack** (board, 2026-11-09): "Changes start tomorrow." sits just above the Save button (layout v6 box 822–858), and the hint sits above that (box 720–818). They are placed from the button up, not from the slice card down. If the hint would come closer than 8 to the slice card's bottom (on short iPads captions stay 24), leave the hint out and use it as the edit clock's VoiceOver hint.

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
  - **Tapping "+"** opens a new slice in the card for the **first hour** of that free span (all of it when it is an hour or less). The rest stays free; a leftover shorter than 15 minutes joins the new slice instead. The time is prefilled; you pick a picture and a name (user review PR #24, 2026-11-09).
  - The new-slice card shows the day pictures in a grid, **3 per row** (slots 88, gap 16). Every day picture can be picked, sleep included, and **the picture sets the slice kind** (sleep picture = a sleep slot, and so on).
  - Making a slice free joins it with free time on either side, so the number of slices on a template is not fixed.
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
