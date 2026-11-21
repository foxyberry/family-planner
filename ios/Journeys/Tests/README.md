# Journeys

A journey is one flow a person takes through the app, tested through the root store
(`AppFeature`) in the Reflex style: send an action, then check the State a person would see. Most
of what we used to check by hand on the iPad belongs here. A thin layer of real UI tests covers only
what State can't show (holds, keyboard focus, scrolling, sheets).

## How a journey is written
Write it so it reads as plain steps in spec terms, and could be replayed by another platform
("share the test, not the code"; user, 2026-11-21):
- **One test per journey**, named for what the person does (`testOneKidFromAnEmptyIPadToTheHome`).
- **Each step is an action named as in the spec**, then the visible State fields checked with the
  spec's names: `nextTapped`, then `step == .school`. Keep Swift-only tricks out of the step logic.
- **The world is plain data.** `WorldData` holds the time, the stops and their buses, the schools,
  the family ("empty" or "sample") and Face ID's answer, as strings and numbers. `World` turns
  it into dependencies.
- **Anything a journey leaves unfaked is unimplemented**, so unexpected I/O fails the test.
- **No sleeps.** Time moves by `world.clock` only.
- **Wait for effects that run in no fixed order** with `await store.finish()`, then
  `await store.skipReceivedActions()`. The store applies a received action to State only once it
  is received or skipped, so checking State right after `finish()` still shows the old values.
- **Fake values only**: Kid A and Kid B, stop 12345, Example Primary School.
- **Replay round trips a person caused as actions.** For example, a text field sends its text again
  when the keyboard goes away.

A new screen or flow adds or extends a journey (`tca-feature`).

## Later
Two pieces will join this folder:
- the agent driver's protocol, written down as platform-neutral JSON: `ls` gives the screen, its
  State and the actions it accepts, and `do <action> <json>` runs one;
- a per-screen contract of State fields and actions.

Together they are the parity contract another platform would implement to run these same journeys.
