# Build step 5 "Morning": the rest (live bus, C2, slide to go, medals, Going)

Spec: `docs/superpowers/specs/2026-11-07-m2-screens-spec.md` › "A2 · Morning" (timetable look,
"A2 live look"), "Bus settings (C2 "Our buses")", "Trips on items: the Going row", "Spoken times".
Already built (PR #14): missions, C5, the timetable way strip, family outing, empty look.
Branch: `feature/m2-morning-live` from develop once PR #14 and `feature/m2-sizing` are in.

Privacy: no real stop code, bus number or key anywhere in the repo, seed, tests, previews, docs
or commit text. Tests use stop "00000" and bus "1". The LTA key lives only in the Keychain.

## Tasks (in order; each ends with tests)

1. **Domain** (pure): `BusArrival` (service, minutes, type), `BusPlan` (stop, services, walk,
   ride, lateGrace), `LivePlan` maths: chosen bus (first minutes ≥ walk), "too soon" bus,
   Leave in, status (onTime / leaveNow / askGrownup), next catchable bus, L1/L2 and the medal
   (gold ≤ L1 − 5, silver ≤ L1, bronze ≤ L2, else none); fallback L1 = start − leaveBefore.
2. **Clients** (`tca-feature` skill): `BusArrivalsClient` (arrivals for a stop; stop name lookup)
   with `BusArrivalsClientLive` (LTA DataMall BusArrival v3 and BusStops, key from Keychain);
   `SecretStoreClient` (Keychain get/set for the LTA key); bus settings in `ScheduleStore`
   (stop, services, walk, ride, late grace per kid). Done state gains `readyAt` and `medal`.
3. **Morning reducer**: on open and every 30 s fetch arrivals for the family outing's stop;
   keep the last good answer 2 min, then the timetable look ("by bus · no live times").
   Live look state: buses (x from minutes), chosen/too-soon, header "Leave in" + status;
   `leaveAt` from Leave in. Slide to go for a kid with an outing today (always awake);
   on slide: readyAt, medal, confetti, next kid; undo "Not yet" with one confirm.
4. **Parts** (gallery + snapshots first): live strip look in `WayStrip` (straight road, stops,
   buses 120 gliding over 1 s, bubbles with plate, minutes, KidFace 32 "my bus", "too soon",
   legend); header status line; ready row with medal on the ring (A3).
5. **A1**: live bus morning shows "Leave in" + 80 bus + TimeLeft + status; fallback "{Place} in".
6. **C2 "Our buses"**: stop code with name confirm, my-bus chips, walk / ride / late grace
   steppers, "Live bus times" key row (secure field, Working / Not working). Entry: C1
   "Getting there". Plan B and "Add a route" hidden.
7. **Going row** on C3/C4/E5 (board C3g): None / Walk / Bus / Car / Taxi, Leave minutes; Bus
   opens C2. Preview line "Leave {h:mm am} by {way}."
8. Spec copy check, `make test`, `make snapshots`, guards, iPad check with the time machine.
