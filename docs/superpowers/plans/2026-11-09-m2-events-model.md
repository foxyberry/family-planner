# M2 events model: one shape for every item (build row 6b)

Spec: `2026-11-07-m2-screens-spec.md` › "Events: one shape for every item". This plan covers the
**model step only**. Today's screens keep working; the event form rows, the mission windows and the
home button come after it.

## Identity

Every event a trip, a route or a record can point at gets an `EventRef`:

```swift
public enum EventRef: Hashable, Codable, Sendable {
    case school            // the kid's School block in the day template
    case item(UUID)        // an every-week or just-once ScheduleItem
}
```

Template blocks other than School have no stable id yet. They keep working as today, with no route,
no linked events and no per-event medal, until C6 blocks get ids.
`Slot.event: EventRef?` is set by `DayPlanner` when it builds the day: School → `.school`, items → `.item(id)`.

## PR A: mission records per window and per outing

Domain (`Missions.swift`):
- `MissionWindow`: `morning`, `before(EventRef)`, `after(EventRef)`, `evening`.
- `WindowMissions { kid, date, window, done: Set<Mission.ID> }`.
- `OutingSlide { kid, date, outing: EventRef?, ready, readyAt, medal }`. `outing == nil` is the
  morning window's "All done? Slide!" on a day with no outing, which has no medal.
- Both kept `MissionDay.kept` (14) days.

Store (`ScheduleStore` port + Live):
- `windowMissions(kid, date, window)`, `saveWindowMissions(_)`, `slides(kid, date)`,
  `saveSlide(_)`, with keys `window:{kid}:{date}:{window}` and `slide:{kid}:{date}:{outing|morning}`.
- **No migration** (user, 2026-11-09: the stored marks were development data): the old per-day
  `missionDay` records are dropped when the store opens; the family itself is untouched.
- `MissionsFeature` keeps its in-memory `MissionDay` (the screen's view) and joins/splits it: the
  morning window's missions plus the slide of the kid's first outing (`firstOuting(of:)`).

Tests: Live round trips for windows and slides (one per outing), the 14-day prune; `EventRef` from
slots; JSON round trips.

## PR B: event fields

Domain (`Models.swift`); every new field decodes as optional, so stored JSON from older builds still
loads:
- `Trip.homeAfter: Int` (0–90, step 5, default 0; custom `init(from:)`).
- `Trip.medal: Bool?`: nil means the default (on for School, off for others). `Trip.lateGrace: Int?`
  for events other than School; School keeps its S2 values.
- `ScheduleItem.after: EventRef?`: "From: After {event}". A linked item has no trip of its own.
- `BusPlan.event: EventRef`, default `.school` (custom decode), so the kid-level route becomes the
  School event's route as it is. The store key changes to `busPlan:{kid}:{event}`; a School route
  under the old key `busPlan:{kid}` still loads and is replaced the next time it is saved.

`DayPlanner`:
- A linked item starts at its event's end and keeps its own length, on days that event happens.
- If the event before it is missing that day (holiday, skipped, another weekday), the linked item is
  dropped too.
- Chains (an item after a linked item) are placed in order. `homeAfter` is stored now; the clock
  uses it when the event form rows arrive.

Medal: `MissionsFeature.medal(for:)` checks the S4 Medals switch first (done), then the outing's
`Trip.medal` (default by event), then the timing rule as today.

Tests: linked item follows school; linked item skipped when school is off (MOE holiday, skip once);
`homeAfter` decode default; medal default on School and off on an item; bus plan per event and
plan lookup by the outing's event.

## PR C: mission windows

Domain (`MissionWindows.swift`): `DayPlanner.missionWindows(slots:night:)` turns the day's points
(wake, each outing's leave and home, dinner, bed) into `WindowSpan`s, each with its window parts in
order:
- Morning: wake → the first leave (that outing's "before" missions join it), or noon when nothing
  leaves before then; an afternoon outing then gets a "before" stretch from noon to its leave.
- After an outing: home (the end of its linked chain + `homeAfter`) → the next leave (whose "before"
  missions join) or dinner. The chain's events each add an "after" part.
- Evening: dinner → bed.
`Slot.after` carries the item's link so the chain can be followed.

Home: "Missions →" shows while a kid's open window has missions (today only the morning routine
has any), and the "Leave in" countdown follows Kid A's open window's outing. `isMissionMorning`
(wake → noon) is gone.

## PR D: event form rows, missions per window (board G2b, layout v24)

Model: `ScheduleItem.bring`, `missionsBefore`, `missionsAfter` (`ItemMission`: id, name, picture;
four each, old JSON loads empty); `Mission.days` (every day unless fewer are picked).

C3 / C4 / E5 form, after the existing rows (spec "Event form rows for 6b"):
- From: a centred card with ChoiceCircles: Home, then the kid's events that end at or before the
  start on every one of the item's days (School first, then by end), five at most. "After X" starts
  the item at X's end, keeps its length, hides Going / Leave and shows "after X" for the start.
- Bring: a centred card with IconPicker in multi-pick (backpack, lunch box, water bottle; "More"
  for the whole kit), four at most; a tap outside puts the list back.
- Missions: a sub-page in the form card with Before and After sections (C5 rows, the C5 card).
- Medal: a CrayonSwitch on the row, off and faded without a trip.
- C5: a Days row in the mission card; fewer days show under the name ("Thu").

Windows: `DayPlanner.missions(in:routine:items:weekday:)` lists a stretch's missions part by part
(the routine's for the weekday, an outing's "before" missions and Bring, the "after" missions of
what just ended; an item's picture already shown is left out). A2 shows each kid's open window
(else the morning) and saves done marks per window part and the slide per outing. Home names the
window: "Missions", "Before {item}", "After {item}" (too long for one line: "Missions").

## Not in this step

School's own Bring / missions / medal switch (its event screen, 6d), the evening routine ("Pack for
tomorrow"), No school days and Runs (6c), and C1/C3/C4 route shortcuts.
