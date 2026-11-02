# Decisions

Ambiguities in SPEC.md resolved with the simplest option that fits. Newest last.

## M1 (core rules)
- **Engine**: Godot 4.4.1 stable (official Linux binary), GUT 9.4.0 in addons/gut.
- **RNG**: own Park-Miller generator (`core/rng.gd`) whose state is one int stored in GameState. Two streams: `grid_rng` (grid defence, the only gameplay randomness) and `ai_rng` (AI noise, spawns, generation). Copying a state copies future rolls, so previews are exact.
- **Telegraphs are relative**: an enemy stores direction + distance from itself. Pushing an enemy moves where its attack lands; projectiles re-scan for the first thing in line at resolution time.
- **Pushing off the board edge** does nothing (no bump, no damage).
- **Push order for adjacent pushes** (Arc Shell, Shockwave): up, right, down, left. Each push resolves fully before the next.
- **Multi-tile attacks** (spear, Hive Breath): damage all tiles first, then push from the far end back.
- **Damage then push**: a unit killed by the damage is not pushed.
- **Building hits**: every hit (any damage > 0, or a bump) costs 1 HP and 1 grid power, regardless of damage amount. One grid-defence roll per hit. Objective buildings also cost grid power; losing one fails the "protect" bonus.
- **Destroyed buildings/mountains** become ground (marked rubble for drawing).
- **0-damage hits** don't affect terrain (no fire, no grid loss) unless the weapon ignites.
- **Fire**: hitting a forest sets the tile burning for the rest of the mission. Units that enter or stand on a burning tile catch fire; burning units take 1 damage at the start of enemy phase B. Burning lasts until death. Ignite weapons can also set ground tiles burning.
- **Water/chasm**: ground units (mechs included) cannot move into water or chasms; pushed or swapped in, they drown/fall. Flying units are unaffected.
- **Movement**: BFS; units can pass through allies but never through opposing units. Flying passes over any terrain but must end on a non-blocking tile. Diggers burrow: any standable empty tile is reachable.
- **Disabled mechs** (0 HP) are removed from the board for the rest of the mission (no wreck), then repaired.
- **Hive Queen** is immovable (can't be pushed or swapped) so the boss can't be drowned in one click.
- **Blob** explosions are damage-only (no push) and chain through other blobs.
- **Weapon upgrades**: "damage" (+1; for 0-damage cluster bombs it boosts the adjacent damage), "range" (+1 max range), "special" (per-weapon override set in weapons.json). Each weapon lists which upgrades it accepts.
- **Weapon pool**: 12 weapons in data/weapons.json, including the 3 starters (punch, arc_shell, swap).

## M2 (presentation)
- **Renderer**: BoardView draws terrain with `_draw()`; OverlayView draws telegraphs and previews above units. Swapping these two nodes swaps the renderer.
- **Weapon keys**: Q/W arm weapon slots 1/2 (spec only fixes 1/2/3, Z, Space). Right-click/Esc cancels.
- **Projectile aiming**: click any tile in the line; it maps to the direction.
- **Preview shows the grid-defence roll**: the RNG lives in the state, so the preview knows whether a building resists and shows it ("RESIST"). This is what "exactly match real resolution" implies.
- **Undo** restores only the mech's position/burning flag (moves have no other side effects), and is refused if another mech now stands on the origin tile. Reset turn restores the full start-of-turn snapshot.
- **Board terrain during playback** uses a display copy updated by events, so buildings fall when their event plays.

## M3 (enemies)
- **AI ordering**: enemies plan in unit-id order (oldest first); each applies its move before the next one plans. Telegraph order numbers follow planning order.
- **AI extras** beyond the spec's weights (all in data/ai.json): -3 for ending on a spawn marker, -4 for ending on a burning tile. Noise is uniform [0, 2) from the AI RNG stream per candidate.
- **Enemy weapons never push** (spec gives only damage values).
- **Phase B order**: fire damage → telegraphed attacks in order → spawns emerge → next turn. The mission ends immediately when grid hits 0.
- **Spawns**: marked on free ground/forest tiles in the top 3 rows (fallback: anywhere), never on the last turn; total enemies + markers capped at 6 (rules.json). Hive Queen marks `larvae` larva spawns within 2 tiles of itself.
- **Win**: the mission is won when phase B of the last turn resolves. Missions with `kill_boss` also end as soon as the boss dies.
- **Generator** (gen/mission_gen.gd) was pulled into M3 because the fuzz needs real missions. Layouts are rejected unless all ground tiles form one connected region.

## M4 (run structure)
- **Any mission failure ends the run** (grid 0 or all mechs disabled). Grid power carries over between missions; mechs are fully repaired after every mission (and between the two final phases).
- **Reputation**: +1 per mission won, +1 more if its bonus objective is met (run.json). Each mission rolls one bonus from its template: "kills" (kill 7+), "objective" (objective building survives; objective missions last 4 turns), "no_damage" (mechs take at most 1 damage, i.e. "less than 2").
- **Shop** opens after each island (4 times, the last before the Hive). Offers: always +1 grid (cap 9), up to 2 reactor cores for weapons the squad owns, and random unowned weapons from the pool. Weapons go into slot 2 of a chosen mech (replacing it if full).
- **Final mission**: phase 1 is a 4-turn mixed swarm; phase 2 places the Hive Queen at the top centre and is won by killing her or surviving 5 turns.
- **Save** is written after every mission and shop purchase, deleted when the run ends. Continuing restores the run between missions (not mid-mission).
- **Mission seed** = run seed x 1000 + island/mission offsets, so a saved run regenerates the same next mission.
- **SFX**: tools/gen_sfx.gd synthesises sfxr-style WAVs (square/saw/sine/noise + pitch slide + envelope) from data/sfx.json into audio/ (bundled, committed).
