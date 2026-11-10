# Layout source: board redlines (design session, 2026-11-09) · layout v2

One JSON file per board, measured in Chrome from the canvas boards (v135). Board coordinates: 1376 × 1032 pt, y 0 = top of the glass (the status band 0–24 stays empty). Public-safe: no names, places, times or bus numbers (any text with digits or a kid's name was dropped; ids carry the meaning).

## File shape
- `global`: lines every screen shares (see below).
- `lines`: lines that belong to this family of screens (home / morning / grown-up).
- `regions`: each region's left and right edge and its anchor (`left`, `right`, `stretch`), following the spec's "Sizing formulas".
- `elements[]`: `id` (stable part name, `region.part[.n]`), `kind`, `x y w h`, `region`, `anchor` (the region's), `align` inside the region (`start` = on the region's left line, `end` = on its right line, `fill` = both, `inside` = placed by its own value), `baseline` + `font` for text, `stripLocal` (x/y in the 1248 × 340 strip frame) for strip parts, `text` only when it is a plain label.
- Text boxes are the glyph run (Range box), so `x` is where the letters start; use `baseline` for vertical placement. Part boxes are the board boxes; treat them as the visible edge (the crayon line runs on the box edge; ignore any fixed inset in the board art).

## Global lines (every screen)
- Status band y 0–24, empty. Margins: left 64, right 1312. Header band 48–128: ← button (64, 48, 80 × 80), title left 168, all header text on baseline 107; header right group ends at 1312.
- Content y 176–968; main buttons end at 968.
- 12 columns: 82 wide, gutter 24, lefts at 64 + 106 n (64, 170, 276, 382, 488, 594, 700, 806, 912, 1018, 1124, 1230). This is the reference grid on board 0a. Only 64 and 1312 are shared by every screen; the screen lines below (448, 928, 104, 232, 930, …) are deliberate and are not column edges. Place parts on the lines in each file, not on the columns.

## Screen lines (one family only; not on the 12-column grid on purpose)
- Home (A1, A1m, A1n, E1, E3, E3b): clock area x 0–900 (disc centre 448, 528; R 372), right panel left 928 (stretches to 1312), panel top 96, main button bottom 968, sky switch (40, 36, 160 × 96).
- Morning (A2, A2t, A2t-w, A3): strip 64–1312 × 176–516; kid list left 64, kid text left 172; missions column left 448 (stretches to 1312); baselines 107 / 584 / 757; circle top 612, caption top 732; bottom control 872–968.
- Grown-up (C1, E6, C2, C3, C3g, C4, E5, C5, C6): form card 64–882, row labels left 104, controls left 232, side column 930–1312, action button (930, 872, 382 × 96).

## Regenerate
`tools/layout-export.py` + `tools/extract.js` (design session scratchpad; needs the canvas boards and Chrome). Not needed in the repo. The tools hold no private words: the export reads them from `tools/private-terms.txt` (one per line, git-ignored, kept only on the design machine) and stops if that file is missing. Every text with a digit or a private word is dropped from the JSON. The Kid B board file is `KidProfileB` (renamed 2026-11-09).

## Contract (see the M2 spec, "Layout contract")
1. Board = source. 2. These JSON files = the machine copy the app places parts from (one modifier; no stack spacing between parts). 3. Canvas page "Redlines" = the same lines drawn on every screen, generated from these files. 4. The app's layout test checks the shared lines on four iPads.
Every board change: re-run `tools/layout-export.py <transcript> <this dir> <next version>` and `tools/redlines.py <this dir>`, publish, and tell the main session the new `layout vN` and the changed ids.

## Versions
- v1 (2026-11-09): 19 boards.
- v2 (2026-11-09): adds A3r (the ready kid's done view); `version` field in every file; board file names removed.
- v3 (2026-11-09): A3 bottom control is now the slide for a kid with no outing (bottom.slide); the pill is retired.
- v4 (2026-11-09): A3r done view named (missions.doneMedal / doneTitle / doneSubtitle, bottom.slide / knob / knobCheck / doneLabel); every slide captured as bottom.slide.
- v5 (2026-11-09): home boards on fixed panel lines (baselines 132 / 187 / 301 / 402 / 446 / 584 / 825, circles bottom 792); home lines listed in lines.baselines.
- v6 (2026-11-09): adds S1–S4 (first-run setup, grown-up lines); C4 date paging (`main.pageEarlier` at 104, `main.pageLater` at 772, 64 round, y 752); C3/C4/C3g/E5 "What" ends in a "More" slot; C6 bottom captions placed from the button up (`side.line.8` hint box 720–818, `side.line.9` "Changes start tomorrow." box 822–858).
- v7 (2026-11-09): copy from the iPad review. C2 redrawn to the built screen (rows Stop 208, Buses 352, Walk 496, Ride 600, Late up to 704; side "{Kid} to school" only, no "Live bus times" card (removed, PR #22); Done). C6 day tabs fit their labels (+16 inset), hint box moved down to sit 8 above "Changes start tomorrow.". C1/E6 schedule rows without "›", two-line captions where needed; footer caption removed. C5 Evening note removed.
- v8 (2026-11-09): home Kid B block follows Kid A: `lines.kidBRule` (gap 40 below Kid A's last box, name baseline never below 584); per board `lines.baselines.kidBName`, `lines.nowNextBottom`, `lines.baselines.nowNextCaptions` are measured from the board. A1n Tomorrow plate 80 / picture 56.
- v9 (2026-11-09): C2 and S3 stop field 400 × 80 (name or code search). S3 shows the match list open (caption "Tap your stop" at field bottom + 8, list card 400 wide at field bottom + 40, rows 64); C2 shows a picked stop (check 32 + "{road} · {code}" caption).
- v10 (2026-11-09): new board S2s (school search, list open: field 610 × 80 at 232/208, caption 296, list card 610 wide at 328, rows 64, last row "Not in the list?"). S2 redrawn in the picked state: rows School 208, Days 352, Hours 448 + source caption 536, Arrive by 584, Latest 696, MOE row 808, kid line 896.
- v11 (2026-11-09): S2 and S2s get the "Goes to" row at 208 (School · Preschool · At home, tabs 180 × 72, gap 12); rows move down: School 304 (caption 392, S2s list card 424), Days 448, Hours 544 (source caption 632), Arrive by 680 with "latest" and a second time field on the same row, MOE row 792. The Latest row and the no-school line are gone.
- v12 (2026-11-09): C2 rows Walk 496, Ride 600, Ride 2nd 704, Late up to 808, link 900; new board C2c (2nd choice that changes buses): From 208, First bus 296, Change at 400 (caption 488), Then 544, Ride 1 680, Walk 776, Ride 2 872.
- v13 (2026-11-09): S1 kid cards get a remove button (`main.removeKid.1` / `.2`): RoundButton 48 at x 846, y card top − 12 (164, 488 on the board), MarkerGlyph.close inside.
- v14 (2026-11-09): result list card on S3 and S2s: 610 wide at x 232, rows 72, padding 12, opaque, veil behind (field and caption stay above it). S3 list top 480, S2s list top 424.
- v15 (2026-11-09): S3 header: title "Getting there", kid tabs 200 × 72 (gap 12) as on S2, "Step 3 of 4" without the kid name; side column starts with the Home card (map RoundButton 64 + "Set on the map").
- v16 (2026-11-09): S4 rows are switch rows at 216 / 356 / 496 (picture 56 at 104, switch 96 × 52 ending at 842) and the caption at 656; the old permission rows are gone from the board (hidden until built).
- v17 (2026-11-09): home Kid A block look ①: `lines.kidARow` (picture 96 at 928/241, or 104 at 928/238 for Next; text left 1040 / 1048) and `lines.baselines` kidALabel 265, timeLeft72 337, status 374, nextLabel 259, nextTitle 300, nextAt 338; Kid B values per board as before (A1 464, A1m 428, A1n 514, E3/E3b 416). S4 switch rows: the switch is 96 × 52 ending at 842, centred on each 120 row (y row + 34); JSON shows only its check picture. Patch (same version): S4.json now carries `main.card` (PaperCard 64,176,818×792) and `main.switch.1–3` (CrayonSwitch 96×52 at x 746, y 250 / 390 / 530). From the next export every grown-up board lists its PaperCard as `main.card`. PNGs: `handover/boards/S4-almost-done@2x.png`, `handover/boards/CrayonSwitch-on-off@4x.png`.
- v18 (2026-11-09): every grown-up board lists its PaperCard(s) as `main.card` (`main.card.2`… when a board has several); no other layout change. Board PNGs for drift checks in `handover/boards/` (2x).
- v19 (2026-11-09): E1, E3, E3b get the sky switch at (40, 36, 160 × 96), as on A1 and A1m.
- v20 (2026-11-09): S2, S2s, S3 kid tabs follow the title at gap 24 (no fixed x); "Step n of 4" and dots stay right. C4 star row: CheckMark 48 + star picture 40 + text. S2/S2s medal caption shortened to two lines.
- v21 (2026-11-09): no divider lines inside cards: C5 mission rows, S2s and S3 result lists (separated by space only). No geometry change.
- v22 (2026-11-09): A1n redrawn with the night mapping (spec "Night mapping", board 0a2): moon-paper hub and plates, softer night text, the Diary button as a night control. Colours only, no geometry change.
- v23 (2026-11-09): car and taxi redrawn (bubble car, option A, no cheeks) on C3g, S3, A2t-w and kit sheet 0d2. Pictures only, no geometry change.
- v24 (2026-11-10): new board G2b (grown-up edit screen, lower rows): From, No school days, Bring, Missions, Medal as one-line rows on the E5 form lines (label 104, control 232, pitch 96, chevron at 814). The Medal switch (96 × 52) sits at x 232, y 774 (not in the JSON: drawn as a span). Use the rows for C3/C4/E5 in 6b; the side column tabs and the Runs / holidays rows are 6c/6d.
- v25 (2026-11-10): for 6c, boards G2 (E5 with This day / All days tabs, Days chips, Runs fields, holidays), G3 (This day) and G5 (the "Change from when?" card over G2: card 408, 306, 560 × 420; its three tabs export as main.button.1–3 and its caption as main.text.1). G2b mission text shortened to fit the 14-character name limit.
- v26 (2026-11-10): grown-up mode for 6d: G0 (home with the pencil; the pencil is panel.button.1 at 1212, 44, 80), G1 (the day; Undo / Redo are main.button.1 / .2 at 722 / 810, 880, 72; header List / Settings are header.button.1 / .2), G1c (day picker card), G1d (unsaved-changes card), G4 (School edit), G6 (Settings), G7 (change school: Starts on), G8 (List). 38 boards in all.
- v27 (2026-11-10): S3 and S4 copy "…later in Our kids…" → "…later in Settings." (matches the build). No geometry change.
- v28 (2026-11-10): home right panel moved right by 48 (976–1360; kidARow picture 976, text 1088 / 1096) on A1, A1m, A1n, E1, E3, E3b and G0; pencil at 1260, 44. User: the right margin now matches the left (drawn edges ≈ 40 from the glass on both sides).
- v29 (2026-11-10): replaces v28. The home panel keeps its left line 928 and widens to 1336 (w 408): kidARow back to 928 / 1040 / 1048, main button 408 × 96 (art at that width), pencil at 1260, 44. Right margin 40 = left margin (sky switch at 40).
- v30 (2026-11-10): the clock's moon goes centred above the top 12 (428, 48, 40) and the sun centred below the bottom 12 (426, 964, 44) on every kid home and G0 (user: not beside the 12).
