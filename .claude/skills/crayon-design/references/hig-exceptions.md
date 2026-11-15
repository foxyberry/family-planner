# Where this app departs from general Apple advice

General skills (`ios-design-guidelines`, `ipados-design-guidelines`, apple-skills, `swiftui-expert`)
assume a standard productivity app. This app is a hand-drawn family planner that young kids use
on a shared iPad. Where their advice conflicts with a decision below, the decision wins.

If a new conflict comes up, don't follow either side quietly: ask the user and record the
answer here.

## Overridden on purpose (decided)
| General advice | This app | Why |
|---|---|---|
| Sidebar or tab bar for navigation; split views (iPad 3.1–3.3, iOS 2.1) | Full-screen boards; grown-up mode behind the pencil; header tabs per kid | The kids' screens must have no navigation chrome. Grown-up screens are few and flat. |
| System colours, semantic colours, Dark Mode via system (iOS 4.1–4.2) | The crayon palette from the spec ("One colour per kid", `pickBlue`, `softText`, `lateText`); its own night look | Colour is part of the hand-drawn look. Meaning never relies on colour alone, which still holds. |
| SF Pro / text styles first (iOS 3.1, 3.4; typography rule 1) | Playpen Sans with our type ramp, scaled with `Font.custom(_:size:relativeTo:)` | It's the crayon voice. Dynamic Type still has to work, via `relativeTo:`. |
| Large titles, standard toolbars (iOS 2.3, iPad 3.4) | Board headers (spec Grown-up form layout) | The header row is part of the fixed frame. |
| 8 pt grid (iOS 1.5) | The spec's spacing tokens and their floors | The boards are drawn on these tokens. |
| Pointer hover, keyboard shortcuts, Scribble (iPad 4–6) | Not designed | Touch-only family iPad. Revisit if a grown-up asks for it. |
| An alternative to every drag (iOS 5.7; WCAG 2.5.7) | Kid `SlideToGo` is slide-only | The slide is part of the fun (user decision). Every other drag (clock knobs) has a field to type in. |

## Open (not decided; raise it when it matters)
| General advice | Current state | Question for the user |
|---|---|---|
| Support both orientations (iPad 1.6) | Landscape only | Portrait for grown-up screens? |
| Never assume full screen; Split View / Stage Manager (iPad 2.1–2.4) | s has a lower bound; small windows not designed (backlog N10) | Design small windows, or lock to full screen? |
| Redistribute content instead of scaling (iPad 1.2–1.3) | One scale with part floors and a give-way order | On the mini, should grown-up screens reflow (fewer columns) rather than scale? Decide after the mini check. |
| Bigger targets for toddlers | Kid floors (spec Part floors) | Larger primary targets on the youngest kid's screens? |

## Followed as is
- At least 44 pt touch (ours are higher: spec Part floors).
- Respect safe areas, and never hard-code the status bar (we read `safe.top`).
- Dynamic Type including accessibility sizes: controls grow and rows reflow; nothing clips.
- VoiceOver labels on every control.
- Bold Text, Reduce Motion and Increase Contrast.
- Contrast by the spec's **Contrast** rule (`scripts/contrast.py`).
- Never override system gestures.
