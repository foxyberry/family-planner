# M2 screen spec: the day and the home clock

Boards: A1, E1, E3, C0, C1, C3, C4, C3k, E5, E6 (design canvas, page "v3 · Crayon").
Public-safe: children are **Kid A** (older, school) and **Kid B** (toddler, at home). No school, stop, route or bus numbers appear here. Times in examples are seed values, not real ones.

Markers used below:
- **[board]**: drawn on the canvas, implement as written.
- **[proposed]**: the board does not show it; this is the design decision for M2. Change it here first if you disagree.
- **[later Mx]**: on the board but owned by a later milestone. In M2 the part is hidden, not shown disabled, unless stated.

---

## 0. Shared rules

### Grid and frame (iPad landscape 1376 × 1032 pt)
- 12 columns of 82, gutter 24, margin 64 (`GridMetrics`). Column n (1-based) starts at x = 64 + (n − 1) × 106.
- Header band y 48–128. Content y 176–968. Main button bottom edge at y 968.
- Spacing tokens: 8 · 16 · 24 · 40 · 64.
- Type: `CrayonType` hero 144, display 96, title 48, head 36, body 30, caption 24. Nothing smaller than 24.
- Kid screens use `KidScreen` (no scrolling; cap content). Grown-up screens use `GrownupScreen` (header and main button pinned; only the named area scrolls).
- Colour never carries meaning alone. Kid A is always blue (`kidABlue`) and Kid B orange (`kidBOrange`), always with the name next to the dot (`KidDot`).

### Grown-up form layout (C3, C4, E5, C3k)
- Form card: `PaperCard`, columns 1–8 (x 64, w 818 to keep the marker stroke inside 824), y 176–968.
- Label column inside the card: x 88, caption-weight body text in `softText`, label tops align with their control tops.
- Controls start at x 232.
- Side column: columns 9–12 (x 930, w 382, the 400 span inset 18 so the crayon spill stays inside).
- Main button: `InkButton`, side column, y 872–968.

### Seed data in M2 [proposed]
- Two kids from a fixed seed, editable only through C3, C4 and E5. Adding a child is M4 (S1).
- Kid A: school days Mon–Fri, school hours, wake-up, bedtime, two every-week items, one just-once item.
- Kid B: nap, bedtime, no every-week items, the same just-once item (made for "Both").

### Schedule model the screens assume [proposed]
- Each kid has a **day template** (sleep, morning routine, school or nursery block, dinner, evening, bedtime) from seed data, plus **every-week items** and **just-once items**.
- Priority when two things share time on one kid's clock: just-once > every-week > day template. The higher one is drawn and named; the lower one is cut around it. Nothing is deleted by an overlap.
- "Skip school holidays" on an every-week item hides it on dates in the holiday list. M2 uses seed holidays; importing them is later.
- The clock's day changes at **midnight**. A just-once item is on the clock on its date only, so it leaves at midnight. The C1/E6 "Just once" list keeps it until the kid's next wake-up time, so a grown-up can still see last night's event in the morning. (Agreed with the main session, 2026-11-07.)
- **Sleep across midnight** is stored as two slots, 0:00–wake and bedtime–24:00. The clock merges touching slots of the same kind into one sector with no edge line between them, and the merged slot is what "current", the 6 pt outline and "until" use (at 23:00 the hub says "until 7:00").

---

## A1 · Home, two kids (Kid A's 24-hour clock) [board]

### Layout
- Screen: `KidScreen` with an **empty header**. The clock uses the full height.
- Clock area: x 0–900, y 0–1032. It is not on the grid; the disc centre is at (448, 528).
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
  - Fill: crayon fill (wash + flicks, as in M1 `CrayonSurface`) in the slot colour.
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

  - mint, orange, green, coral, lilac and pink are new palette entries.
  - Text is never placed on these fills, so contrast rules do not apply to them.
- **Slot pictures**: each slot's kit picture (`KitIcon`, from the item's slot) at the slot's middle angle, radius 0.7R (about 260). Keep it between the hub (r 160) and the rim (r R − 8).
  - Size by slot length: ≥ 3 h → 104; 1–3 h → 84; 30–60 min → 68; under 30 min → no picture.
- **Hub**: white disc r 152, 4 pt marker outline, on top of the slots.
- **Hand**: the "lollipop" in `handRed` #E5484D.
  - Line 9 pt from r 154 to r 312 at the current time's angle.
  - Disc r 24 at r 336, crayon-filled red with a 4 pt outline.
  - Moves once a minute (`TimelineView(.everyMinute)` / `@Dependency(\.date)`).
- Accessibility label for the whole clock: "Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. Now {h:mm}, {slot}." On a school morning, M3 appends " Leave at {h:mm}.".

### Hub text (NOW rule)
- Three centred lines, M1 type steps only (agreed 2026-11-07):
  - "NOW": caption 24 `softText`, baseline about y 488.
  - slot title: title 48 `ink`, baseline about 548.
  - "until {end h:mm}": body 30 `softText`, baseline about 596.
  - The board's 44 and 26 were not type steps; these replace them.
- Slot title = the item's name (e.g. "Breakfast", "School", "Swimming", "Sleep").
- If the title is wider than 260 pt, use head 36. If it is still too wide, cut it at a word and end with "…". Never wrap.
- **Gap (no slot covers now)** [proposed]: title "Free time", second line "until {next start}". If nothing else is planned today: "Free time" with no second line.
- **No schedule at all** [proposed]: the disc is plain paper with ticks and labels, no slots and no hand change. Hub: "NOW" / "Nothing planned". No instruction to the child.

### Overlap and short slots [proposed]
- Overlaps resolve by the priority in section 0 before drawing, so sectors never overlap.
- A slot shorter than 10 minutes (2.5°) is drawn with 10 minutes' width, centred on its real time. It still shows no picture.
- Two short slots next to each other keep their order and push apart by up to 5 minutes each. If they still collide, the lower-priority one is dropped from the drawing; it stays in the data and in the side lists.

### Right panel
- **Kid A block** (spacing from the board):
  - `KidDot` (Kid A) + name, head 36.
  - **[later M3]** School mornings: "Leave in" (body, `softText`) with an 80 pt bus picture at right, then `TimeLeft` at display 96 ("34 min"), then the status "On time" (body bold `onTimeText`, 24 pt green dot).
  - **M2 instead** [proposed]: E1's "Next" list for Kid A (see E1).
- **Kid B block**, 64 below:
  - `KidDot` (Kid B) + name, head 36.
  - Row with gap 40:
    - "now": 160 circle in crayon `kidApricot` with a 104 picture inside, caption "now" under it.
    - "next": 104 white circle with a 64 picture inside, caption "next".
  - Bottom-aligned.
- **Main button**: `InkButton` "Missions →", full panel width, 96 tall, bottom of panel → A2. **[later M3]**: hidden in M2.

### States
- Weekend or holiday → E3 layout. One child → E1 layout.
- Kid B has no slot now: the "now" circle shows the play picture with caption "now"; if nothing is next, the "next" circle is not shown. [proposed]

---

## E1 · Home, one child [board]
- Same clock and hub as A1.
- Right panel: Kid A block, then **Next**:
  - "Next" head 36.
  - The first row: 104 picture, gap 20, then the title (head 36) over the time range "{start} – {end}" (body, `softText`).
  - The second row: 72 picture, title (body bold) over the start time (caption).
  - At most 2 rows (0f: kids never scroll).
- No Kid B block. Main button as A1 (hidden in M2).
- Empty Next [proposed]: "Next" + "Nothing else today" (body, `softText`).

## E3 · Home, weekend or holiday [board]
- Same clock. Weekend slots come from the weekend day template.
- Right panel:
  - `KidDot` + Kid A name (head).
  - Day name, e.g. "Saturday" (body, `softText`).
  - "No school, no bus" (48 bold). On a school holiday that falls on a weekday the line is the same; the day name shows the weekday.
  - The next just-once or every-week item for Kid A: 72 picture + title (body bold) over "{start} – {end}" (caption). Only one.
  - Kid B block as A1.
- Main button "Diary →" → B2. **[later M5]**: hidden in M2.
- No item left today [proposed]: leave out the item row.

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
- Card: `PaperCard`, 818 × 352, centred horizontally, y 320. Padding 48 × 64, gap 20.
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
  - `CrayonTabs` with Kid A and Kid B, each 200 × 72 with its `KidDot`. Exactly one is on.
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
  - "Day" → wake picture "Up {h:mm} · " + sleep picture "Bed {h:mm}". **[later M4]** editing; no "›" in M2.
- **School**:
  - "School" → school picture + school name (from settings).
  - "Days" → seven read-only `DayChip` 56 (on = school day).
  - "Hours" → "{start} – {end}" in "h:mm am" form.
  - "Holidays" → "Term {n} ends {Day d Mon}" or "No holidays set". **[later]** "›".
- **Getting there** **[later M3]**: hidden in M2.
  - "To school" → bus picture, bus plate, "leave about {h:mm} · in by {h:mm}", "›" → C2.
  - "Home time" → "{h:mm} · pick-up at the gate", "›" → C2.

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
  - "Cards" → "Wake up · Milk · Shoes", "›" → C5. **[later M3]**: hidden in M2.
  - "Taps" → "A grown-up taps for now".
- Side column: "Every week" with "Nothing yet" when empty, "Add every week", then "Just once" with items and "Add once". Same rules as C1.

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
  | 200 | For | `CrayonTabs` single-select, 3 options of 180 × 72: Kid A, Kid B (each with `KidDot`), "Both" |
  | 296 | What | `IconPicker`: slots 88 with gap 14. The picked one gets a 104 ring. The last slot is "+". |
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
- Focus: the focused field gets the blue focus outline (`kidABlue`, 610 wide) and a 3 × 36 caret in `kidABlue`. Its label turns `kidABlue`.
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
- `ConfirmCard`: small `PaperCard` with title (head), body, and two buttons, the destructive one in `lateText`. It points at the control that opened it, like `PickerPopover`.
- `LockOverlay` (C0 overlay and card with the state table).
- Everything else uses M1 parts:
  - Screens: `KidScreen`, `GrownupScreen`
  - Controls: `CrayonTabs`, `DayChip`, `DateChip`, `CrayonField`, `TimeField`, `IconPicker`, `CheckMark`, `InkButton`, `RoundButton`
  - Content: `ListRow`, `TodayRow`, `PaperCard`, `KidDot`, `TimeLeft` (M3)
