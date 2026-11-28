# Automatic rigs: design (Later)

Design session; moved from the product backlog (retired 2026-11-28, local issue 052). Later work, not planned yet: local issues 042 (a kid's drawing) and 043 (kit layer tags). Public-safe: Kid A / Kid B, no real places.

## What a rig needs
1. **Parts**: which pixels or layers move together.
2. **Pivot**: where each part is attached.
3. **Move**: one move from the fixed vocabulary (rock, bob, slide, spin, rise, fall, press, blink, flicker, twinkle, hop).
4. **Rules**: rigid parts only, small amounts, faces move only with the head, one play ≤ 1.2 s.

Rules 3 and 4 already exist as data (`rigs.json`). Automation is about 1 and 2.

## Step 1: kit pictures (cheap, do first)
- In kit.js, give layers a **part tag** where they are drawn, e.g. `flag`, `wheel`, `arm-left`, `steam`.
- Add a **category template** per slot type:
  - vehicle → body bob, wheels spin
  - flag → rock at the pole
  - food → steam rise
  - person → arms rock at the shoulders, head tilt ≤ 5°, eyes blink
- `make art` then builds `rigs.json` from tags + template. Pivots come from the tag's attachment point.
- A **rule checker** fails the build if a rig breaks the rules: too many parts, a pivot outside its part, a face part moving alone, or amounts over the limit.

## Step 2: a kid's drawing (photo)
The drawing is made **for a slot** (D1 "Draw your toothbrush!"), so the slot's rig is the template. The job is to find the template's parts in the drawing.

| Stage | How | Where it runs |
|---|---|---|
| Clean | D2 already flattens, removes the paper and bolds the lines | on device |
| Split into regions | Vision subject masks + connected regions of the cleaned drawing (an outline plus its fill = one region) | on device |
| Match regions to the template's parts, guess pivots | A vision model gets the drawing, the numbered regions, the slot name, the template and the rules, and answers in the `rigs.json` schema (region ids instead of layer indices) | on device if the on-device model can read images; otherwise a cloud model (e.g. Claude) behind a `RigProposer` interface, only with a grown-up's consent |
| Check | The same rule checker. A part cut out of the middle of a shape would leave a hole when it moves, so it is rejected; only parts that stick out (arms, flags, leaves, wheels at the edge) may move. | on device |
| Review | The grown-up and the kid see it play once, then choose "Move like this" or "No moving" | D3, new step |

- **Fallback**: if nothing passes the checker or confidence is low, the drawing gets the safe whole-picture **hop**. It never looks strange.
- **Privacy**: drawings stay on the iPad unless a grown-up turns on cloud help for that drawing.
- **To build**:
  - part tags and category templates in kit.js
  - the shared rule checker
  - region splitting on device
  - `RigProposer`, with a prompt that embeds the rules and the schema
  - the D3 review step
  - a rigs.json variant whose parts are alpha masks instead of layer indices
