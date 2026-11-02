# Progress

## Done
- M1: project setup, GUT, core rules (Board, Unit, GameState, Action, Event, Resolver, Rules), 12 data-driven weapons, tests.
- M2: board presentation (BoardView/_draw renderer, UnitView code-drawn units, OverlayView for telegraphs + previews), select/move/undo/attack with live preview, HUD, keyboard shortcuts, `--screenshot=<fixture>[:x:y]`.

## State
- Tests: 60 passing (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`).
- Screenshots need a display: `xvfb-run -a godot --rendering-driver opengl3 -- --screenshot=demo`.
- Main scene loads the demo fixture directly (menu comes in M5).

## Known bugs
- none known

## Next up
- M3: enemy AI tests, resolution phase tests, spawns, grid power, win/lose, preview property test, invariant fuzz.
