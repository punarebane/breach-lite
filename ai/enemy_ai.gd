class_name EnemyAI
extends RefCounted
## Seeded utility AI. Each enemy scores every (reachable tile x attack option) and
## plans against the board AFTER the previous enemies' moves.


static func plan_turn(state: GameState) -> Array[Event]:
	var ev: Array[Event] = []
	var order := state.enemies()
	order.sort_custom(func(a: Unit, b: Unit) -> bool: return a.id < b.id)
	for u in order:
		if not u.alive or not state.is_playing():
			continue
		var plan := choose(state, u)
		ev.append_array(Resolver.apply(state, plan))
	return ev


static func attack_options(state: GameState, u: Unit, w: Dictionary, from: Vector2i) -> Array:
	var out: Array = []
	for dir in Board.DIRS:
		match String(w["targeting"]):
			"melee", "artillery":
				for d in range(int(w["range_min"]), int(w["range_max"]) + 1):
					if state.board.in_bounds(from + dir * d):
						out.append([dir, d])
			"projectile", "line":
				if state.board.in_bounds(from + dir):
					out.append([dir, 1])
	return out


static func score_hits(state: GameState, u: Unit, tiles: Array[Vector2i]) -> float:
	var cfg := Data.ai()
	var s := 0.0
	for p in tiles:
		var t := state.unit_at(p)
		if t != null and t != u:
			s += float(cfg["hit_mech"]) if t.is_mech() else float(cfg["hit_enemy"])
			continue
		match state.board.get_t(p):
			Board.Terrain.BUILDING:
				s += float(cfg["hit_building"])
			Board.Terrain.OBJECTIVE:
				s += float(cfg["hit_objective"])
	return s


static func choose(state: GameState, u: Unit) -> Action:
	var cfg := Data.ai()
	var w := u.weapon_def()
	var best_score := -INF
	var best := Action.enemy_plan(u.id, u.pos, Vector2i.ZERO, 0)
	var tiles := Rules.reachable(state, u)
	for tile in tiles:
		var tile_bias := 0.0
		if state.spawn_at(tile) >= 0:
			tile_bias += float(cfg["stand_on_spawn"])
		if state.board.is_burning(tile) and not u.burning:
			tile_bias += float(cfg["stand_on_fire"])
		for opt in attack_options(state, u, w, tile):
			var dir: Vector2i = opt[0]
			var dist: int = opt[1]
			var hits := Rules.hit_tiles(state, u, w, tile, dir, dist)
			var sc := score_hits(state, u, hits) + tile_bias + state.ai_rng.randf() * float(cfg["noise"])
			if sc > best_score:
				best_score = sc
				best = Action.enemy_plan(u.id, tile, dir, dist)
	return best
