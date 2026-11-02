# Progress

## Done
- M1: project setup, GUT, core rules (Board, Unit, GameState, Action, Event, Resolver, Rules), 12 data-driven weapons, tests.
- M2: board presentation (BoardView/_draw renderer, UnitView code-drawn units, OverlayView for telegraphs + previews), select/move/undo/attack with live preview, HUD, keyboard shortcuts, `--screenshot=<fixture>[:x:y]`.
- M3: enemy utility AI (sequential planning), telegraphs with order badges, phase B resolution (fire → attacks in order → spawns), spawn blocking, grid power, win/lose, reset turn; mission generator (needed early for the fuzz); preview property test (2,000 pairs, events + full state fingerprint) and invariant fuzz (500 seeded missions, random-legal-action bot).
- M4: RunState (4 islands x 2 missions + 2-phase Hive finale), island flavours + templates in the seeded generator, bonus objectives → Reputation, shop (grid / reactor cores / 12-weapon pool, 2 slots per mech), save/continue (user://save.json), run screen, main menu, tutorial fixture with contextual hints, generated SFX (tools/gen_sfx.gd → audio/*.wav). Greedy PlayerBot + tools/sim.gd written.

## State
- Tests: 101 passing (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`).
- Screenshots need a display: `xvfb-run -a godot --rendering-driver opengl3 -- --screenshot=demo`.

## Known bugs
- none known

## Next up
- M5: run the balance sim (300 runs), tune data/ to targets; juice (hit pause, telegraph pulses done, screen shake done), tooltips audit.
