class_name MissionGen
extends RefCounted
## Seeded mission generator built on hand-authored template constraints
## (data/templates.json) and island terrain flavours (data/islands.json).

const TERRAIN_IDS := {"forest": Board.Terrain.FOREST, "mountain": Board.Terrain.MOUNTAIN,
	"water": Board.Terrain.WATER, "chasm": Board.Terrain.CHASM}


static func templates() -> Array:
	return Data.load_json("templates")["templates"]


## island: index into islands.json, or -1 for the final hive missions (phase 1/2).
## squad: [{"kind": String, "weapons": Array}] (null = default squad).
static func generate(island: int, mission_idx: int, seed_value: int, grid_power: int = -1, squad: Array = [], phase: int = 1) -> GameState:
	var tpl: Dictionary
	var isl: Dictionary
	if island < 0:
		tpl = Data.load_json("templates")["final"][phase - 1]
		isl = {"name": "Hive", "flavour": "hive", "terrain": {"forest": 1, "mountain": 2, "water": 1, "chasm": 2},
			"enemy_pool": tpl["enemy_pool"], "initial_enemies": tpl["initial_enemies"], "spawns_per_turn": tpl["spawns_per_turn"], "enemy_hp_bonus": 0}
	else:
		isl = Data.islands()[island]
		var tpls := templates()
		var rng0 := SeededRng.new(seed_value * 13 + mission_idx)
		tpl = tpls[rng0.next_int() % tpls.size()]
	for attempt in 50:
		var s := _try(tpl, isl, island, mission_idx, seed_value + attempt * 7919, grid_power, squad)
		if s != null:
			return s
	push_error("MissionGen: no valid layout for seed %d" % seed_value)
	return _try(tpl, isl, island, mission_idx, seed_value, grid_power, squad, true)


static func _rows(s: GameState, r: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in s.board.all_tiles():
		if p.y >= int(r[0]) and p.y <= int(r[1]):
			out.append(p)
	return out


static func _try(tpl: Dictionary, isl: Dictionary, island: int, mission_idx: int, seed_value: int, grid_power: int, squad: Array, force: bool = false) -> GameState:
	var rng := SeededRng.new(seed_value)
	var s := GameState.new(int(Data.rule("board_size")))
	s.grid_rng = SeededRng.new(seed_value * 3 + 1)
	s.ai_rng = SeededRng.new(seed_value * 5 + 2)
	# Terrain flavour.
	var cand := _rows(s, tpl["terrain_rows"])
	rng.shuffle(cand)
	var scale := float(tpl.get("terrain_scale", 1.0))
	var terr: Dictionary = isl["terrain"]
	for name in ["mountain", "water", "chasm", "forest"]:
		var n := int(round(float(terr.get(name, 0)) * scale))
		for i in n:
			if cand.is_empty():
				break
			s.board.set_t(cand.pop_back(), TERRAIN_IDS[name])
	# Buildings.
	var bspots: Array[Vector2i] = []
	for p in _rows(s, tpl["building_rows"]):
		if s.board.get_t(p) == Board.Terrain.GROUND:
			bspots.append(p)
	rng.shuffle(bspots)
	var nb := rng.randi_range(int(tpl["buildings"][0]), int(tpl["buildings"][1]))
	var n2 := rng.randi_range(int(tpl["two_hp"][0]), int(tpl["two_hp"][1]))
	var placed: Array[Vector2i] = []
	for i in nb:
		if bspots.is_empty():
			break
		var p: Vector2i = bspots.pop_back()
		s.board.set_t(p, Board.Terrain.BUILDING, 2 if i < n2 else 1)
		placed.append(p)
	if bool(tpl.get("objective", false)) and not placed.is_empty():
		s.board.set_t(placed[placed.size() - 1], Board.Terrain.OBJECTIVE, 1)
	if not force and not _connected(s):
		return null
	# Mechs.
	var sq := squad
	if sq.is_empty():
		for k in Data.run_cfg()["squad"]:
			sq.append({"kind": k, "weapons": []})
	var deploy: Array[Vector2i] = []
	for p in _rows(s, tpl["deploy_rows"]):
		if s.board.is_ground_standable(p):
			deploy.append(p)
	rng.shuffle(deploy)
	for m in sq:
		if deploy.is_empty():
			return null
		s.add_unit(Unit.make_mech(String(m["kind"]), m.get("weapons", [])), deploy.pop_back())
	# Enemies.
	var pool: Dictionary = isl["enemy_pool"]
	var espots: Array[Vector2i] = []
	for p in _rows(s, tpl["enemy_rows"]):
		if s.board.is_ground_standable(p) and s.unit_at(p) == null:
			espots.append(p)
	rng.shuffle(espots)
	if tpl.has("boss"):
		var q := Unit.make_enemy(String(tpl["boss"]))
		var qp := Vector2i(3, 0)
		s.board.set_t(qp, Board.Terrain.GROUND)
		espots.erase(qp)
		s.add_unit(q, qp)
	s.mission = {
		"island": island, "mission_idx": mission_idx, "template": tpl["id"], "island_name": isl["name"],
		"enemy_pool": pool, "spawns_per_turn": int(isl["spawns_per_turn"]),
		"bonus": String(tpl["bonus"][rng.next_int() % tpl["bonus"].size()]),
		"kill_boss": bool(tpl.get("kill_boss", false)), "phase": int(tpl.get("phase", 0)),
		"enemy_hp_bonus": int(isl.get("enemy_hp_bonus", 0)),
	}
	for i in int(isl["initial_enemies"]):
		if espots.is_empty():
			break
		var e := Unit.make_enemy(Spawner.pick_kind(s, pool))
		e.hp += int(isl.get("enemy_hp_bonus", 0))
		e.max_hp = e.hp
		s.add_unit(e, espots.pop_back())
	s.grid_power = grid_power if grid_power > 0 else int(Data.rule("start_grid"))
	s.max_grid = int(Data.rule("max_grid"))
	s.max_turns = int(tpl.get("turns", Data.rule("objective_mission_turns") if bool(tpl.get("objective", false)) else Data.rule("mission_turns")))
	return s


## All ground-standable tiles must form one connected region (no sealed pockets).
static func _connected(s: GameState) -> bool:
	var open: Array[Vector2i] = []
	for p in s.board.all_tiles():
		if s.board.is_ground_standable(p):
			open.append(p)
	if open.is_empty():
		return false
	var seen := {open[0]: true}
	var stack: Array[Vector2i] = [open[0]]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in Board.DIRS:
			var n: Vector2i = c + d
			if s.board.in_bounds(n) and not seen.has(n) and s.board.is_ground_standable(n):
				seen[n] = true
				stack.append(n)
	return seen.size() == open.size()
