# Product backlog: build plan and Later

The one categorised backlog for the app. Public-safe: Kid A / Kid B, no real places or times.
Board ids refer to the design canvas. Screen details live in `2026-11-07-m2-screens-spec.md`.

## Change log
- 2026-11-08: first version (MVP cut, Next, Later by category, multi-iPad sync plan, reference time zone).
- 2026-11-08: automatic rigs plan (kit part tags, kid drawings), section 5.
- 2026-11-08: sync UX in detail: separate Apple IDs via CKShare (no login switching), roles, C8 start/add/list/stop, the Join flow, states (before pairing, first sync, offline, conflict, removed, owner signed out).
- 2026-11-08: user's scope choice (hop, rigs, night look + sky switch kept; E1 and other motion to Next); school holidays kept as built (N3 removed); build order and status table.
- 2026-11-08: N1a bus crowding in windows + rocking buses, N1b school shuttle (board A2s); school pictures are raised on a dotted line, only vehicles sit on the line.
- 2026-11-08: N1a passengers are small feelHappy faces (not new people) and move with the bus.
- 2026-11-08: N2 slide to go never waits for missions; label "Ready? Slide to go".
- 2026-11-08: missions shown as circles for both kids (Kid A like Kid B); A3 text "Ready in good time!".
- 2026-11-08: mission overflow rule (fold done ones, "+n" page; no horizontal scroll); 0f Scroll rules A2 line updated.
- 2026-11-08: board A2m (many missions: fold, "+n" page, "‹" back); flow pass: grown-up screens go back to C1, C1 ↔ E6 tabs, C1 → C5 "Morning missions", A1n → B2n, E1 → E2, B3 → B2; C5 shows "up to 8".
- 2026-11-08: N1b shuttle is a per-term choice; C1 "More" with Morning missions (C5) and Drawings (D1).
- 2026-11-08: each kid finishes on their own; A3 redrawn (Kid A ready, Kid B still going), new A3s (shuttle).
- 2026-11-08: board A2f (3–4 kids: kid list on the left, focus on the right).
- 2026-11-08: A2, A2s, A3, A3s, E4 moved to the family layout (kids on the left, chosen kid on the right); A3 shows Kid A ready and Kid B chosen.
- 2026-11-08: wheels turn on the map (spoke + hub wheel, wheel parts in bus rigs).
- 2026-11-08: home with a kid list (A1f) tried and dropped (user: not everything visible at once); A1 keeps the big clock + other kid now/next.
- 2026-11-08: review: status table updated; "Design to finish before the build reaches it" added (CrayonKit primitives list, MVP mission screen without the bus, mission spec).
- 2026-11-08: A2-MVP way strip (destination + how the kid goes, by the clock); N9 taxi ETA typed by a grown-up (no Grab API).
- 2026-11-08: principle audit: board 00 Principles (time, kids, who is who, type and space, drawing, privacy); 0c2 kid parts; type and gap tokens applied to every board; one colour per kid day and night (`kidA` #56B4E9, `kidB` #E69F00) and `pickBlue` #2E8FE0 for ✓/picked/focus. Details in the screen spec change log.
- 2026-11-08: step 5 questions answered in the spec (missions, trips, done state, home entry A1-MVP, C5); trip editing moved to N1.
- 2026-11-08: N10 portrait and resizable windows added (landscape sizing formulas are in the M2 spec now; user chose landscape first).
- 2026-11-08: scope change (user): live bus (N1 core) and medals + slide to go (N2) move into the MVP as rows 10–11 and build step 6; crowding, shuttle, plan B screen and nudge stay Next; step 5 is finished as built, the timetable strip becomes the no-live / car / walk fallback.
- 2026-11-08: step 6 design: A2-live board and spec, C2 MVP cut, "Going" row spec; a real bus number in N1a replaced by a placeholder.
- 2026-11-08: **no MVP stage** (user): one build plan; the morning (missions, timetable look, live bus, C2, slide and medals, "Going" row) is one step 5; Next is "after the morning", step 6 on. Board ids renamed: A2-live → A2, A2-MVP → A2t, A2-MVP-w → A2t-w, A1-MVP → A1m, old A2 (plan B and crowding) → A2b, E4 retired (the timetable look replaces it).
- 2026-11-08: build status from the main session: steps 1–2 merged, 3–4 built in open PRs, step 5 partly built.
- 2026-11-08: step 5 "Morning" built in full (live look, C2, slide and medals, A1 status line, Going row via a new `ChoiceCircles` part); waiting for the user's check on the iPad.
- 2026-11-08: LTA key built in (git-ignored local config); stop and buses move to first-run setup S3 "Getting to school" (user).
- 2026-11-09: slide and All done keep a "Ready!" done look with "Not yet" undo; no "Back to the clock"; local config = LTA key only (user).
- 2026-11-09: step 6 started by the main session (E1, first-run setup). S1–S4 boards brought to the current rules and moved to "Building now" with E1; S4 asks only for what is built (lock now, notifications with the nudge; microphone M5, camera M6, Screen Time later stay hidden). Layout v6.
- 2026-11-09: school data for S2 built in the notes folder (`school-data/`: 337 MOE schools, MOE calendar 2026–2027, hours for 21 sampled primaries, 81 international / private schools). The international list comes from the SWDA register, which is not open data. User decision (2026-11-09): school search is only there to fill in term dates and hours, which come from each school's own site, so the list stays as it is in the private build for the family's iPad; before the app goes to other families (TestFlight / App Store or the backend), rebuild the list of names and addresses from the schools' own sites so nothing comes from SWDA; hours for the other 161 primaries wait for the backend refresh job.
- 2026-11-09: follow-up from PR #30: MOE term dates are stored per school (`usesMoeTerms`) but do not yet fill the holiday list from `moe-calendar.json`; international schools with `termDates` likewise.
- 2026-11-09: kit batch to come: `preschool` picture (for the Preschool block), plus the bring things (swimsuit, goggles, towel, rollerblades, helmet, library bag) once the sketches are approved, and the redrawn car and taxi.
- 2026-11-09: follow-up from PR #30: move the row labels of C2, C3/C4/C3g/E5, C5 and C1 to caption bold on one line (S2 and S3 already use it); touches every grown-up form and its snapshots.
- 2026-11-09: build plan row 6b "Events, one shape" (user decisions: linked events skip with the event before them; medal on/off per event).
- 2026-11-09: N11 map stop picker added (later).
- 2026-11-09: school data decision (user): lists, terms, hours and locations are public data and every real build bundles all of it; the international and preschool lists live in a private data repo (set up by the school-data session after the preschool research) that the build copies from; later the app fetches updates from a data store.
- 2026-11-09: N13 CI read access to the private data repo (later).
- 2026-11-09: build plan row 6d "Grown-up mode" (C6 absorbed, C1 → Settings, List kept).
- 2026-11-09: build plan row 6c "Repeats and dates" (user decisions: two edit tabs with "from when?"; linked events skip on no-school days unless given a set time).

## Goal (the user's words)
> **See today's schedule on this iPad, and do today's missions.**

**No MVP stage** (user, 2026-11-08): there is one build plan, in order. Nothing is designed or built twice as a cut-down version first. "Later" means not planned yet. The bus needs the network; without live times the morning screen shows its timetable look, so everything else still works offline.

---

## 1. In the build plan

| # | Feature | Boards | Why | Notes |
|---|---|---|---|---|
| 1 | Home clock, two kids: 24 h pie, hand, weekday / until, Kid B now and next | A1 | This *is* "see today's schedule" | Right panel: Kid A Next row + time left ("now and next" rule, spec) |
| 2 | Weekend and holiday home | E3, E3b | The view must work every day | Same clock with the Sat or Sun template |
| 3 | Day templates (Mon–Fri, Sat, Sun) + every-week + just-once items, merged by priority | model | The schedule itself | Seed data for the first run |
| 4 | Edit the day template: drag times on the clock | C6 | Seed times never match real life; without this the clock is wrong | Agreed for M2 |
| 5 | Add and edit items: every week, just once, skip one, remove | C3, C4, C3k, E5 | Real weeks need changes | — |
| 6 | Grown-up lock (Face ID) and the kids hub | C0, C1, E6 | Kids must not edit the plan | C1 rows for later features stay hidden |
| 7 | Morning missions: Kid A checklist, Kid B picture cards (a grown-up taps), "All done!" for a kid with no outing | A2, A2t, A3, C5 | This *is* "do today's missions" | The same screen carries the way there (rows 10–11) |
| 8 | Crayon design system and kit pictures | 0a–0f, kit | Already built (M1) | — |
| 9 | Basic accessibility: VoiceOver labels, Reduce Motion respected, contrast | all | Required for any release | — |
| 10 | Live bus: LTA arrivals for the family's stop and bus numbers, the toy-town map with the live bus coming to our stop, bubbles (number, minutes, "my bus"), "Leave in" + "On time" / hurry on the mission screen and on home | A2 (live look), A1 (Leave in), C2 (stop, buses, walk time); no live times → A2t (timetable look) | Getting to the bus is the point of the morning (user, 2026-11-08) | No crowding, no shuttle, no plan B screen. No live data → the timetable look (A2t) with "no live times". Stop code and API key are entered on the iPad and stored there, never in the repo. |
| 11 | Medals and slide to go: Kid A slides "Ready? Slide to go" (always awake, never locked by missions); medal from the time only; Kid B (no trip) taps "All done!" | A3, 0b SlideToGo, A2 | Same screen as 10; splitting it meant building the end of the morning twice | Medal rules: M2 spec "A2 live look" |

### Also in the build (the user's choice, 2026-11-08)
| Item | Boards | Decision |
|---|---|---|
| New-slot hop | 0g2 | **keep** (current scope) |
| Picture rigs, debug "Rig scale" slider, default 1.5 | 0g3, 0g3b | **keep** |
| Night look + sky switch | A1n, 0g | **keep** |
| School holidays: bundled holiday list, "skip school holidays", weekday holiday → Sun | E3 rule, C3 | **keep**: already built, and there is no UX reason to hide it. It only needs the holiday list to be visible to grown-ups: C1 "Holidays" shows the next holiday from the bundled list. |
| One-child layout | E1 | **after the morning** (step 6) |
| Other motion extras: hour pulse, idle wink | 0g2 | **after the morning** |

## Build order and status
| # | Step | Status |
|---|---|---|
| 1 | Day templates and the new seed | done (PR #10 merged) |
| 2 | Home: A1 and E3/E3b in `KidScreen`, picture size and radius rules, free time as paper, new-slot hop, night look, sky switch, now/next rule, `KidFace` | done (PR #11 merged) |
| 3 | Picture rigs playback + debug "Rig scale" slider (default 1.5 from rigs.json) | built (PR #13 open; with the app icon and school-roof flags) |
| 4 | C6 Our day | built (PR #14 open, with board 00 principles) |
| 5 | **Morning** (one step): Kid A checklist, Kid B cards, "All done!", C5 editor; the way strip with its timetable look (car, taxi, walk, no live times) and its live look (bus service module for LTA arrivals, key and stop stored on the iPad); C2 bus settings; "Leave in" + "On time" on A2 and A1; slide to go and medals; the "Going" row on C3/C4/E5 | built in full (feature/m2-morning-live, not pushed; installed on the iPad, waiting for the user's check) |
| 6b | **Events, one shape** (user, 2026-11-09; spec "Events: one shape for every item"): From / linked events, trip way back, bus route per event (1st and 2nd choice), Bring, missions before/after, medal switch, mission windows, slide and done per outing | design: sketches SK1–SK4 in review; model first, then form rows, then windows |
| 6c | **Repeats and dates** (user, 2026-11-09; spec "Repeats, dates and changes", sketches SK10–SK11): Runs start/end (end of term, date, count, none), skip school holidays from the term data, linked time worked out per day, No school days (skip / set time), Today vs Every week with "from when?", exception rule; then monthly, yearly, multi-day and extra one-off sessions in the same plan |
| 6d | **Grown-up mode** (user, 2026-11-09; spec "Grown-up mode", boards G0–G8): pencil way in, the day on the clock (absorbs C6), List, edit screens with This day / All days (E5, School G4), "from when?", Settings (replaces C1), change school |
| 6 | After the morning, proposed order: E1 one child, first-run setup (S1–S4), school shuttle, bus crowding, "time to leave" nudge, reference time zone, the rest of the delight pack, taxi ETA, portrait and windows | later |


### Design to finish before the build reaches it (added 2026-11-08 review)
| Needed by | Item | State |
|---|---|---|
| step 2 (now) | `CrayonKit` primitives the boards now use | done 2026-11-08: M2 spec "CrayonKit UI parts", reference in `handover/crayon-ui-ref/` |
| step 5 | Mission screen, timetable look | done 2026-11-08: board A2t |
| step 5 | Mission screen spec section | done: M2 spec "A2 · Morning" |
| step 5 | C5 mission editor: "up to 8", per-kid picture cards | done 2026-11-08: spec "C5" |
| step 5 | Mission data, trips, done state, home entry | done 2026-11-08: spec "Morning data" + board A1m |
| step 5 | "Going" row on C3/C4/E5 and C1 "Getting there" to edit a trip (way + leave before) | done 2026-11-08: board C3g + spec |
| step 5 | A2 live spec (map in the strip region, bubbles, "Leave in", On time / hurry, fallback to the timetable strip), medal + slide spec, C2 details (stop, buses, walk time, key) | done 2026-11-08: board A2, spec "A2 live look" and "Bus settings" |
| later steps | Crowding, shuttle, plan B | boards done ahead of time (A2b, A2s, A3s; no build impact) |

---

## 2. After the morning (the build plan continues)

| # | Feature | Boards | Category |
|---|---|---|---|
| N1 | Bus: in build step 5 (live look, C2, timetable fallback). Left for later: the plan B buses on the map and the plan B switch screen | A2b, C2 | bus |
| N1a | Bus crowding in the windows: live load → passenger overlay on each bus (busSinglePax1–3, busDoublePax1–3, busMiniPax1–3; 1 seats free, 2 standing, 3 nearly full). Passengers are the feelHappy face drawn small, and the overlay sits in the same view as the bus, so it moves with the bus (map rock and tap rig). No data → plain bus. Bubbles keep only number, minutes, "my bus" dot and "→ {change bus}". Buses rock on the map (0.9 s loop, 1°/2 pt) and their wheels turn all the time (360° every 0.9 s, linear); both off with Reduce Motion. Wheels have a white spoke and a steel hub so the turn is visible; bus rigs (busDouble, busSingle, busMini, busShuttle) have body + back wheel + front wheel parts, so the map draws the body run and spins the two wheel runs around their centres. | A2, A3, E2, kit 0d3 | bus |
| N1b | School shuttle as a way to go, chosen for the whole term, not per day (user, 2026-11-08: a shuttle is booked for a term): Public bus or School shuttle in C1 Getting there / C2, with the term dates; car or taxi stay one-off changes. A shuttle term and a bus term never share a morning screen; shuttle = pickup name, time, walk time; going home chosen separately. A2s: one busShuttle on the map, "Shuttle at 7:20", "Leave in" from the timetable, Hurry chip, missed → "Ask a grown-up" (no plan B), no bubble or passengers. | A2s, C1, C2 | bus |
| N2 | (in build step 5; kept here as the full rule) Medals (gold / silver / bronze from the leave time) and slide-to-go. Slide to go is always awake ("Ready? Slide to go"); missions help but never lock it (user, 2026-11-08: busy mornings). Medals come from the time only. Missions for both kids are one row of 112 pt crayon circles in the kid's colour (Kid A sky, Kid B apricot) with a caption and a blue check when done; the current one has a bold caption. No big "now" band (user, 2026-11-08: less pushy, matches Kid B). Too many missions: no sideways scrolling (kids never scroll). The row holds 6 a kid with two kids, 8 with one; done missions fold into one ✓ circle with a count at the start of the row; if it still does not fit, the last circle is "+n" and tapping it turns the row to the next page (whole page, no half scroll). C5 suggests at most 8 missions a kid. Each kid finishes on their own (user, 2026-11-08, option A): Kid A slides, Kid B taps "All done!"; a finished kid's column turns into its done state (medal, "Ready to go!") while the other keeps going; nobody waits for a sibling and there is no shared finish (A3, A3s). 3–4 kids (draft A2f): kids listed down the left (face, progress ring, "3 of 6 done", medal when ready); the chosen kid's missions and go button on the right; first up = who leaves first and is not done; tap a name to switch. From 2 kids up every morning screen uses this layout (A2, A2s, A3, A3s, E4 updated 2026-11-08); 1 kid keeps E2. The chosen kid has a crayon band in their colour with a notch toward the missions; progress rings are crayon (tools/crayon-ring.js, crayon-pick.js); Slide to go is the 864-wide crayon pill. Open: whether the youngest should come first. Wording: each kid shows only their own leave time, "leave at 7:25 am" (from the bus or shuttle plan and the time to be in); no comparing words like "leaves first"; a kid with no trip today shows "home today". The order of the list does the comparing. | A3, 0b SlideToGo | missions, rewards |
| N4 | **Reference time zone**: show the family's schedule in a chosen zone (e.g. view Korea time from Singapore) | new: setting in C1, a zone chip on the clock | schedule, settings |
| N5 | Rest of the delight pack: hour pulse, idle wink | 0g2 | delight |
| N8 | One-child layout (also used by an iPad set to show one kid) | E1 | kids |
| N6 | First-run setup (family, school, getting to school: stop code + buses + walk, permissions) | S1, S2, S3 (new 2026-11-08), S4 | setup |
| N7 | "Time to leave" nudge (local notification) | — | bus |
| N10 | Portrait and resizable windows (iPadOS 26 cannot refuse them): layout switch by free space (two columns → stacked → clock only), boards for 12.9" portrait and a half window; see the research report "아이패드 화면 크기 대응 레이아웃" | — | sizing formulas (landscape) |
| N11 | Pick the bus stop on a map (user, 2026-11-09): map button at the end of the Stop field; a "Find your stop" sheet centred on the school, LTA stop pins (clustered), search by stop or place, tap a pin → name, road, code, buses, "Use this stop"; plus a get-off stop so walk, ride and car times are worked out (MapKit ETA for walk and car, LTA BusRoutes distance for the ride), editable, with "no bus links these stops" help | S3, C2, C2c; spec "Pick the stop on a map" + "Get-off stop and worked-out times" | bus |
| N12 | Setup polish from the iPad (user, 2026-11-09): S3 kid tabs (one screen, no per-kid Next); Preschool search from the ECDA list (private resource), typed drop-off / pick-up, "Closed on public holidays"; family Home on the map (device only) for walk and car times | S2, S3, map picker; spec "S3 · Getting there", "Where the kid goes in the day" | setup |
| N13 | CI builds with the private school data (user, 2026-11-09): read-only deploy key on the private data repo (private key as a secret in the public repo; fine-grained token or GitHub App as alternatives); PR checks build with `public_build=1` and no secret (fork PRs get none; never `pull_request_target` with secrets); real builds only on push to develop/main or manual dispatch, behind an approval environment; never upload the .ipa as a public Actions artifact (send it to TestFlight); no data in logs | CI | platform |
| N14 | School data from CloudKit (user, 2026-11-09): publish every list from the private data repo to the CloudKit public DB (manifest + schema versions; validate and decode before upload) — owned by the school-data session; the app fetches newer compatible files, keeps bundled ones as fallback, follows the remote data safety rules, and shows the "School lists" refresh row on S2 and C9 — owned by the implementation side (may start its own session) | S2, C9; sketch SK5; spec "School data delivery and refresh" | platform |
| N9 | Taxi day: a grown-up types the ride-hailing ETA once ("taxi in 7 min"); the way strip counts down to it. No ride-hailing API: Grab has no public API for a rider's own booking (checked 2026-11-08). | A2t way strip | bus |

### N4 · Reference time zone (UX)
- **Family time zone**: the zone the plan is written in. It is set once in C1 → "About the family" (default: this iPad's zone at first run). Every template slot and item is stored in family time.
- **Show times in**, a per-device setting: "Family time (default)" or "This iPad's time".
  - In the first case, an iPad that is travelling (e.g. in Korea) still shows the Singapore day, and the clock gets a chip under the hub: "Singapore time" (caption).
  - In the second case, the plan is converted. The day changes at local midnight; slots that cross the boundary are split across the two days.
- Kid screens never show two times at once; the chip is the only sign.
- Grown-up screens show times in family time with the zone name in the header caption while the device is in another zone.
- Engineering note: all time already flows through dependencies (`@Dependency(\.date)`, calendar/zone). The change is a family-zone value plus a per-device display preference.

---

## 3. Later (by category)

| Category | Item | Boards / backlog ids |
|---|---|---|
| **sync & devices** | Same family data on several iPads (plan below) | new: C8 "Our iPads" |
| sync & devices | iPhone app for grown-ups | — |
| **diary** | Diary page, feelings and energy, voice note, photo, week list, bus league | B2, B3, 0e, B2n |
| **drawings** | Kid redraws a picture on paper, snap and clean, pick the version | D1–D3 |
| drawings | Auto-rig a kid's drawing so it can play like a kit picture (plan in section 5) | D3 + new review step |
| delight | Tag kit layers with part names so rigs are derived, not hand-listed (plan in section 5) | kit.js |
| **school calendar** | Import from photo / PDF / text / link (on-device reading; Apple Intelligence or a manual fallback) | C7 |
| **evening and screens** | Evening routine missions, video time plan, iPad Screen Time hand-off | B1, EV backlog |
| **rewards** | Puzzle album, sticker book, league level-up celebration | RW backlog |
| **language** | Korean UI (String Catalog first, then translation), per-kid language | — |
| **art styles** | Marker / paint / pencil kits, in-app style switch | ST-1…ST-16, 0i, 0j |
| **kids** | One-child layout, face and hair options, nursery for Kid B | E1, S1 |
| **platform** | Server-side features (school email import, remote push) | PL backlog |

---

## 4. Plan: one family on several iPads (Later, sync & devices)

Example household: a 12.9″ iPad Pro on the living-room wall and a smaller iPad in a kid's room.

### Technology choice
- **Recommended: iCloud (CloudKit) with sharing.**
  - Native, works offline, push updates in seconds.
  - No extra sign-in on a kid's iPad.
  - Needs the paid Apple Developer account, which is already planned for M7.
  - The family data lives in one CloudKit zone that the first iPad **shares** with the others (`CKShare`). That works even when the iPads use different Apple IDs, e.g. a child account on the kid's iPad.
- **Google Drive: not recommended.**
  - Every iPad would need a Google sign-in, including the kid's.
  - There is no push, so the app would have to poll.
  - Conflict handling would be ours to build on top of files.
- The app already keeps storage behind `ScheduleStore`, so a synced store replaces the local one without screen changes.

### Accounts: nobody switches logins (2026-11-08)
- The parent's Apple ID **owns** the family data, in a shared CloudKit zone.
- Each other iPad **keeps its own Apple ID**, including a kid's (Family Sharing child) account, and joins the share once as a participant with read and write access. Write access is needed so mission checks sync back.
- A second parent joins the same way from their own account.
- Engineering note: SwiftData's built-in sync cannot share, so the synced store uses CKSyncEngine or Core Data + CloudKit sharing behind `ScheduleStore`. It needs the paid developer account.

### Roles
| Role | Who | Can do |
|---|---|---|
| Owner | the parent's iPad that started sharing | everything, plus add and remove iPads, stop sharing |
| Grown-up participant | another parent's iPad | everything behind its own Face ID lock, except removing the owner |
| Kid iPad | an iPad set to show one or both kids | kid screens; grown-up screens only behind that iPad's lock (a parent's face) |

### Start sharing (owner, grown-up screen C8 "Our iPads")
Opened from C1 → "Our iPads", behind the lock.
1. **First time**: a short card.
   - "Use this family on other iPads. Each iPad keeps its own Apple account. Changes show up on all of them."
   - Button "Start sharing". The app creates the share.
2. **Add an iPad** (main button):
   - A sheet with a big **QR code**, plus "Send a link" (AirDrop / Messages; the system share sheet).
   - Caption: "On the other iPad, open Family Planner and tap 'Join a family'. Or scan this with its camera."
   - The sheet stays open and turns into "Kid A's iPad joined ✓" when the other side accepts.
3. **The list of iPads**, one `ListRow` each:
   - device name, which kids it shows (dots), "Last seen 2 min ago"
   - "›" opens that iPad's card: rename, "Remove from family"
   - Pending invites show as "Waiting… (sent 3 min ago)" with "Cancel".
4. **Stop sharing** (owner only), at the bottom in `lateText`. It needs a confirmation: "Stop sharing? Other iPads keep what they have now but stop getting changes."

### Join (kid iPad or second parent)
- **First run** on a new iPad: the setup screen starts with two big choices:
  - "Start a new family here"
  - "Join a family from another iPad"
- **Join**:
  - The screen shows the camera (to scan the owner's QR code) and "Or open the link you were sent".
  - Caption: "A grown-up starts this on their iPad: Our kids → Our iPads → Add an iPad."
- **Accepting**: scanning or tapping the link opens the system iCloud sharing sheet ("Join 'Family Planner'?"). The grown-up taps Join.
  - If a child account's Screen Time blocks it, the app says: "This iPad needs a grown-up's OK. Approve it in Screen Time, then scan again." To be confirmed on a real device.
- **After joining**: "Which kids does this iPad show?" (Both / Kid A / Kid B), then "Show times in: Family time / This iPad's time" (only if the zones differ). Then the clock.

### States on a joined iPad
| State | Kid screens | Grown-up screens |
|---|---|---|
| **Before pairing** (chose Join, not accepted yet) | Only the join screen: no clock, no fake data | — |
| **Syncing the first time** | The clock appears empty with a gentle "Getting your family…" under the hub (caption) for at most a few seconds | Same |
| **Online** | Normal | C8 shows "Up to date" |
| **Offline** | **No change**: the clock runs from the last copy; mission checks are kept and sent later | A small chip in the header: "Offline · last synced 7:02". Edits are allowed and queued. |
| **Conflict on return** | Never shown | The quiet note from "Two iPads editing", or the "Keep yours / Use theirs" card for a whole day |
| **Removed from the family**, or sharing stopped | A calm full screen with the home picture: "This iPad isn't connected to the family any more. Ask a grown-up." No clock, so nobody follows an out-of-date plan. | Behind the lock: "Join again" (back to Join), "Keep a copy here" (becomes its own family, no sharing), or "Clear this iPad" |
| **The owner's iCloud is signed out** | Same as Offline | C8: "Sharing is paused: the owner iPad needs iCloud." |

### What is shared, and what stays on each iPad
Per-device settings never sync. They are asked once at join and can be changed later in that iPad's C1 → "This iPad".

| Shared (family) | Per iPad (device) |
|---|---|
| Kids, day templates, every-week and just-once items, skips | **Which kids this iPad shows**: Both (A1 layout) / Kid A only / Kid B only (one-kid layout, E1) |
| Mission lists, today's mission checks, medals | Sky switch shown or hidden; night look on or off |
| Holidays, school, buses and routes | Show times in: family time / this iPad's time (N4) |
| Diary entries, drawings (later) | Grown-up lock (Face ID on this iPad) |
| Family time zone | Debug settings, the rig scale |

### Two iPads editing at the same time
- **Small records**: every template slot, item, skip, mission and mission-check is its own record with a stable id and an `updatedAt`. Two grown-ups editing different things never conflict.
- **Same record on both iPads: newest wins** (by `updatedAt`, server time when it arrives).
  - The iPad whose edit lost shows a quiet note in the grown-up screen: "Changed on the other iPad: Swimming now 3:45–4:45" with "OK".
  - Nothing is lost silently from kid screens.
- **Delete vs edit**: a delete wins unless the other iPad's edit is newer than the delete. Deleted records keep a tombstone for 30 days so a late edit cannot resurrect them by accident.
- **Today's mission checks** merge per mission: checked if any iPad checked it. Un-checking is a newer explicit change, so it wins only if it is the newest.
  - So the kid can tick "Brush teeth" on the kitchen iPad and see it ticked in the bedroom.
- **The day-template drag (C6)** saves on "Save the day" as one change set. If the other iPad saved the same day type in the meantime, a card asks before replacing: "The Mon–Fri day changed on the other iPad. Keep yours / Use theirs".

### Offline
- Every iPad works fully offline; changes queue and sync when back online.
- Grown-up screens show "Last synced 5 min ago" in C1; kid screens never show sync state.

### Data needed (already noted by the main session)
- Stable ids (present), `updatedAt` per record, tombstones for deletes, a family-zone value, a device-settings store that never syncs.

---

## 5. Plan: automatic rigs (Later, drawings and delight)

### What a rig needs
1. **Parts**: which pixels or layers move together.
2. **Pivot**: where each part is attached.
3. **Move**: one move from the fixed vocabulary (rock, bob, slide, spin, rise, fall, press, blink, flicker, twinkle, hop).
4. **Rules**: rigid parts only, small amounts, faces move only with the head, one play ≤ 1.2 s.

Rules 3 and 4 already exist as data (`rigs.json`). Automation is about 1 and 2.

### Step 1: kit pictures (cheap, do first)
- In kit.js, give layers a **part tag** where they are drawn, e.g. `flag`, `wheel`, `arm-left`, `steam`.
- Add a **category template** per slot type:
  - vehicle → body bob, wheels spin
  - flag → rock at the pole
  - food → steam rise
  - person → arms rock at the shoulders, head tilt ≤ 5°, eyes blink
- `make art` then builds `rigs.json` from tags + template. Pivots come from the tag's attachment point.
- A **rule checker** fails the build if a rig breaks the rules: too many parts, a pivot outside its part, a face part moving alone, or amounts over the limit.

### Step 2: a kid's drawing (photo)
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

## Next steps for planning
- Board **C8 "Our iPads"** and the "Join a family" first-run screen: draw when sync moves up from Later.
- Board for **N4**: a C1 setting row and the zone chip on the clock: draw when N4 starts.
