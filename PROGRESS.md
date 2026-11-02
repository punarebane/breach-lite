# Progress

## Done
- **M1** Core rules as pure RefCounted classes (core/: Board, Unit, GameState, Action, Event, Resolver, Rules, SeededRng, Data, Fixture), BFS movement incl. flying/burrowing, push/bump/water/chasm/fire/mountains/buildings/grid defence, 12 data-driven weapons.
- **M2** Presentation: BoardView (`_draw`), UnitView (code-drawn), OverlayView (telegraphs + preview overlays), MissionView (input, HUD, event playback with tweens). Select/move/undo/attack with live preview; 1/2/3, Q/W, Z, Space, Esc/right-click.
- **M3** Seeded utility AI with sequential planning, numbered telegraphs, phase B resolution, spawns + blocking, grid power, win/lose, reset turn. Preview property test (2,000 pairs; events and full state fingerprint) and invariant fuzz (500 missions) pass.
- **M4** Mission generator (templates + island flavours, connectivity check), 4 islands x 2 missions + 2-phase Hive Queen finale, bonus objectives → Reputation, shop (grid, reactor cores, 12-weapon pool, 2 slots), save/continue.
- **M5** Balance sim on target (below). Juice: tweens, hit pause, screen shake, pulsing telegraphs/spawns, idle animation, generated SFX. Main menu, tutorial with contextual hints, hover tooltips for every unit and tile.
- **M6** Export presets: Web (single-threaded, no SharedArrayBuffer), Windows, macOS (universal, unsigned), Linux. `tools/package.sh` → `build/dist/*.zip`. ITCH.md. Screenshots in screenshots/. Web smoke test (Playwright): menu appears, click starts tutorial, 0 console errors.

## Acceptance checks (all passing, 2026-11-02)
- GUT headless: **104 tests passing** (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`, ~20 s).
- Preview property test + invariant fuzz: pass (tests/test_property_fuzz.gd).
- Balance targets: met (below).
- Web: `node tools/web_smoke.js build/web` → `WEB SMOKE: PASS`, 0 console errors.

## Balance (tools/sim.gd, 300 seeded runs, greedy 1-ply bot)
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
Targets: island-1 mission win rate > 85% ✓, run win rate 10-30% ✓. Single worker: `godot --headless -s tools/sim.gd -- --runs=300` (~25 min); 4 parallel workers with `--start`/`--out` + `tools/sim_merge.gd` (~4.5 min).

## How to run things
- Play: open the folder in Godot 4.4+ and press F5 (main scene: scenes/main.tscn).
- Screenshots (needs a display): `xvfb-run -a godot --rendering-driver opengl3 -- --screenshot=<fixture>[:x:y]` (also `menu`, `run`, `mission:<seed>:<island>`).
- Regenerate SFX: `godot --headless -s tools/gen_sfx.gd`.
- Package: `tools/package.sh` (needs export templates 4.4.1).

## Known bugs / rough edges
- Damage numbers in previews show HP actually lost (a 2-damage punch on a 1-HP Blob shows -1).
- Playback moves units in a straight line, not along the BFS path.
- Mid-mission saves are not supported (continue resumes between missions), by design.
- macOS build is unsigned (Gatekeeper: right-click → Open).

## Next up
- Feel pass from real playtesting: animation timing, an end-of-turn "threat summary", path-following move tweens.
- More mission templates and a second boss pattern for replay variety.
