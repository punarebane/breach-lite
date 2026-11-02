class_name Fixture
extends RefCounted
## Builds a GameState from a JSON fixture (data/fixtures/*.json) or a Dictionary.
## Map legend: . ground  M mountain  ~ water  _ chasm  F forest  B building  b 2-HP building  O objective  * burning forest

const CHARS := {".": Board.Terrain.GROUND, "M": Board.Terrain.MOUNTAIN, "~": Board.Terrain.WATER,
	"_": Board.Terrain.CHASM, "F": Board.Terrain.FOREST, "*": Board.Terrain.FOREST, "B": Board.Terrain.BUILDING,
	"b": Board.Terrain.BUILDING, "O": Board.Terrain.OBJECTIVE}


static func load_file(name: String) -> GameState:
	var d: Variant = Data.load_json("fixtures/" + name)
	return from_dict(d)


static func _v(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new(int(Data.rule("board_size")))
	var seed_value := int(d.get("seed", 1))
	s.grid_rng = SeededRng.new(seed_value)
	s.ai_rng = SeededRng.new(seed_value * 31 + 7)
	var rows: Array = d.get("map", [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			var p := Vector2i(x, y)
			s.board.set_t(p, CHARS.get(c, Board.Terrain.GROUND), 2 if c == "b" else -1)
			if c == "*":
				s.board.fire[s.board.idx(p)] = 1
	for m in d.get("mechs", []):
		var u := Unit.make_mech(String(m["kind"]), m.get("weapons", []))
		s.add_unit(u, _v(m["pos"]))
		if m.has("hp"):
			u.hp = int(m["hp"])
	for e in d.get("enemies", []):
		var u := s.add_unit(Unit.make_enemy(String(e["kind"])), _v(e["pos"]))
		if e.has("hp"):
			u.hp = int(e["hp"])
	for sp in d.get("spawns", []):
		s.spawns.append({"pos": _v(sp["pos"]), "kind": String(sp["kind"])})
	s.grid_power = int(d.get("grid", Data.rule("start_grid")))
	s.max_grid = int(Data.rule("max_grid"))
	s.max_turns = int(d.get("turns", Data.rule("mission_turns")))
	s.mission = d.get("mission", {"enemy_pool": {"beetle": 2, "spitter": 1}, "spawns_per_turn": 2})
	return s
