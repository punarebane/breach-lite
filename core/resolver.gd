class_name Resolver
extends RefCounted
## The only code that mutates a GameState during play. Every rule lives here and
## reports what happened as Events. apply() on a duplicate() is the attack preview.


static func apply(state: GameState, a: Action) -> Array[Event]:
	var ev: Array[Event] = []
	if not Rules.is_legal(state, a):
		ev.append(Event.new("illegal", a.unit_id, a.target))
		return ev
	match a.kind:
		Action.Kind.MOVE:
			_do_move(state, a, ev)
		Action.Kind.ATTACK:
			_do_attack(state, a, ev)
		Action.Kind.ENEMY_PLAN:
			_do_enemy_plan(state, a, ev)
		Action.Kind.END_TURN:
			_do_end_turn(state, ev)
	_check_status(state, ev)
	return ev


# --- player / enemy commands -------------------------------------------------

static func _do_move(state: GameState, a: Action, ev: Array[Event]) -> void:
	var u := state.get_unit(a.unit_id)
	var from := u.pos
	u.pos = a.target
	u.has_moved = true
	ev.append(Event.new("moved", u.id, from, a.target))
	_on_enter(state, u, ev)


static func _do_attack(state: GameState, a: Action, ev: Array[Event]) -> void:
	var u := state.get_unit(a.unit_id)
	var w := u.weapon_def(a.slot)
	u.has_acted = true
	u.has_moved = true
	var dir := Rules.dir_to(u.pos, a.target)
	var dist := Rules.manhattan(u.pos, a.target)
	ev.append(Event.new("attack", u.id, u.pos, a.target, 0, String(w["id"])))
	fire_weapon(state, u, w, dir, dist, a.target, ev)


static func _do_enemy_plan(state: GameState, a: Action, ev: Array[Event]) -> void:
	var u := state.get_unit(a.unit_id)
	if a.target != u.pos and Rules.can_stand(state, u, a.target):
		var from := u.pos
		u.pos = a.target
		ev.append(Event.new("moved", u.id, from, a.target))
		_on_enter(state, u, ev)
	if not u.alive:
		return
	u.tele_dir = a.dir
	u.tele_dist = a.dist
	if a.dir != Vector2i.ZERO:
		u.tele_order = state.next_order
		state.next_order += 1
		ev.append(Event.new("telegraph", u.id, u.pos, u.pos + a.dir * maxi(a.dist, 1), u.tele_order))
	else:
		u.tele_order = 0


static func _do_end_turn(state: GameState, ev: Array[Event]) -> void:
	ev.append(Event.new("phase_b", -1, Vector2i(-1, -1), Vector2i(-1, -1), state.turn))
	# 1. Fire.
	for u in state.alive_units():
		if u.burning and u.alive:
			ev.append(Event.new("burn", u.id, u.pos))
			damage_unit(state, u, int(Data.rule("burn_damage")), ev)
			if _over(state):
				return
	# 2. Telegraphed attacks, in order. They hit whatever is on the tile NOW.
	var attackers: Array[Unit] = []
	for u in state.enemies():
		if u.tele_order > 0:
			attackers.append(u)
	attackers.sort_custom(func(x: Unit, y: Unit) -> bool: return x.tele_order < y.tele_order)
	for u in attackers:
		if not u.alive or u.tele_order == 0:
			continue
		var w := u.weapon_def()
		var target := u.pos + u.tele_dir * maxi(u.tele_dist, 1)
		ev.append(Event.new("attack", u.id, u.pos, target, u.tele_order, String(w["id"])))
		var dir := u.tele_dir
		var dist := u.tele_dist
		u.clear_telegraph()
		fire_weapon(state, u, w, dir, dist, target, ev)
		_check_status(state, ev)
		if _over(state):
			return
	for u in state.enemies():
		u.clear_telegraph()
	# 3. Spawns emerge.
	var spawns := state.spawns.duplicate(true)
	state.spawns.clear()
	for s in spawns:
		var p: Vector2i = s["pos"]
		var blocker := state.unit_at(p)
		if blocker != null:
			ev.append(Event.new("spawn_blocked", blocker.id, p, p, 0, String(s["kind"])))
			damage_unit(state, blocker, int(Data.rule("spawn_block_damage")), ev)
			_check_status(state, ev)
			if _over(state):
				return
			continue
		var e := state.add_unit(Unit.make_enemy(String(s["kind"])), p)
		ev.append(Event.new("spawned", e.id, p, p, 0, e.kind))
		_on_enter(state, e, ev)
	# 4. Next turn.
	for u in state.units:
		u.has_moved = false
		u.has_acted = false
	state.next_order = 1
	state.turn += 1
	ev.append(Event.new("turn_start", -1, Vector2i(-1, -1), Vector2i(-1, -1), state.turn))
	_check_status(state, ev)
	if state.is_playing() and state.turn > state.max_turns:
		state.status = GameState.Status.WON
		ev.append(Event.new("mission_won"))


# --- weapons -----------------------------------------------------------------

static func fire_weapon(state: GameState, u: Unit, w: Dictionary, dir: Vector2i, dist: int, target: Vector2i, ev: Array[Event]) -> void:
	var targeting := String(w["targeting"])
	if targeting == "swap":
		_swap(state, u, target, w, ev)
		return
	if targeting == "self":
		for d4 in Board.DIRS:
			_hit(state, u.pos + d4, d4, w, ev, false)
		return
	var tiles := Rules.hit_tiles(state, u, w, u.pos, dir, dist)
	if tiles.size() == 1:
		_hit(state, tiles[0], dir, w, ev, true)
		return
	# Multi-tile attacks (spear, queen breath): damage everything first, then
	# push from the far end back, so the near victim is not shoved into the far one.
	var victims: Array[Unit] = []
	for p in tiles:
		var victim := state.unit_at(p)
		victims.append(victim)
		ev.append(Event.new("hit", victim.id if victim else -1, p, p, int(w["damage"])))
		damage_tile(state, p, int(w["damage"]), ev, bool(w["ignite"]))
	for i in range(tiles.size() - 1, -1, -1):
		var v := victims[i]
		if v != null and v.alive and v.pos == tiles[i]:
			match String(w["push"]):
				"away":
					push_unit(state, v, dir, ev)
				"toward":
					push_unit(state, v, -dir, ev)


## Resolve one hit: damage the tile, push its occupant, then the adjacent ring.
static func _hit(state: GameState, p: Vector2i, dir: Vector2i, w: Dictionary, ev: Array[Event], allow_adjacent: bool) -> void:
	if not state.board.in_bounds(p):
		return
	var victim := state.unit_at(p)
	ev.append(Event.new("hit", victim.id if victim else -1, p, p, int(w["damage"])))
	damage_tile(state, p, int(w["damage"]), ev, bool(w["ignite"]))
	if victim != null and victim.alive and victim.pos == p:
		match String(w["push"]):
			"away":
				push_unit(state, victim, dir, ev)
			"toward":
				push_unit(state, victim, -dir, ev)
	if allow_adjacent and bool(w["push_adjacent"]):
		for d4 in Board.DIRS:
			var q := p + d4
			if not state.board.in_bounds(q):
				continue
			var adj := state.unit_at(q)
			if int(w["adjacent_damage"]) > 0:
				damage_tile(state, q, int(w["adjacent_damage"]), ev, false)
			if adj != null and adj.alive and adj.pos == q:
				push_unit(state, adj, d4, ev)


static func _swap(state: GameState, u: Unit, target: Vector2i, w: Dictionary, ev: Array[Event]) -> void:
	var other := state.unit_at(target)
	if other == null or other == u or other.immovable:
		return
	var a := u.pos
	var b := other.pos
	u.pos = b
	other.pos = a
	ev.append(Event.new("swapped", u.id, a, b, other.id))
	_on_enter(state, other, ev)
	_on_enter(state, u, ev)
	if int(w["damage"]) > 0 and other.alive:
		damage_tile(state, other.pos, int(w["damage"]), ev, bool(w["ignite"]))


# --- primitives --------------------------------------------------------------

## Push 1 tile. Blocked by a unit or blocking terrain = bump (both take 1).
## Pushing off the board does nothing.
static func push_unit(state: GameState, u: Unit, dir: Vector2i, ev: Array[Event]) -> void:
	if not u.alive or u.immovable or dir == Vector2i.ZERO:
		return
	var dest := u.pos + dir
	if not state.board.in_bounds(dest):
		return
	var bump := int(Data.rule("bump_damage"))
	var other := state.unit_at(dest)
	if other != null:
		ev.append(Event.new("bumped", u.id, u.pos, dest, other.id))
		damage_unit(state, u, bump, ev)
		damage_unit(state, other, bump, ev)
		return
	if state.board.is_blocking(dest):
		ev.append(Event.new("bumped", u.id, u.pos, dest, -1))
		damage_unit(state, u, bump, ev)
		damage_terrain(state, dest, ev)
		return
	var from := u.pos
	u.pos = dest
	ev.append(Event.new("pushed", u.id, from, dest))
	_on_enter(state, u, ev)


## Terrain consequences of a unit arriving on its tile.
static func _on_enter(state: GameState, u: Unit, ev: Array[Event]) -> void:
	if not u.alive:
		return
	var t := state.board.get_t(u.pos)
	if not u.flying:
		if t == Board.Terrain.WATER:
			ev.append(Event.new("drowned", u.id, u.pos))
			kill_unit(state, u, ev)
			return
		if t == Board.Terrain.CHASM:
			ev.append(Event.new("fell", u.id, u.pos))
			kill_unit(state, u, ev)
			return
	if state.board.is_burning(u.pos) and not u.burning:
		u.burning = true
		ev.append(Event.new("caught_fire", u.id, u.pos))


static func damage_tile(state: GameState, p: Vector2i, amount: int, ev: Array[Event], ignite: bool = false) -> void:
	if not state.board.in_bounds(p):
		return
	var u := state.unit_at(p)
	if u != null and amount > 0:
		damage_unit(state, u, amount, ev)
	if amount > 0:
		damage_terrain(state, p, ev)
	if ignite:
		set_fire(state, p, ev)


## A hit on terrain: buildings lose grid, mountains crumble, forests ignite.
static func damage_terrain(state: GameState, p: Vector2i, ev: Array[Event]) -> void:
	var b := state.board
	match b.get_t(p):
		Board.Terrain.BUILDING, Board.Terrain.OBJECTIVE:
			if state.grid_rng.randf() < float(Data.rule("grid_defence")):
				ev.append(Event.new("grid_resisted", -1, p))
				return
			var is_obj := b.get_t(p) == Board.Terrain.OBJECTIVE
			b.hp[b.idx(p)] -= 1
			state.grid_power = maxi(0, state.grid_power - 1)
			ev.append(Event.new("grid_lost", -1, p, p, 1))
			if b.get_hp(p) <= 0:
				ev.append(Event.new("building_destroyed", -1, p, p, 0, "objective" if is_obj else "building"))
				if is_obj:
					state.objective_lost = true
				b.set_t(p, Board.Terrain.GROUND)
				b.rubble[b.idx(p)] = 1
		Board.Terrain.MOUNTAIN:
			b.hp[b.idx(p)] -= 1
			ev.append(Event.new("mountain_damaged", -1, p, p, b.get_hp(p)))
			if b.get_hp(p) <= 0:
				ev.append(Event.new("mountain_destroyed", -1, p))
				b.set_t(p, Board.Terrain.GROUND)
				b.rubble[b.idx(p)] = 1
		Board.Terrain.FOREST:
			set_fire(state, p, ev)


static func set_fire(state: GameState, p: Vector2i, ev: Array[Event]) -> void:
	var b := state.board
	var t := b.get_t(p)
	if (t == Board.Terrain.FOREST or t == Board.Terrain.GROUND) and not b.is_burning(p):
		b.fire[b.idx(p)] = 1
		ev.append(Event.new("fire_started", -1, p))
	var u := state.unit_at(p)
	if u != null and u.alive and not u.burning and t != Board.Terrain.WATER:
		u.burning = true
		ev.append(Event.new("caught_fire", u.id, p))


static func damage_unit(state: GameState, u: Unit, amount: int, ev: Array[Event]) -> void:
	if amount <= 0 or not u.alive:
		return
	var dealt := mini(amount, u.hp)
	u.hp -= dealt
	if u.is_mech():
		state.mech_damage += dealt
	ev.append(Event.new("damaged", u.id, u.pos, u.pos, dealt))
	if u.hp <= 0:
		kill_unit(state, u, ev)


static func kill_unit(state: GameState, u: Unit, ev: Array[Event]) -> void:
	if not u.alive:
		return
	u.alive = false
	u.hp = 0
	u.burning = false
	u.clear_telegraph()
	if u.is_mech():
		ev.append(Event.new("disabled", u.id, u.pos))
		return
	state.kills += 1
	ev.append(Event.new("destroyed", u.id, u.pos, u.pos, 0, u.kind))
	if u.explode > 0:
		ev.append(Event.new("exploded", u.id, u.pos, u.pos, u.explode))
		for d4 in Board.DIRS:
			damage_tile(state, u.pos + d4, u.explode, ev, false)


# --- status ------------------------------------------------------------------

static func _over(state: GameState) -> bool:
	return not state.is_playing()


static func _check_status(state: GameState, ev: Array[Event]) -> void:
	if not state.is_playing():
		return
	if state.grid_power <= 0:
		state.status = GameState.Status.LOST
		state.lost_reason = "grid"
		ev.append(Event.new("mission_lost", -1, Vector2i(-1, -1), Vector2i(-1, -1), 0, "grid"))
	elif state.alive_units(Unit.Team.MECH).is_empty():
		state.status = GameState.Status.LOST
		state.lost_reason = "mechs"
		ev.append(Event.new("mission_lost", -1, Vector2i(-1, -1), Vector2i(-1, -1), 0, "mechs"))
