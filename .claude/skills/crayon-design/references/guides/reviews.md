# Reviews: three checklists

Use these when you add or change a rule, hand a board over to be built, or call a board done.
Each list is tied to this app's artefacts:
- **Spec**: `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` (section 0 and the screen
  sections, plus the change log).
- **Layout JSON**: `docs/superpowers/layout/<board>.json` and its README (layout vN).
- **Boards**: the canvas in the design session's workspace, and the generated Redlines page.
- **Code**: `ios/DesignSystem` (Tokens, Controls, Content, Layout, Screens, SnapshotTests).

Report every finding as: board id · what you see · expected (spec section) · fix. Fake names
only.

## 1. Design-system audit (a new or changed rule, token or part)
Naming
- [ ] The part's name is the same in the spec, the layout JSON `kind`, and the Swift type.
- [ ] Tokens are named by role (`softText`, `pickBlue`, `lateText`), not by look. A new colour
      gets a role name in the spec first.
Values
- [ ] No raw sizes, colours, spacing or fonts in screen code. Search `ios/DesignSystem/Screens`
      and Controls for numeric `padding`, `frame`, `.font(.system`, hex colours and
      `minimumScaleFactor`; each hit is either a token use or a finding.
- [ ] Every spacing value is one of the spec's tokens; inner-part tokens are not used between
      parts.
- [ ] Every floored size comes from one `Sizing` helper per part; no screen has its own `max`.
- [ ] The 13" value equals the board (`scale.py`), and the value has a formula in the spec.
Coverage
- [ ] The part has a rule in **Part floors** (touch, drawn box, padding, text).
- [ ] Its states are drawn and specified: default, picked, focus, disabled, done, night look,
      and the empty look if it holds content.
- [ ] Reduce Motion and Bold Text behaviour.
- [ ] Every control has an `accessibilityIdentifier`: a test hook for the UI tests (not VoiceOver work), so tests never match visible words.
- [ ] Snapshot tests cover each state on the test sizes the spec's **Check** names.
Conflicts
- [ ] The rule doesn't contradict an older bullet without the change log saying which wins.
- [ ] It doesn't contradict `../hig-exceptions.md`; a new conflict is asked, then recorded.

## 2. Handoff completeness (board → layout JSON → build)
The build reads the layout JSON, so anything missing there is a guess in code.
- [ ] Layout JSON re-exported, `version` bumped, and a README line names the changed ids
      (SKILL.md, "Handover contract").
- [ ] Every part on the board has an element in the JSON with its region and anchor. A part
      missing from the JSON is a question to the design session, not a guess.
- [ ] Every new line has a name, in the JSON and in the spec.
- [ ] Each region has its empty look named (spec **Fixed regions**).
- [ ] Size behaviour is clear for each part: free × s, floored, or fixed, and where it gives
      way on the mini (`../size-check.md`).
- [ ] Text: the longest real label measured at the floor; wrap and "…" rules for typed names.
- [ ] States the board shows only once are listed: picked, disabled, keyboard up, error,
      loading, night.
- [ ] Motion: each moment is a row in the spec's **Motion** table, with its reduced look.
- [ ] Copy follows `copy.md`: no explanatory sentences; confirms use `ConfirmCard`.
- [ ] A spec change-log line exists, and the building session has been told the layout version.

## 3. Design critique (a board is finished)
First look
- [ ] The first thing the eye lands on is the thing this screen is for (a kid's now and next,
      the main button on a form).
- [ ] A kid can tell whose screen it is from face and name alone.
Use
- [ ] The kid or grown-up can finish the job without reading a sentence.
- [ ] One main action per screen, in the main-button place.
- [ ] Nothing a kid needs is behind a long press, a scroll or a hidden gesture.
Hierarchy
- [ ] Type steps run from the ramp; no two neighbours at the same step pretending to differ
      (watch body and caption at their shared floor; `../size-check.md`, risk 2).
- [ ] Whitespace uses the tokens; regions sit on their lines.
Consistency
- [ ] The same part looks and behaves the same as on other boards (tabs, fields, cards,
      `ConfirmCard`).
- [ ] Spare width goes where **Grown-up form layout** and the **Fill rule** say.
- [ ] The drawing rules hold: CrayonKit shapes, kit pictures only, rigid motion
      (spec **Principles → Drawing**, **Crayon part inset**).
Accessibility
- [ ] Contrast pairs checked with `contrast.py` on day and night grounds.
- [ ] Touch floors met; kid parts on kid floors.
- [ ] Meaning never by colour alone.
Close
- [ ] Name what works, then the top three fixes in order of effect on the kids.
- [ ] Check the size run (13" → 11" → mini) before you call it done.

Source: distilled from the design plugin's design-system, design-handoff and design-critique
(Anthropic), and apple-skills design → design-system (MIT).
