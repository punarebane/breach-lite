class_name Invariants
extends RefCounted
## Structural invariants that must hold after every step. Returns a list of violations.


static func check(s: GameState) -> PackedStringArray:
	var bad := PackedStringArray()
	var seen := {}
	for u in s.units:
		if not u.alive:
			if u.hp != 0:
				bad.append("dead unit %d has hp %d" % [u.id, u.hp])
			continue
		if not s.board.in_bounds(u.pos):
			bad.append("unit %d out of bounds %s" % [u.id, u.pos])
			continue
		if seen.has(u.pos):
			bad.append("units %d and %d share %s" % [u.id, seen[u.pos], u.pos])
		seen[u.pos] = u.id
		if u.hp < 1 or u.hp > u.max_hp:
			bad.append("unit %d hp %d/%d" % [u.id, u.hp, u.max_hp])
		if s.board.is_blocking(u.pos):
			bad.append("unit %d on blocking tile %s" % [u.id, u.pos])
		if not u.flying and not s.board.is_ground_standable(u.pos):
			bad.append("ground unit %d on %s" % [u.id, Board.TERRAIN_NAMES[s.board.get_t(u.pos)]])
		if u.is_mech() and u.has_telegraph():
			bad.append("mech %d has telegraph" % u.id)
	if s.grid_power < 0 or s.grid_power > s.max_grid:
		bad.append("grid %d" % s.grid_power)
	for sp in s.spawns:
		if not s.board.in_bounds(sp["pos"]):
			bad.append("spawn out of bounds")
	for p in s.board.all_tiles():
		var t := s.board.get_t(p)
		if s.board.is_building(p) and s.board.get_hp(p) <= 0:
			bad.append("dead building standing at %s" % p)
		if t == Board.Terrain.MOUNTAIN and s.board.get_hp(p) <= 0:
			bad.append("dead mountain at %s" % p)
	return bad
