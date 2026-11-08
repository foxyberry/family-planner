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
