# Home redesign: one kid's clock, the family's next things

Design session, 2026-11-22, with the user. Boards A1, A1m, A1b, A1n, A1z, A1k, E1, E3, E3b, E3h, E3s, E3x, G0 (layout v75). The screen rules live in the M2 screens spec, section "A1 · Home". This note keeps the why and the choices.

## Why
A screen-only UX review of the home's main button found that it changed by itself between "Missions →", "Before {item} →" and "Diary →" in one look. Kid B could not tell it was theirs, and nothing on home showed how far a kid had got. Working on it showed three deeper problems:
- the clock was Kid A's day but said so nowhere;
- the right panel grouped things by kid, so the nearest thing was spread over several blocks;
- with three kids, nothing fitted: not three bands on the clock, and not three blocks with buttons on the right.

## Goals, non-goals
- Goal: a kid finds what is next, and whether it is theirs, at a glance; a grown-up sees the family's next things in time order.
- Goal: it works for one, two or three kids without a new layout.
- Non-goal: showing mission progress on home (it lives in A2); missions per event (issue 024); per-holiday art (issue 023).
- Anti-goal: words that explain the screen; blinking; a second "button language".

## Approaches considered
1. Keep the one main button and put picture, label and faces on it: the button became too small for its contents.
2. A button per kid under each kid block: clear ownership, but the panel filled up and three kids did not fit.
3. The event row itself as the button (picked): the row of the outing that has checks becomes the button, so the label names itself.
4. A family clock that splits a slice into kid bands where the kids differ: kept the overview, but three bands were too thin and confusing to read.
5. One kid's clock, picked by chips, with one family list in time order (picked): the clock stays simple, the list answers "what is next".
- Research behind 5: children's visual schedules use two parts, now and next; ambient displays need one primary item; family calendars (Skylight, Hearth) tell people apart by colour, not columns.

## Decisions (user unless marked as the designer's call)
- **Clock:** shows the picked kid's day. A kid-colour rim and the kid's face in the hub say whose clock it is. The hub shrinks to r 104 and holds only the face, the weekday and the time; the weekday leaves the right panel.
- **List order:** the right panel stacks from the bottom up. Kid chips sit at the bottom (where the main button was), the nearest thing is a larger card right above them, and later things climb above it. Weight sits low, and "soon" sits near the hand.
- **Chips:** they pick the clock. A tap also fades the other kids' rows for 10 s, so a kid sees "now" (the chip) and "my next" (the strong rows). With one kid there is one chip, with the kid's name.
- **Time cell:** the left column of every row is a time cell. Within an hour it shows "{n} min" over six dots, one dot per 10 minutes, red for the time left. The dots go out from the right, and only the last one on the card breathes. Past an hour it shows the clock time; another day shows the day label.
  - The direction (red = time left, shrinking) follows children's visual timers. A filling bar was tried and dropped, and so was blinking: it nags, and WCAG 2.2.2 discourages it.
- **Rows:** faces sit under the title, and the right side only carries "›" on mission rows. Fading uses colour, not opacity, to keep contrast: later titles 4.7 : 1.
- **Mission rows:** only outings that have something to check get the kid-colour hatch and "›". A morning with no outing has no mission button. No left-to-right progress fill: two fills competed.
- **Words dropped:** "Leave in", "On time", "Now ·" and "Next ·" are gone from home. Live bus status stays on A2.
- **Holiday scene:** a crayon scene behind the clock. Priority: the public holiday's own scene, else the school-holiday scene when every school kid is off, else none. It is hidden at night. Holiday names come from the official list; school breaks get no name on home.
- **Disabled controls:** one look, 40 % (raised from the build, PR #272).
- **Designer's calls:**
  - the 10 s return for chips;
  - the 30 % fade for other kids;
  - a shared outing's hatch in one warm neutral (alternating kid colours looked too busy, user);
  - a public holiday without its own scene shows none;
  - the row geometry (time cell to 1040, picture at 1052, title at 1120; hatch bleed 12, padding 12 / 10).

## Left to the builder and to the iPad
- The next card's and mission rows' insides are not in the layout JSON (they are buttons): the spec gives their numbers.
- iPad observations:
  - Do kids read the dots as "time left"?
  - Do they look at the bottom first?
  - Does Kid B find their own row after tapping their chip?
  - Is red (hand, dots, holiday weekday) ever confused?
