# Progress

## Done
- M1: project setup, GUT, core rules (Board, Unit, GameState, Action, Event, Resolver, Rules), 12 data-driven weapons, tests.
- M2: board presentation (BoardView/_draw renderer, UnitView code-drawn units, OverlayView for telegraphs + previews), select/move/undo/attack with live preview, HUD, keyboard shortcuts, `--screenshot=<fixture>[:x:y]`.
- M3: enemy utility AI (sequential planning), telegraphs with order badges, phase B resolution (fire → attacks in order → spawns), spawn blocking, grid power, win/lose, reset turn; mission generator (needed early for the fuzz); preview property test (2,000 pairs, events + full state fingerprint) and invariant fuzz (500 seeded missions, random-legal-action bot).
- M4: RunState (4 islands x 2 missions + 2-phase Hive finale), island flavours + templates in the seeded generator, bonus objectives → Reputation, shop (grid / reactor cores / 12-weapon pool, 2 slots per mech), save/continue (user://save.json), run screen, main menu, tutorial fixture with contextual hints, generated SFX (tools/gen_sfx.gd → audio/*.wav). Greedy PlayerBot + tools/sim.gd written.
- M5: balance sim run (below), hit pause, screen shake, telegraph pulses, idle unit animation, SFX hooks, main menu, tutorial with contextual hints, hover tooltips for every unit/tile and weapon buttons.

## Balance (tools/sim.gd, 300 seeded runs, greedy 1-ply bot)
Run with `/home/claude/runsim.sh 300`-style parallel workers or `godot --headless -s tools/sim.gd -- --runs=300`.

```
runs: 300   run win rate: 22.3%
missions: 2327   grid lost per mission: 1.10   bonus rate: 68.1%
  final1   played  104  win  87.5%  grid lost/mission 0.89
  final2   played   91  win  73.6%  grid lost/mission 0.74
  island1  played  600  win  99.7%  grid lost/mission 0.78
  island2  played  594  win  97.5%  grid lost/mission 0.88
  island3  played  542  win  88.9%  grid lost/mission 1.29
  island4  played  396  win  69.9%  grid lost/mission 1.80
```
Targets: island-1 mission win rate > 85% ✓ (99.7%), run win rate 10-30% ✓ (22.3%). The first data pass already met both, so no tuning changes were needed; difficulty ramps through the islands' enemy pools and spawn counts (data/islands.json).

## State
- Tests: 101 passing (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`).
- Screenshots need a display: `xvfb-run -a godot --rendering-driver opengl3 -- --screenshot=demo`.

## Known bugs
- none known

## Next up
- M6: export presets (Web single-threaded, Windows, macOS, Linux), itch.io zip, ITCH.md, Playwright smoke test of the web build.
