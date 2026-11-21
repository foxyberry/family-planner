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
| SF Pro / text styles first (iOS 3.1, 3.4; typography rule 1) | Playpen Sans with our type ramp × s | It's the crayon voice. |
| Large titles, standard toolbars (iOS 2.3, iPad 3.4) | Board headers (spec Grown-up form layout) | The header row is part of the fixed frame. |
| 8 pt grid (iOS 1.5) | The spec's spacing tokens × s | The boards are drawn on these tokens. |
| Resize fluidly; never assume full screen; Split View / Stage Manager (iPad 2.1–2.4) | One scale from the app window: a smaller window shows the whole board smaller, with paper around it (spec **Supported screens and windows**) | One board-drawn layout can't reflow; scaling keeps every window usable without crop or scroll (user, 2026-11-21). |
| Pointer hover, keyboard shortcuts, Scribble (iPad 4–6) | Not designed | Touch-only family iPad. Revisit if a grown-up asks for it. |
| Redistribute content instead of scaling (iPad 1.2–1.3); 44 pt touch minimum; Dynamic Type | One scale, no floors: every size is board × s, touch is the visible box, text sizes come from s only (spec **Sizing**) | One rule for every screen keeps proportions and removes the per-iPad floor code (user, 2026-11-21). On the iPhone Duo inner screen some grown-up parts fall under 44 pt; accepted. |
| An alternative to every drag (iOS 5.7; WCAG 2.5.7) | Kid `SlideToGo` is slide-only | The slide is part of the fun (user decision). Every other drag (clock knobs) has a field to type in. |

## Open (not decided; raise it when it matters)
| General advice | Current state | Question for the user |
|---|---|---|
| Support both orientations (iPad 1.6) | Landscape only | Portrait for grown-up screens? |
| Bigger targets for toddlers | Kid targets as drawn on the boards, × s | Larger primary targets on the youngest kid's screens? |
| VoiceOver labels on every control | No VoiceOver work in this phase (user, 2026-11-21): no labels, spoken text or adjustable elements in specs or boards; skip the VoiceOver items in the guides and review lists | When to add VoiceOver back |

## Followed as is
- Respect safe areas, and never hard-code the status bar (we read `safe.top`).
- Bold Text, Reduce Motion and Increase Contrast.
- Contrast by the spec's **Contrast** rule (`scripts/contrast.py`).
- Never override system gestures.
