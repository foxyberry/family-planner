# Copy: labels, buttons and confirms

Use this whenever you write or change words on a board or a screen. This app's first rule is
**keep screens plain**: values, pictures and short labels stay; explanatory sentences go
(spec change log, the plain-screens passes). Lengths and sizes are in the spec
(`docs/superpowers/specs/2026-11-07-m2-screens-spec.md`, section 0: **Part floors → Label
column** and **Text**); this guide is about the words.

## The plain-screens rule
- No sentence on screen that explains how the screen works. If a screen seems to need one,
  the layout or the picture is wrong: fix that, or ask the design session.
- No hint lines under fields, no "Tip:", no onboarding captions, no "Tap here to…".
- Keep: values ("{h:mm am}", "{n} min"), names, short labels, a title, button words.
- Empty looks are drawn, not written (each screen names its empty look in the spec). Don't
  add "Nothing here yet. Tap + to add…".

## Labels
- One to three words, the noun or the short question the row answers: "Arrive by",
  "Goes to", "Late". Lead with the word that differs from the row above.
- Fit the label column at the caption floor. If it doesn't fit, **reword; never squeeze**.
  The spec's own example: "Late up to" became "Late". Shrinking, tightening, tracking or a
  smaller weight is not an option (`typography.md`).
- Same thing, same word, on every screen and board. Keep a short word list in the spec's
  parts or screen sections when a new term appears; check it before naming something.
- Sentence case. No full stop on a label, a button or a title.
- Plain words a grown-up uses at home, not app words: "This day / All days", not
  "Instance / Series".

## Buttons
- Start with the verb that says what happens: "Save", "Leave", "Remove", "Add".
- Name the outcome, not "OK", "Yes", "Submit" or "Done" when a verb fits.
- One line at the default text size. If it would wrap, find a shorter verb.
- The same action keeps the same word everywhere ("Keep editing" is always "Keep editing").

## ConfirmCard: every confirm and alert
- Every confirm or alert in the app is the one `ConfirmCard` part (spec **New parts →
  CrayonKit UI parts**). No system alerts, no new dialog part.
- **At most two buttons. The main one first.** The main one is the action the question is
  about ("Leave", "Remove"); a destructive main button uses `lateText` and still has a word,
  not only a colour.
- Ask only when the user would lose something. Otherwise just do it and let Undo exist.
- **Title**: the question, short, naming the thing: "Leave without saving?",
  "Remove {name}?". Not "Are you sure?".
- **Scan test**: the title and the two buttons alone must make sense. Add a body line only
  when they don't, and only a fact ("Changes start tomorrow."), not an explanation.
- The second button says what staying means: "Keep editing", "Keep". Not "Cancel" when a
  clearer word fits; "Cancel" is fine where the spec uses it.

## Kid screens
- Kids read little, and the youngest kid reads nothing: the picture carries the meaning, the
  word backs it up.
- A few words, warm, never a scold: "Ready? Slide to go", "Ready!", "Gold!". Late is no medal,
  never a sad word or face (spec **Principles → Kids**).
- Celebrate in proportion: the biggest words for the rarest moment (gold), quieter ones for
  routine (a mission done gets no words at all).
- Times: short on screen ("38 min", "1h 20m").

## Values and names
- Times follow the format in spec **Principles → Time**. Use one formatter for times,
  durations and dates; never format in a view.
- Typed names keep the case the grown-up typed.
- Placeholders in boards and the public repo use Kid A / Kid B and fake places only.

## Reviewing copy
For each word on the screen ask, in this order:
1. Does the screen still work without it? Then remove it.
2. Is it the same word the rest of the app uses for this?
3. Does it fit at the floor in the shown weight (`measure-text.swift`)? If not, reword.
4. Read it aloud: does it sound like a kind grown-up at home?

Report as: `Board / screen | Now | Problem | New words`, most-seen screens first. Put accepted
copy changes into the spec with a change-log line; a new label that only lives in code is a
silent fork.

Source: distilled from apple-skills design → ux-writing (MIT), the design plugin's ux-copy
(Anthropic) and ios-design-guidelines alert rules (platform-design-skills, MIT).
