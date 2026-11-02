# Breach-lite

A tactics roguelike made in Godot 4. Three mechs defend a 7x7 city grid from burrowing swarms. Every enemy shows exactly what it will hit next turn, so you push, swap and redirect them into each other instead of the city.

## Play / develop
1. Install [Godot 4.4](https://godotengine.org/download) (any 4.3+ standard build; no .NET needed).
2. `git clone https://github.com/punarebane/breach-lite`
3. In Godot's Project Manager, click **Import**, pick `breach-lite/project.godot`, then press **F5** to run.

New to the game? Pick **Tutorial** on the main menu.

## Tests and tools
- Tests (GUT, vendored): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Balance sim: `godot --headless -s tools/sim.gd -- --runs=300`
- Builds for itch.io: `tools/package.sh` (needs the 4.4.1 export templates)

See `SPEC.md` for the design, `DECISIONS.md` for rule choices, `PROGRESS.md` for status and balance numbers, and `ITCH.md` for the store page.
