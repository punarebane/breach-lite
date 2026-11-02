class_name Rules
extends RefCounted
## Legality and geometry queries shared by the resolver, the UI, the AI and the bots.


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Can unit u end a move on p?
static func can_stand(state: GameState, u: Unit, p: Vector2i) -> bool:
	if not state.board.in_bounds(p) or state.board.is_blocking(p):
		return false
	var other := state.unit_at(p)
	if other != null and other != u:
		return false
	if u.flying:
		return true
	return state.board.is_ground_standable(p)


## Can unit u pass through p while moving?
static func can_pass(state: GameState, u: Unit, p: Vector2i) -> bool:
	if not state.board.in_bounds(p):
		return false
	var other := state.unit_at(p)
	if other != null and other != u and other.team != u.team:
		return false
	if u.flying:
		return true
	return not state.board.is_blocking(p) and state.board.is_ground_standable(p)


## BFS over tiles reachable within u.move (including the start tile).
## Flying units pass over any terrain; nobody passes through opposing units.
static func reachable(state: GameState, u: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = [u.pos]
	if u.burrow:
		for p in state.board.all_tiles():
			if p != u.pos and can_stand(state, u, p):
				out.append(p)
		return out
	var dist := {u.pos: 0}
	var frontier: Array[Vector2i] = [u.pos]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= u.move:
			continue
		for dir in Board.DIRS:
			var n: Vector2i = cur + dir
			if dist.has(n) or not can_pass(state, u, n):
				continue
			dist[n] = d + 1
			frontier.append(n)
			if can_stand(state, u, n):
				out.append(n)
	return out


static func dir_to(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if d.x != 0 and d.y != 0:
		return Vector2i.ZERO
	return Vector2i(signi(d.x), signi(d.y))


## First tile with a unit or blocking terrain, scanning from origin along dir.
## Returns Vector2i(-1,-1) when nothing is hit. `ignore` is not considered (the shooter).
static func projectile_hit(state: GameState, origin: Vector2i, dir: Vector2i, max_range: int, ignore: Unit = null) -> Vector2i:
	for d in range(1, max_range + 1):
		var p := origin + dir * d
		if not state.board.in_bounds(p):
			return Vector2i(-1, -1)
		var u := state.unit_at(p)
		if u != null and u != ignore:
			return p
		if state.board.is_blocking(p):
			return p
	return Vector2i(-1, -1)


## Tiles an attack would hit (directly, not counting pushed-adjacent) if fired from `from`.
static func hit_tiles(state: GameState, u: Unit, w: Dictionary, from: Vector2i, dir: Vector2i, dist: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match String(w["targeting"]):
		"melee":
			for i in int(w["pierce"]):
				var p := from + dir * (dist + i)
				if state.board.in_bounds(p):
					out.append(p)
		"projectile":
			var p := projectile_hit(state, from, dir, int(w["range_max"]), u)
			if p.x >= 0:
				out.append(p)
		"artillery":
			var p := from + dir * dist
			if state.board.in_bounds(p):
				out.append(p)
		"line":
			for d in range(1, int(w["range_max"]) + 1):
				var p := from + dir * d
				if state.board.in_bounds(p):
					out.append(p)
		"self":
			for d4 in Board.DIRS:
				var p := from + d4
				if state.board.in_bounds(p):
					out.append(p)
	return out


## Legal target tiles for a mech weapon from the unit's current position.
static func targets(state: GameState, u: Unit, w: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if w.is_empty():
		return out
	match String(w["targeting"]):
		"melee", "artillery":
			for dir in Board.DIRS:
				for d in range(int(w["range_min"]), int(w["range_max"]) + 1):
					var p: Vector2i = u.pos + dir * d
					if state.board.in_bounds(p):
						out.append(p)
		"projectile", "line":
			for dir in Board.DIRS:
				if state.board.in_bounds(u.pos + dir):
					out.append(u.pos + dir)
		"self":
			out.append(u.pos)
		"swap":
			for o in state.alive_units():
				if o != u and not o.immovable and manhattan(o.pos, u.pos) <= int(w["range_max"]):
					out.append(o.pos)
	return out


## Map a clicked tile to the canonical target tile (projectiles/lines aim by direction).
static func canonical_target(u: Unit, w: Dictionary, clicked: Vector2i) -> Vector2i:
	var t := String(w.get("targeting", ""))
	if t == "projectile" or t == "line":
		var dir := dir_to(u.pos, clicked)
		if dir != Vector2i.ZERO:
			return u.pos + dir
	return clicked


static func is_legal(state: GameState, a: Action) -> bool:
	if not state.is_playing():
		return false
	var u := state.get_unit(a.unit_id)
	match a.kind:
		Action.Kind.MOVE:
			if u == null or not u.alive or not u.is_mech() or u.has_moved or u.has_acted:
				return false
			return a.target in reachable(state, u)
		Action.Kind.ATTACK:
			if u == null or not u.alive or not u.is_mech() or u.has_acted:
				return false
			var w := u.weapon_def(a.slot)
			return a.target in targets(state, u, w)
		Action.Kind.ENEMY_PLAN:
			return u != null and u.alive and u.is_enemy()
		Action.Kind.END_TURN:
			return true
	return false


## All legal player actions (moves and attacks) in the current state.
static func legal_player_actions(state: GameState) -> Array[Action]:
	var out: Array[Action] = []
	for u in state.alive_units(Unit.Team.MECH):
		if u.has_acted:
			continue
		if not u.has_moved:
			for p in reachable(state, u):
				if p != u.pos:
					out.append(Action.move(u.id, p))
		for slot in u.weapons.size():
			for t in targets(state, u, u.weapon_def(slot)):
				out.append(Action.attack(u.id, slot, t))
	return out
