class_name Spawner
extends RefCounted
## Marks spawn points for the next emergence (enemy phase A).


static func mark(state: GameState) -> Array[Event]:
	var ev: Array[Event] = []
	if not state.is_playing() or state.turn >= state.max_turns:
		return ev
	var cap := int(state.mission.get("enemy_cap", Data.rule("enemy_cap")))
	var room := cap - state.enemies().size() - state.spawns.size()
	# Hive Queen larvae first: near the queen.
	for q in state.enemies():
		if q.larvae <= 0:
			continue
		var near: Array[Vector2i] = []
		for p in _free_tiles(state, -1):
			if Rules.manhattan(p, q.pos) <= 2:
				near.append(p)
		for i in q.larvae:
			if room <= 0 or near.is_empty():
				break
			var p: Vector2i = near.pop_at(state.ai_rng.next_int() % near.size())
			_add(state, p, "larva", ev)
			room -= 1
	var count := int(state.mission.get("spawns_per_turn", 2))
	var pool: Dictionary = state.mission.get("enemy_pool", {"beetle": 1})
	var rows := int(state.mission.get("spawn_rows", Data.rule("spawn_rows")))
	var tiles := _free_tiles(state, rows)
	if tiles.is_empty():
		tiles = _free_tiles(state, -1)
	for i in count:
		if room <= 0 or tiles.is_empty():
			break
		var p: Vector2i = tiles.pop_at(state.ai_rng.next_int() % tiles.size())
		_add(state, p, pick_kind(state, pool), ev)
		room -= 1
	return ev


static func _add(state: GameState, p: Vector2i, kind: String, ev: Array[Event]) -> void:
	state.spawns.append({"pos": p, "kind": kind})
	ev.append(Event.new("spawn_marked", -1, p, p, 0, kind))


static func _free_tiles(state: GameState, rows: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in state.board.all_tiles():
		if rows >= 0 and p.y >= rows:
			continue
		if not state.board.is_ground_standable(p) or state.board.is_burning(p):
			continue
		if state.unit_at(p) != null or state.spawn_at(p) >= 0:
			continue
		out.append(p)
	return out


static func pick_kind(state: GameState, pool: Dictionary) -> String:
	var total := 0.0
	var keys := pool.keys()
	keys.sort()
	for k in keys:
		total += float(pool[k])
	var r := state.ai_rng.randf() * total
	for k in keys:
		r -= float(pool[k])
		if r <= 0.0:
			return String(k)
	return String(keys[keys.size() - 1])
