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
