# Breach-lite — itch.io page kit

## Title
Breach-lite

## Short description
Three mechs, a 7x7 city, and a swarm that shows you every move. Push, swap and redirect so the bugs hit each other instead of the grid.

## Page text
Every enemy shows exactly what it will hit at the end of your turn, with a numbered resolution order.
You have perfect information and too few actions.

- **Push, swap, redirect.** Attacks hit whatever is on the tile *when they resolve*, so shove a Scarab one tile and its boulder lands on its friend.
- **See before you commit.** Hover any target to preview the exact outcome: damage numbers, push arrows, deaths, fires and grid loss. The preview runs the real rules on a copy of the board, so it is never wrong.
- **Three mechs:** the Brawler punches and shoves, the Artillery lobs shells that scatter everything around the impact, the flying Warper swaps places with any unit in range (try swapping a bug into the water).
- **Six bug species + the Hive Queen:** Beetles, Hornets, Spitters, Scarabs, Diggers that burrow anywhere and Blobs that explode in chains.
- **A full run:** 4 islands (forest, water, mountains, chasms) x 2 missions, a Reputation shop between islands (grid power, reactor-core weapon upgrades, 12 weapons, 2 slots per mech) and a 2-phase finale.
- **Deterministic:** no hit rolls. The only dice are the grid's 15% chance to shrug off a hit, and even that shows in the preview.

## Controls
| Action | Mouse | Keys |
|---|---|---|
| Select mech | Left-click | 1 / 2 / 3 |
| Move | Left-click a blue tile | |
| Arm weapon | Weapon button | Q / W |
| Preview / fire | Hover / left-click a yellow tile | |
| Cancel | Right-click | Esc |
| Undo move (until the mech acts) | Undo button | Z |
| End turn | End turn button | Space |
| Reset turn (once per mission) | Reset button | |

New players: start with **Tutorial** on the main menu.

## Uploads
| File | itch.io setting |
|---|---|
| `breach-lite-web.zip` | Kind: HTML. Tick **"This file will be played in the browser"**. Viewport 1280 x 720. The build is single-threaded, so **SharedArrayBuffer support is NOT needed** (leave it unticked). Enable the fullscreen button. |
| `breach-lite-windows.zip` | Windows executable |
| `breach-lite-macos.zip` | macOS (unsigned: right-click → Open the first time) |
| `breach-lite-linux.zip` | Linux executable (x86_64) |

Build them with `tools/package.sh` (needs Godot 4.4.1 + export templates). Output: `build/dist/`.

## Screenshots (screenshots/)
1. `preview_2_3.png` — the attack preview: a punch kills a Blob, the explosion damages its neighbours and cancels its attack.
2. `mission_7_2.png` — a Granite Spine mission with numbered telegraphs and spawn rings.
3. `tutorial.png` — the tutorial with contextual hints.
4. `run.png` — the Reputation shop between islands.
5. `menu.png` — main menu.

Regenerate with `xvfb-run -a godot --rendering-driver opengl3 -- --screenshot=<fixture>[:x:y]` (fixtures in data/fixtures; also `menu`, `run`, `mission:<seed>:<island>`).

## Tags
tactics, turn-based, roguelike, strategy, mechs, puzzle

## Credits
Made with Godot 4.4.1. Tests: GUT 9.4.0 (MIT). All art is code-drawn; all sound is synthesised by tools/gen_sfx.gd.
