# M2: layout contract for every screen, then "after the morning"

**Status (2026-11-09):** in progress. Branch per piece of work from develop; each PR merges itself
when CI is green (user's go-ahead for this run). Every branch ends with a retro (below).

Sources: spec `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` (Shared rules › "Layout
contract", "Sizing formulas"), redlines `docs/superpowers/layout/<board>.json` (layout v4), the
backlog `docs/superpowers/specs/2026-11-08-product-backlog.md` (build order).

## How every screen is built and checked (layout contract)

1. Read the board's redline JSON; ask the design session for a missing part, never guess.
2. A `<Screen>Layout` model: every part's rect, line and baseline through `Sizing`.
3. The view places every part with `place(_:)` / `place(left:baseline:)` / `place(right:baseline:)` /
   `place(topLeft:)`; no stack spacing, centring or offsets decide where a part goes.
4. A layout test: the shared lines at ±1 pt on 1376×1032, 1366×1024, 1180×820, 1133×744.
5. On the iPad: `make device NOW=… OPEN=<screen> GRID=1`, `pymobiledevice3 developer dvt screenshot`,
   compare every part with its line, fix, repeat.

## Work, in order

| # | Work | Boards | Done when |
|---|---|---|---|
| 1 | Merge PR #15 (sizing) and PR #16 (morning) | — | both on develop |
| 2 | Home on the contract: `HomeLayout` from A1, A1m, A1n, E1, E3, E3b; layout test; grid check with `OPEN=home` at the morning, day, evening and night times and on a weekend | A1 family | done: Kid A block per board (A1/A1m leave, A1n time left, E3 next); `HomeLayoutTests`; checked on the 12.9" with the grid at 6:52, 10:30, 19:30 and a Saturday |
| 3 | Grown-up screens on the contract: a `GrownupLayout` (form card 64–882, labels 104, controls 232, side column 930–1312, action button 930, 872); debug-only deep links to C1, C2, C3, C5, C6 (behind "Skip Face ID") so they can be opened and captured | C1, E6, C2, C3, C3g, C4, E5, C5, C6 | every part on its line on the iPad |
| 4 | After the morning, backlog order: E1 one child (check), then first-run setup S1–S4 (S3 "Getting to school" is designed), then the rest of step 6 as the design session hands it over | E1, S1–S4 | per spec |

## Retro at the end of every branch

- Duplicates: parts or helpers that do the same thing (for example `MarkerStyle.with`, frame
  insets, the old `BusBubble` vs `LiveBusBubble`, `DrivingKitIcon` vs `RollingKitIcon`).
- Dead code: parts, strings, assets and keys nothing uses (`check-strings` finds keys; grep the rest).
- Errors and warnings in the build log.
- Skills and CLAUDE.md: anything learned that the next session must do differently; the lessons
  inbox (`skill-retro` when 5+).
- Fix all of it on the same branch before it merges.
