# One family on several iPads: design (Later)

Design session; moved from the product backlog (retired 2026-11-28, local issue 052). Later work, not planned yet: local issue 038. Public-safe: Kid A / Kid B, no real places.

Example household: a 12.9″ iPad Pro on the living-room wall and a smaller iPad in a kid's room.

## Technology choice
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

## Accounts: nobody switches logins (2026-11-08)
- The parent's Apple ID **owns** the family data, in a shared CloudKit zone.
- Each other iPad **keeps its own Apple ID**, including a kid's (Family Sharing child) account, and joins the share once as a participant with read and write access. Write access is needed so mission checks sync back.
- A second parent joins the same way from their own account.
- Engineering note: SwiftData's built-in sync cannot share, so the synced store uses CKSyncEngine or Core Data + CloudKit sharing behind `ScheduleStore`. It needs the paid developer account.

## Roles
| Role | Who | Can do |
|---|---|---|
| Owner | the parent's iPad that started sharing | everything, plus add and remove iPads, stop sharing |
| Grown-up participant | another parent's iPad | everything behind its own Face ID lock, except removing the owner |
| Kid iPad | an iPad set to show one or both kids | kid screens; grown-up screens only behind that iPad's lock (a parent's face) |

## Start sharing (owner, grown-up screen C8 "Our iPads")
Opened from G6 Settings → Family → "Our iPads", behind the lock.
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

## Join (kid iPad or second parent)
- **First run** on a new iPad: the setup screen starts with two big choices:
  - "Start a new family here"
  - "Join a family from another iPad"
- **Join**:
  - The screen shows the camera (to scan the owner's QR code) and "Or open the link you were sent".
  - Caption: "A grown-up starts this on their iPad: Settings → Family → Our iPads → Add an iPad."
- **Accepting**: scanning or tapping the link opens the system iCloud sharing sheet ("Join 'Family Planner'?"). The grown-up taps Join.
  - If a child account's Screen Time blocks it, the app says: "This iPad needs a grown-up's OK. Approve it in Screen Time, then scan again." To be confirmed on a real device.
- **After joining**: "Which kids does this iPad show?" (Both / Kid A / Kid B), then "Show times in: Family time / This iPad's time" (only if the zones differ). Then the clock.

## States on a joined iPad
| State | Kid screens | Grown-up screens |
|---|---|---|
| **Before pairing** (chose Join, not accepted yet) | Only the join screen: no clock, no fake data | — |
| **Syncing the first time** | The clock appears empty with a gentle "Getting your family…" under the hub (caption) for at most a few seconds | Same |
| **Online** | Normal | C8 shows "Up to date" |
| **Offline** | **No change**: the clock runs from the last copy; mission checks are kept and sent later | A small chip in the header: "Offline · last synced 7:02". Edits are allowed and queued. |
| **Conflict on return** | Never shown | The quiet note from "Two iPads editing", or the "Keep yours / Use theirs" card for a whole day |
| **Removed from the family**, or sharing stopped | A calm full screen with the home picture: "This iPad isn't connected to the family any more. Ask a grown-up." No clock, so nobody follows an out-of-date plan. | Behind the lock: "Join again" (back to Join), "Keep a copy here" (becomes its own family, no sharing), or "Clear this iPad" |
| **The owner's iCloud is signed out** | Same as Offline | C8: "Sharing is paused: the owner iPad needs iCloud." |

## What is shared, and what stays on each iPad
Per-device settings never sync. They are asked once at join and can be changed later in that iPad's G6 Settings → Family → "This iPad".

| Shared (family) | Per iPad (device) |
|---|---|
| Kids, day templates, every-week and just-once items, skips | **Which kids this iPad shows**: Both (A1 layout) / Kid A only / Kid B only (one-kid layout, E1) |
| Mission lists, today's mission checks, medals | Sky switch shown or hidden; night look on or off |
| Holidays, school, buses and routes | Show times in: family time / this iPad's time (N4) |
| Diary entries, drawings (later) | Grown-up lock (Face ID on this iPad) |
| Family time zone | Debug settings, the rig scale |

## Two iPads editing at the same time
- **Small records**: every template slot, item, skip, mission and mission-check is its own record with a stable id and an `updatedAt`. Two grown-ups editing different things never conflict.
- **Same record on both iPads: newest wins** (by `updatedAt`, server time when it arrives).
  - The iPad whose edit lost shows a quiet note in the grown-up screen: "Changed on the other iPad: Swimming now 3:45–4:45" with "OK".
  - Nothing is lost silently from kid screens.
- **Delete vs edit**: a delete wins unless the other iPad's edit is newer than the delete. Deleted records keep a tombstone for 30 days so a late edit cannot resurrect them by accident.
- **Today's mission checks** merge per mission: checked if any iPad checked it. Un-checking is a newer explicit change, so it wins only if it is the newest.
  - So the kid can tick "Brush teeth" on the kitchen iPad and see it ticked in the bedroom.
- **Our Day edits (G1)** save on "Save" as one change set. If the other iPad saved the same day type in the meantime, a card asks before replacing: "The Mon–Fri day changed on the other iPad. Keep yours / Use theirs".

## Offline
- Every iPad works fully offline; changes queue and sync when back online.
- Grown-up screens show "Last synced 5 min ago" in C1; kid screens never show sync state.

## Data needed (already noted by the main session)
- Stable ids (present), `updatedAt` per record, tombstones for deletes, a family-zone value, a device-settings store that never syncs.

## Boards to draw when it starts
- C8 "Our iPads" and the "Join a family" first-run screen.
