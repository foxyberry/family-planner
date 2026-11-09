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

## Not in this step

The event form rows (From, Bring, Before/After, Medal), the mission windows on A2, the home
"Missions →" label, C5 day-only missions, Bring → missions, and C1/C3/C4 route shortcuts.
