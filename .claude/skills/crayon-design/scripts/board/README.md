# Board tools

Scripts for the design loop: edit a board → render → screenshot → layout JSON → redlines →
publish → hand over. They need only this folder, a work folder and the canvas artifact.
Nothing here reads a session transcript.

## Setup (once per session)

```sh
export DESIGN_WORK=~/design-work            # any private folder outside the repo
B=.claude/skills/crayon-design/scripts/board  # this folder
mkdir -p "$DESIGN_WORK"/{canvas/project,blob,deps,preview}
npm install --prefix "$DESIGN_WORK/deps" roughjs@4.6.6
```

- Chrome: `$CHROME`, default `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.
- Private words: put the real names and places, one per line, in `$DESIGN_WORK/private-terms.txt`
  (or point `PRIVATE_TERMS` at a file). Never put that file, or its words, in the repo.

Pull the canvas from the artifact with the Artifact tool (ask the user for its URL, or `list`):
1. `action: "list", scope: "files", url` shows the published paths (`project/<Board>.dc.html`,
   `project/canvas.json`).
2. `action: "read", url, path: "project/<Board>.dc.html", out_dir: "<work>/canvas"` for each
   board you need, and `project/canvas.json`. Use `paths` for several at once.
3. Assets: `python3 $B/local-render.py <Board>` lists the missing asset ids. Fetch each with
   `action: "read", url, path: "<32-hex id>", out_dir: "<work>/blob"`, **one id per call**; it
   lands as `<id>.svg` (or .png). Run local-render again until `missing []`.

## The loop

1. **Edit the board.** There is no editor script: change `canvas/project/<Board>.dc.html` with a
   small Python or Edit, from the built board. New art: make it with the art scripts below, upload
   it with `action: "publish", url, asset: true, file_path`, reference `/_blob/<id>` as the result
   gives it, and save a copy as `<work>/blob/<id>.svg` so it renders locally.
2. **Render + screenshot:** `bash $B/shots.sh GrownupG4` → `preview/g-GrownupG4.png` (1376 × 1032,
   device scale 2). Look at it before going on. `sheet.sh` puts several on one page.
3. **Export layout JSON** into the repo, bumping the version:
   `python3 $B/layout-export.py docs/superpowers/layout 50 G4` (short ids, comma separated; no ids
   = every board). Add one line to `docs/superpowers/layout/README.md`:
   `- v50 (YYYY-MM-DD): G4 <what moved, with numbers>. Other JSON files unchanged.`
   Re-export and bump on **every** screen-board change, even a text-only one.
4. **Redlines:** `python3 $B/redlines.py docs/superpowers/layout G4` writes
   `canvas/project/RL-GrownupG4.dc.html` (lines drawn from the JSON just written).
5. **Publish to the artifact:** `action: "publish", url, root: "<work>/canvas",
   file_path: "canvas/project/canvas.json", files: {"project/GrownupG4.dc.html": ...,
   "project/RL-GrownupG4.dc.html": ...}`, only changed boards plus their RL-*. Add a new board to
   `canvas.json` (`boards` → title, x, y, w 1376, h 1032, page) before publishing it.
6. **Tell the building session:** layout vN, which ids changed and how, the artifact link, and the
   spec section to update. Handover PNGs: `python3 $B/handover-pngs.py <dir> G4-edit-school`.

## Scripts (one example each)

All Python scripts take `--work DIR` or `$DESIGN_WORK`; output paths are relative to where you run them.

| Script | Example | Does |
|---|---|---|
| `local-render.py` | `python3 $B/local-render.py GrownupG4` | board → `preview/r-<Board>.html` with local assets from `blob/`; exits 1 listing missing ids (`--allow-missing` to go on) |
| `shots.sh` | `bash $B/shots.sh GrownupG4 GrownupG1` | render + PNG `preview/g-<Board>.png`; `SCALE=1` for small |
| `sheet.sh` | `bash $B/sheet.sh review GrownupG4 GrownupG1` | contact sheet `preview/review.png`, 3 per row (run shots.sh first) |
| `layout-export.py` | `python3 $B/layout-export.py docs/superpowers/layout 50 G4,G1` | layout JSON per board (uses `extract.js` in headless Chrome) |
| `relations.py` | `python3 $B/relations.py S1,C3` | relations check on the grown-up boards (see below); exits 1 on any delta over 1 pt |
| `redlines.py` | `python3 $B/redlines.py docs/superpowers/layout G4` | `canvas/project/RL-<Board>.dc.html` |
| `handover-pngs.py` | `python3 $B/handover-pngs.py out/boards G4-edit-school` | `<name>@2x.png` for the `handover` names in `boards.json` |
| `card-art.js` | `node $B/card-art.js $DESIGN_WORK/deps out 800x600 472x320` | crayon paper card `card-WxH.svg` |
| `btn-art.js` | `node $B/btn-art.js $DESIGN_WORK/deps out 408` | `btn-ink-408.svg` + night `btn-night-408.svg`, height 96 |
| `pie-clock.js` | `PIE_ONLY=1 node $B/pie-clock.js $DESIGN_WORK/deps out pie.json` | home 24h clock (900 × 1032) |
| `day-editor.js` | `node $B/day-editor.js $DESIGN_WORK/deps out day.json` | grown-up day editor pie (824 × 792) |

`boards.json` is the registry: short id → `[board name, family]`, plus the handover PNG names.
Add a row when you add a screen board, or export and redlines skip it. Families
(`home`, `morning`, `grown`, `grown64`, `calendar`) choose the regions and lines in `layout-export.py`.

## Relations check

`relations.py` measures the boards themselves (the layout JSON drops field boxes): it renders each grown-up board
(`grown` / `grown64` in `boards.json`, plus C3k and the F1–F4 ConfirmCard boards listed in the script as `EXTRA`),
loads it in headless Chrome with `relations.js` and records every part box, its kind (from the classes above, or the
art's blob id for inline art) and the ink box of its art. Then, per row band at 13", it enforces the spec's "Layout model", "Layout balance" and "Grown-up form layout" rules:

1. **line**: each row's first control has its frame on the line (192, 78 for full-width rows, 864 side, 40 header,
   a small card's content edge). Frames sit on lines; every part draws its outline 6 inside; touch area beyond the
   frame is invisible; pick rings are an outward overlay. The S1 swatch is drawn as its 56 circle, so its frame is
   that box + 6. Named exceptions are listed, not failed: F4's indented sub-options, and pictures centred in a
   caption column (F1 / F2 / F4). `--line drawn` checks drawn outlines instead.
2. **col2**: a second column has one label line and one control line per card, its controls end on 808, and its
   label line = control line − (longest second-column label + 10); up to 4 short is accepted as rounding.
3. **height**: one height per row for controls of the same kind; other kinds are centred on the row; header tabs
   are 72.
4. **right**: stretching controls (fields, search, value areas, side rows, the main button) end on frame 808
   (1336 in the side column, the content edge in small cards). Choices next to a label may end short.
5. **label**: every label's glyph is centred on its control's drawn box.
6. **balance**, every gap between drawn edges: card padding by card kind (main form and overlay cards 32,
   nested cards 24; a fixed main card's bottom and any card's right side may be larger), card → card 40, and
   row → row at least 24 (16 in a nested card). A caption or body line within 12 under a row belongs to it.

`--cached` reuses `preview/rel-<Board>.json`; `--quiet` prints only flagged rows; `--sizes` prints, instead of the
checks, every distinct part / picture size per kind with counts and boards (heights only for fields, tabs, rows and
cards, plus their recurring widths), near-duplicates, and one-off sizes. Text is masked with the private-terms file.

## Clock configs

Hours are 0–24 with decimals (7.5 = 7:30). A slot that ends before it starts wraps past midnight.
Colours are the spec's tokens as hex; `null` = free time (plain paper). Angle = crayon hatch angle.

`pie-clock.js` (home clock; without a config it draws an example school day to `pie-crayon.svg`,
and without `PIE_ONLY=1` also writes the small UI pieces: dots, ink button, circles):
```json
{"out": "pie-weekday.svg", "now": 7.5, "current": [7, 8], "night": false,
 "secs": [[21, 7, "#FFD23F", -40], [7, 8, "#7FD6B5", 60], [8, 15, "#F7A84B", -55],
          [15, 17, null, 0], [17, 21, "#A8DB7A", -30]]}
```
`now` = red hand, `current` = outlined slot, `night` = lit paper face and chalk ticks.

`day-editor.js` (with a config it writes only the pie; without one, the example pie plus
exact-size tabs, card and time fields):
```json
{"out": "day-edit.svg", "locked": [8, 15], "active": 17, "selected": [7, 8], "dash": null, "plus": [16],
 "slots": [[21, 7, "#FFD23F", -40, "sleep"], [7, 8, "#7FD6B5", 60, "morning"],
           [8, 15, "#F7A84B", -55, "school"], [15, 17, null, 0, "free"],
           [17, 21, "#A8DB7A", -30, "play", true]]}
```
Slot = `[from, to, colour, angle, name, skipped?]` (skipped = faded). `locked` = grey padlock
knobs, `active` = blue knob being dragged, `selected` = outlined slice, `dash` = where an edge was,
`plus` = "+" buttons on free slices.

## Pitfalls

- **Never render from a session transcript.** The old tools did; reading a large transcript ran
  out of memory. Assets come only from `blob/`.
- **Fetch missing blobs first.** A missing asset renders as `missing.svg`: the screenshot looks
  broken and the export measures the wrong boxes. Get `missing []` before exporting.
- **9-slice rule.** Crayon art stretched with `background-size: 100% 100%` smears its rounded ends.
  When a tab, pill or card changes width, either draw exact-size art (`card-art.js`, `btn-art.js`)
  or 9-slice it:
  `box-sizing:border-box; border-style:solid; border-width:0 40px; border-image:url(/_blob/<id>) 0 40 fill / 0 40px / 0 stretch; background:none`
  (40 for tabs and pills, 24 for cards). The art must have plain ends that wide.
- `extract.js` names parts from markup: `.lbl` labels, `btn-ink` primary, `btn-round` back,
  `[class*=field]`, `tab-` / `day-` / `slot` choices, `role=tab|slider`, `h1` title. Keep these on
  new boards or the JSON gets wrong kinds and ids. Check ids against the previous version.
- Export drops text with digits, over 32 characters, or a private word. Without a private-terms
  file it stops; `PRIVATE_TERMS=none` skips only the word check. Read the JSON before committing.
- Boards, `canvas.json` and PNGs can show real names; they stay in the artifact and the work
  folder. Only layout JSON goes in the repo; check any PNG before it goes anywhere public.
- `RL-*` boards are generated; never edit them by hand, re-run `redlines.py`.
- Work paths can contain spaces; quote them.
