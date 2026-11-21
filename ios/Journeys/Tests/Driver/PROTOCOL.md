# Agent driver protocol (v1)

An agent or a script drives the running app with two commands, `ls` and `do`, as plain JSON
(Reflex style; user, 2026-11-21: "share the test, not the code"). The same commands and the same
journey files work on any platform that implements this protocol and `contract.json`, so the
journeys here can later run against an Android build unchanged. Nothing here is Swift.

## Files
- `PROTOCOL.md`: this page, the commands and how a journey file runs.
- `contract.json`: the parity contract. For each screen: its id, the visible State fields `ls` shows,
  and the person actions `do` accepts with their arguments. Each entry's `ios` binds it to this
  app's code; `scripts/check-driver-contract.sh` checks those names exist.
- `journeys/*.json`: journeys as steps. Each names the Swift journey it mirrors (`same as`).

## `ls`
Returns where the app is and what a person could do now:

```json
{
  "screen": "addChild",
  "stack": ["home", "ourDay", "settings", "addChild"],
  "fields": { "name": "Kid C", "age": "6", "colour": 2, "canSave": false },
  "app": { "relockCaption": null },
  "actions": [
    { "name": "addChild.nameChanged", "args": { "text": "string" } },
    { "name": "addChild.faceTapped", "args": { "face": "string" } }
  ]
}
```

- `screen` is the focused screen's id: `setup` while first run shows; else the top of the grown-up
  stack; else `home`. The `lock` card, when shown, is the focused screen over the home.
- `fields` holds only the fields the contract lists for that screen, with the contract's names and
  types. Never a dump of State: its order, dates and enum payloads differ between platforms.
- `actions` lists the contract's actions for that screen.

## `do <action> <json>`
Sends one person action, named `<screen>.<action>`, with arguments as the contract gives them:
`do setup.nameChanged {"kid": 0, "text": "Kid A"}`. It answers with `ls` right after the action.
- Only what a person causes is sendable: taps, typing, a picked value, the 2 s hold (`home.clockHeld`).
  Results of the app's own work (a load, a save, Face ID's answer) are never sent: they arrive by
  themselves, and the next `expect` waits for them.
- An action for a screen that is not focused is refused with `{"error": "not on <screen>"}`; an
  unknown action or a wrong argument is refused the same way. Nothing changes then.
- Things in a list are named by their index in the screen's `ls` field (`"kid": 0` is the first card).
- A text field's value is an action with the text (`addChild.nameChanged`), not a binding.

## Journey files
```json
{ "journey": "…", "same as": "SwiftTests.testName", "world": { … }, "steps": [ … ] }
```
- `world` is the journey's `WorldData` as plain values (`now`, `timeZone`, `family` "empty" or
  "sample", `faceID`). The app starts in that world (DebugTools launch flags today: `-fpNow`,
  `-fpFamily`); the stops and schools are the journeys' fake ones (stop 12345, Example Primary School).
- `{"do": "<screen>.<action>", "args": {…}}` runs `do`. An argument `"$<field>"` takes that field's
  value from the last `ls` (replaying a text field that sends its text again).
- `{"expect": {"<field>": value, …}}` waits until one `ls` shows every value (`screen` included),
  polling for up to 5 s, then fails with the last `ls`. This is how a journey's `receive` reads:
  "wait until the screen shows it".
- `why` is a note for people; runners ignore it.

## What v1 leaves out
- **Time.** Journeys that wait on the clock (the 2-minute grown-up relock, A3's done view after the
  slide) need the world's clock moved; v1 has no command for it and does not fake one.
- **Screens being redesigned**: Our day's editing (layout v65; v1 has only its way to Settings), the
  bus screens and the morning missions join the contract when they settle.
- **The real hold and keyboard**: `home.clockHeld` is the hold's outcome; the hold itself, focus and
  scrolling stay in the UI tests (`../UI`).

## On a real iPad (step 3, not built)
The driver is debug-only and starts only with its launch flag, listening on 127.0.0.1 (reached over
USB by port forwarding, as WebDriverAgent is). On the family's iPad `ls` would show the real family
and `do` could change it. Proposed (the user decides before step 3): the driver there runs only in a
throwaway world, never on the stored family.
