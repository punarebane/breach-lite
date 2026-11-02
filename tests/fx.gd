extends RefCounted
## Test fixtures: build GameStates from ASCII maps.
## . ground  M mountain  ~ water  _ chasm  F forest  B building  O objective

const CHARS := {".": Board.Terrain.GROUND, "M": Board.Terrain.MOUNTAIN, "~": Board.Terrain.WATER,
	"_": Board.Terrain.CHASM, "F": Board.Terrain.FOREST, "B": Board.Terrain.BUILDING, "O": Board.Terrain.OBJECTIVE}


static func state(rows: Array = [], seed_value: int = 1) -> GameState:
	var s := GameState.new(7)
	s.grid_rng = SeededRng.new(seed_value)
	s.ai_rng = SeededRng.new(seed_value + 7)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			s.board.set_t(Vector2i(x, y), CHARS[row[x]])
	return s


static func mech(s: GameState, kind: String, p: Vector2i) -> Unit:
	return s.add_unit(Unit.make_mech(kind), p)


static func mech_w(s: GameState, kind: String, p: Vector2i, weapon: String, upgrades: Array = []) -> Unit:
	return s.add_unit(Unit.make_mech(kind, [{"id": weapon, "upgrades": upgrades}]), p)


static func enemy(s: GameState, kind: String, p: Vector2i) -> Unit:
	return s.add_unit(Unit.make_enemy(kind), p)


static func types(events: Array[Event]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(e.type)
	return out


static func has(events: Array[Event], type: String, uid: int = -2) -> bool:
	for e in events:
		if e.type == type and (uid == -2 or e.unit_id == uid):
			return true
	return false


static func count(events: Array[Event], type: String) -> int:
	var n := 0
	for e in events:
		if e.type == type:
			n += 1
	return n
