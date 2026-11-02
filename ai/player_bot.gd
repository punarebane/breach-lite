class_name PlayerBot
extends RefCounted
## Greedy 1-ply player bot for the balance sim. For each mech it evaluates every
## (move tile x weapon target, or no attack) combo on a copy and scores the result:
## enemies killed/damaged, telegraphed attacks redirected or cancelled, buildings threatened.

const W_KILL := 9.0
const W_ENEMY_DMG := 2.0
const W_GRID := 25.0
const W_MECH_DMG := 4.0
const W_MECH_LOST := 20.0
const W_THREAT_BUILDING := 11.0
const W_THREAT_OBJECTIVE := 6.0
const W_THREAT_MECH := 4.0
const W_THREAT_ENEMY := 3.0
const W_SPAWN_BLOCK_ENEMY := 2.0
const W_SPAWN_BLOCK_MECH := 2.5
const W_BURNING_ENEMY := 1.5


static func evaluate(s: GameState) -> float:
	if s.status == GameState.Status.LOST:
		return -10000.0
	var sc := 0.0
	sc += s.kills * W_KILL
	sc += s.grid_power * W_GRID
	sc -= s.mech_damage * W_MECH_DMG
	for u in s.units:
		if u.is_mech() and not u.alive:
			sc -= W_MECH_LOST
		elif u.is_enemy() and u.alive:
			sc -= u.hp * W_ENEMY_DMG
			if u.burning:
				sc += W_BURNING_ENEMY
	for e in s.enemies():
		if e.tele_order <= 0:
			continue
		var w := e.weapon_def()
		for p in Rules.hit_tiles(s, e, w, e.pos, e.tele_dir, e.tele_dist):
			var t := s.unit_at(p)
			if t != null and t != e:
				if t.is_mech():
					sc -= W_THREAT_MECH * float(w["damage"])
				else:
					sc += W_THREAT_ENEMY * float(w["damage"])
			elif s.board.is_building(p):
				sc -= W_THREAT_BUILDING
				if s.board.get_t(p) == Board.Terrain.OBJECTIVE:
					sc -= W_THREAT_OBJECTIVE
	for sp in s.spawns:
		var t := s.unit_at(sp["pos"])
		if t != null:
			sc += W_SPAWN_BLOCK_ENEMY if t.is_enemy() else -W_SPAWN_BLOCK_MECH
	return sc


## Best (move, attack) plan for one mech. Returns [score, move_to, slot, target] (slot -1 = no attack).
static func best_for(s: GameState, u: Unit) -> Array:
	var best: Array = [-INF, u.pos, -1, Vector2i.ZERO]
	var tiles: Array[Vector2i] = [u.pos] if u.has_moved else Rules.reachable(s, u)
	for tile in tiles:
		var moved := s.duplicate()
		var mu := moved.get_unit(u.id)
		if tile != mu.pos:
			Resolver.apply(moved, Action.move(u.id, tile))
		var base := evaluate(moved)
		if base > best[0]:
			best = [base, tile, -1, Vector2i.ZERO]
		for slot in mu.weapons.size():
			for t in Rules.targets(moved, mu, mu.weapon_def(slot)):
				var c := moved.duplicate()
				Resolver.apply(c, Action.attack(u.id, slot, t))
				var sc := evaluate(c)
				if sc > best[0]:
					best = [sc, tile, slot, t]
	return best


static func play_turn(m: Mission) -> void:
	var remaining: Array[int] = []
	for u in m.state.alive_units(Unit.Team.MECH):
		remaining.append(u.id)
	while not remaining.is_empty() and m.state.is_playing():
		var pick := -1
		var plan: Array = []
		for uid in remaining:
			var u := m.state.get_unit(uid)
			if u == null or not u.alive:
				continue
			var b := best_for(m.state, u)
			if pick < 0 or b[0] > plan[0]:
				pick = uid
				plan = b
		if pick < 0:
			break
		remaining.erase(pick)
		var u := m.state.get_unit(pick)
		if plan[1] != u.pos:
			m.move(pick, plan[1])
		if plan[2] >= 0 and m.state.is_playing():
			m.attack(pick, plan[2], plan[3])
	if m.state.is_playing():
		m.end_turn()


static func play_mission(m: Mission) -> void:
	m.begin_turn()
	var guard := 0
	while m.state.is_playing() and guard < 30:
		guard += 1
		play_turn(m)


## Simple shop policy for the sim.
static func shop(r: RunState) -> void:
	var guard := 0
	while guard < 10:
		guard += 1
		var choice := -1
		var mech := -1
		for i in r.shop_items.size():
			var it: Dictionary = r.shop_items[i]
			if not r.can_buy(it):
				continue
			if it["type"] == "grid" and r.grid_power <= 5:
				choice = i
				break
			if it["type"] == "reactor" and choice < 0:
				choice = i
			if it["type"] == "weapon" and choice < 0:
				for mi in r.squad.size():
					if r.squad[mi]["weapons"].size() < 2:
						choice = i
						mech = mi
						break
		if choice < 0:
			for i in r.shop_items.size():
				if r.shop_items[i]["type"] == "grid" and r.can_buy(r.shop_items[i]):
					choice = i
		if choice < 0 or not r.buy(choice, mech):
			break
	r.leave_shop()


## Plays a full run. Returns the run's history (one report per mission).
static func play_run(seed_value: int) -> RunState:
	var r := RunState.new_run(seed_value)
	var guard := 0
	while r.status == "playing" and guard < 20:
		guard += 1
		if r.shop_pending:
			shop(r)
		var m := Mission.new(r.build_mission())
		play_mission(m)
		r.complete_mission(m.state)
	return r
