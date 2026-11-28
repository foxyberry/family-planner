# Reference time zone: design (Later)

Design session; moved from the product backlog (retired 2026-11-28, local issue 052). Later work, not planned yet: local issue 028. Public-safe: Kid A / Kid B, no real places.

Show the family's schedule in a chosen zone (e.g. view the home zone's day while travelling).

- **Family time zone**: the zone the plan is written in. It is set once in G6 Settings → Family (default: this iPad's zone at first run). Every template slot and item is stored in family time.
- **Show times in**, a per-device setting: "Family time (default)" or "This iPad's time".
  - In the first case, an iPad that is travelling (e.g. in Korea) still shows the Singapore day, and the clock gets a chip under the hub: "Singapore time" (caption).
  - In the second case, the plan is converted. The day changes at local midnight; slots that cross the boundary are split across the two days.
- Kid screens never show two times at once; the chip is the only sign.
- Grown-up screens show times in family time with the zone name in the header caption while the device is in another zone.
- Engineering note: all time already flows through dependencies (`@Dependency(\.date)`, calendar/zone). The change is a family-zone value plus a per-device display preference.

## Boards to draw when it starts
- The setting row (G6 Settings → Family) and the zone chip under the hub.
