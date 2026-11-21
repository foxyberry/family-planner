# Accessibility for the crayon app

Use this for touch, contrast, the system accessibility settings and gestures.
VoiceOver is not in this phase (user, 2026-11-21; `../hig-exceptions.md`): add no labels,
spoken text or adjustable actions. It holds no numbers: every size and colour is in the spec
(`docs/superpowers/specs/2026-11-07-m2-screens-spec.md`, section 0 "Shared rules"). Where general
Apple advice and this app differ, `../hig-exceptions.md` decides.

## Touch
- One touch rule (spec **Sizing → Touch**), in this order: (1) a tap hits only what is drawn,
  scaled by `s`, never an invisible floor; (2) a drag that starts on no tappable part grabs the
  nearest draggable handle in that area (clock knobs, slider knobs), up to half the way to the
  next one; (3) draw the part bigger on the board only as the last resort.
- Kid targets are big on the board; they stay big by scaling, not by floors. On the iPhone Duo
  inner screen some grown-up parts fall under 44 pt; the user accepted that.
- Use `Button` (or a custom `ButtonStyle`) for anything tappable, not `onTapGesture`: it brings
  the button trait and focus for free.
- Neighbouring targets are spaced only by the spec's tokens × s.

## Text size
- Text sizes come from the board × s only. The system text size (Dynamic Type) does not change
  them in this phase (spec **Sizing → Type**; `../hig-exceptions.md`).
- Never use `minimumScaleFactor` and never `scaleEffect` a screen (it blurs text).

## Contrast
- Check every colour pair before you name it:
  `python3 .claude/skills/crayon-design/scripts/contrast.py <fg> <bg>`. The thresholds are in
  SKILL.md, "Before you write a value", step 4. Check day and night grounds (A1n, B2n).
- UI parts count too: crayon outlines, the slide track, check circles, switch knobs and focus
  marks need the UI-part ratio against what they sit on.
- Pick colours from the crayon tokens in the spec ("One colour per kid" and the token list),
  never a new hex in a view.

## Never colour alone
- A kid is always face + name; their colour only adds to that (spec **Principles → Who is who**).
- Done, picked and focus use the pick colour **and** a shape: a tick, a thicker outline, a
  filled state. Late shows as no medal, never as a red-only cue and never a sad face.
- Disabled parts look dimmed **and** are announced as dimmed (`.disabled`), not only faded.

## System settings
- **Bold Text**: read `@Environment(\.legibilityWeight)`. When it is `.bold`, step each text
  weight up one named instance of the font (`typography.md`). Strokes of crayon parts stay
  as drawn.
- **Reduce Motion**: read `@Environment(\.accessibilityReduceMotion)`. Every moment in the
  spec's **Motion** table and **Picture rigs** has its reduced look; build that look, not just
  "no animation". `kid-feedback.md` lists them per kid moment.
- **Increase Contrast**: read `@Environment(\.colorSchemeContrast)`. When it is `.increased`,
  use the higher-contrast variant of a soft colour (`softText` and other faded parts). If a
  token has no variant yet, that is a spec question, not a local fix.
- **Reduce Transparency** and **Differentiate Without Colour**: faded buses and their tags on the live strip and
  washes must still read; the shape cue above already covers colour.

## Gestures
- Never take over system gestures: the edges belong to the system (home, Control Centre,
  notifications). Custom drags start clear of the screen edges.
- Kid screens have no edge swipe back; the way out is the header "←" (spec A2,
  **Presentation**).
- Every custom drag has another way to do it, by tap or by typing:
  - clock knobs: the time field in the slice card;
  - drag to reorder or resize anything new: a tap path, decided before the board is final.
- **Accepted exception: kid `SlideToGo` is slide-only.** The slide is part of the fun; this is a
  user decision recorded in `../hig-exceptions.md`. Don't add a visible button next to it.
- Long press is never the only way to anything a kid needs. The grown-up "hold the clock" way
  in is a gate on purpose (spec **C0**), and the pencil button is the other way in.

## Not designed yet (ask before you build)
- Switch Control and Full Keyboard Access: the app is touch-only today
  (`../hig-exceptions.md`). Standard `Button`s keep them working by default; don't break that.
- Larger primary targets on the youngest kid's screens: open in `../hig-exceptions.md`.

Source: distilled from ios-design-guidelines and ipados-design-guidelines (platform-design-skills,
MIT), swiftui-expert accessibility-patterns (Antoine van der Lee, MIT), apple-skills design
(MIT) and the design plugin's accessibility-review (Anthropic).
