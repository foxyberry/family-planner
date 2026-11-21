# Kid feedback: making kid moments land

Use this when you design, build or review a kid moment: a mission check, the slide, the medal,
a picture rig, a new slot. What moves, how long, and the Reduce Motion look are in the spec
(`docs/superpowers/specs/2026-11-07-m2-screens-spec.md`): **Motion: every moment**, **Picture
rigs**, and the A2 sections (**Tapping a mission**, **After the slide**, **Medal from the time
only**). This guide is the method for checking that each moment reaches the kid.

## Who is watching
- The iPad is shared and often stands on a table or a stand. A kid may be across the room;
  a grown-up may be watching from the side.
- So screen motion and picture size do most of the work. Sound would reach the whole room;
  haptics would reach only a hand holding the iPad.
- **Haptics: treat as absent.** `CHHapticEngine.capabilitiesForHardware().supportsHaptics`
  reports false on iPads. Gate every haptic call on it and never let a cue be haptic-only.
- **Sound: not designed.** The spec has no sound layer. Don't add one on your own; it needs
  user decisions (which moments, mute switch, the silent-switch policy, not stopping the
  family's music). Raise it as a question.

## The event × channel audit
Build this table **from the code**, not from memory, for every kid screen you touch:

| Event | Who must notice | Visual | Motion | Haptic | Sound | Reduce Motion look | Verdict |
|---|---|---|---|---|---|---|---|

- Fill each cell with what actually fires (file and line), or "none".
- **Verdict**:
  - a signature moment (gold, the slide finishing) needs at least two channels; on this iPad
    that means a visual change **and** motion;
  - a routine moment (a mission check) needs one clear visual change and the right trait;
  - a moment with no Reduce Motion look, or one whose reduced look loses the meaning, fails;
  - two code layers firing the same moment (a double hop) fails.

## The kid moments
For each, the spec row is the rule; here is what to check.

**Mission check** (tap a mission circle)
- Visual: the tick and the done state in the pick colour plus shape (not colour alone).
- Motion: the check draws itself; the mission picture plays its rig once.
- Reduce Motion: the check appears; the rig doesn't play.
- Taps during the rig still toggle; they don't restart it.

**Slide to go** (`SlideToGo`)
- Visual: the track, the knob picture and the label; the done look stays after release.
- Motion: the knob picture plays while dragging and follows the finger's direction; a hop and
  a wash at the end.
- Reduce Motion: a colour change only.
- Undo by dragging back past the middle; the done look and undo are the same for every kid.

**Medal / done view**
- This is the rarest moment, so it is the biggest one: the medal picture, the display word
  ("Gold!"), confetti. Nothing routine may reuse the same motion.
- Medals come from time only; a late kid gets "Ready!" and no medal, with the same warmth and
  no sad cue. A kid with no outing gets the crown.
- Reduce Motion: the medal fades in; the information is the same.

**Picture rigs** (tap a slot on the kid clock, or a mission picture)
- Motion: one play, rigid parts only, within the spec's limits; a second tap during the play is
  ignored.
- The rig is extra; the slot still reads when still.
- Reduce Motion: no movement; the slot's outline thickens briefly instead.

**Clock moments** (new slot, on the hour, idle wink, sky switch)
- Each has its row in the Motion table with its own reduced look; check them in the same table.

## Rules for every kid moment
- **Feedback follows rarity.** Routine < done < ready < medal. The rarest moment gets the
  biggest motion; never reuse the medal's motion for a routine tap.
- **Every effect is tied to an event.** No looping glows or background particles competing
  with the moment.
- **Same thresholds on every channel.** If the screen changes look at a time threshold, any
  other cue (a colour) changes at the same moment.
- **One owner per event.** The reducer or the view decides; not both.
- **Instant first response.** A tap changes something on screen at once, even when the rest
  of the moment follows.
- **Reduce Motion keeps the meaning.** Build the spec's reduced look for each row; "no
  animation" alone is not a reduced look unless the spec says "none".
- **No shame, ever.** No red-only, no sad face, no shaking "wrong" motion (spec
  **Principles → Kids**).

## Before handing over
- The audit table for the screen, worst rows first.
- A check on the family iPad: feel and timing can't be judged in the simulator, and the
  simulator plays no haptics either way.
- Any gap that needs a new rule (a moment with no reduced look, a sound question) goes to the
  design session with the board id.

Source: distilled from apple-skills design → game-feel, feedback-audit, haptic-design and
sound-design (MIT), and ios-design-guidelines feedback and Reduce Motion rules
(platform-design-skills, MIT).
