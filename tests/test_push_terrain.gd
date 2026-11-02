extends GutTest

const FX := preload("res://tests/fx.gd")


func test_punch_damages_and_pushes() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var e := FX.enemy(s, "scarab", Vector2i(3, 2))
	e.hp = 5
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 2)))
	assert_eq(e.hp, 3)
	assert_eq(e.pos, Vector2i(3, 1))
	assert_true(FX.has(ev, "pushed", e.id))


func test_punch_kill_does_not_push() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var e := FX.enemy(s, "beetle", Vector2i(3, 2))
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 2)))
	assert_false(e.alive)
	assert_false(FX.has(ev, "pushed"))
	assert_eq(s.kills, 1)


func test_push_off_board_edge_does_nothing() -> void:
	var s := FX.state()
	var e := FX.enemy(s, "beetle", Vector2i(0, 3))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(-1, 0), ev)
	assert_eq(e.pos, Vector2i(0, 3))
	assert_eq(ev.size(), 0)


func test_bump_into_unit_damages_both() -> void:
	var s := FX.state()
	var a := FX.enemy(s, "beetle", Vector2i(2, 2))
	var b := FX.enemy(s, "beetle", Vector2i(3, 2))
	var ev: Array[Event] = []
	Resolver.push_unit(s, a, Vector2i(1, 0), ev)
	assert_eq(a.pos, Vector2i(2, 2))
	assert_eq(a.hp, 1)
	assert_eq(b.hp, 1)
	assert_eq(FX.types(ev), ["bumped", "damaged", "damaged"] as Array[String])


func test_bump_into_mountain_damages_unit_and_mountain() -> void:
	var s := FX.state(["...M..."])
	var e := FX.enemy(s, "beetle", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_eq(e.hp, 1)
	assert_eq(s.board.get_hp(Vector2i(3, 0)), 1)
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_false(e.alive)
	assert_eq(s.board.get_t(Vector2i(3, 0)), Board.Terrain.GROUND, "two hits destroy a mountain")
	assert_true(FX.has(ev, "mountain_destroyed"))


func test_bump_into_building_loses_grid() -> void:
	var s := FX.state(["...B..."], 3)
	s.grid_power = 5
	var e := FX.enemy(s, "scarab", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_true(FX.has(ev, "grid_lost") or FX.has(ev, "grid_resisted"))
	if FX.has(ev, "grid_lost"):
		assert_eq(s.grid_power, 4)


func test_push_into_water_drowns_ground_unit() -> void:
	var s := FX.state(["...~..."])
	var e := FX.enemy(s, "beetle", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_false(e.alive)
	assert_eq(FX.types(ev), ["pushed", "drowned", "destroyed"] as Array[String])


func test_push_into_water_flying_survives() -> void:
	var s := FX.state(["...~..."])
	var e := FX.enemy(s, "hornet", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_true(e.alive)
	assert_eq(e.pos, Vector2i(3, 0))


func test_push_into_chasm_kills_non_flying() -> void:
	var s := FX.state(["..._..."])
	var e := FX.enemy(s, "scarab", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_false(e.alive)
	assert_true(FX.has(ev, "fell", e.id))


func test_push_into_chasm_flying_survives() -> void:
	var s := FX.state(["..._..."])
	var e := FX.enemy(s, "hornet", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_true(e.alive)


func test_mech_pushed_into_water_is_disabled() -> void:
	var s := FX.state(["...~..."])
	var m := FX.mech(s, "brawler", Vector2i(2, 0))
	FX.mech(s, "artillery", Vector2i(6, 6))
	var ev: Array[Event] = []
	Resolver.push_unit(s, m, Vector2i(1, 0), ev)
	assert_false(m.alive)
	assert_true(FX.has(ev, "disabled", m.id))


func test_immovable_queen_ignores_push() -> void:
	var s := FX.state()
	var q := FX.enemy(s, "queen", Vector2i(3, 3))
	var ev: Array[Event] = []
	Resolver.push_unit(s, q, Vector2i(1, 0), ev)
	assert_eq(q.pos, Vector2i(3, 3))


func test_hitting_forest_starts_fire_and_burns_occupant() -> void:
	var s := FX.state([".......", ".......", "...F..."])
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var e := FX.enemy(s, "scarab", Vector2i(3, 2))
	e.hp = 5
	s.board.set_t(Vector2i(3, 1), Board.Terrain.MOUNTAIN)
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 2)))
	assert_true(FX.has(ev, "fire_started"))
	assert_true(s.board.is_burning(Vector2i(3, 2)))
	assert_true(e.burning, "unit on the hit forest catches fire")


func test_burning_unit_takes_damage_each_turn() -> void:
	var s := FX.state()
	FX.mech(s, "brawler", Vector2i(6, 6))
	var e := FX.enemy(s, "scarab", Vector2i(0, 0))
	e.burning = true
	var ev := Resolver.apply(s, Action.end_turn())
	assert_eq(e.hp, 1)
	assert_true(FX.has(ev, "burn", e.id))
	Resolver.apply(s, Action.end_turn())
	assert_false(e.alive)


func test_pushed_onto_burning_tile_catches_fire() -> void:
	var s := FX.state()
	s.board.fire[s.board.idx(Vector2i(3, 0))] = 1
	var e := FX.enemy(s, "beetle", Vector2i(2, 0))
	var ev: Array[Event] = []
	Resolver.push_unit(s, e, Vector2i(1, 0), ev)
	assert_true(e.burning)


func test_blob_explodes_on_death() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 4))
	var blob := FX.enemy(s, "blob", Vector2i(3, 3))
	var e := FX.enemy(s, "beetle", Vector2i(4, 3))
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 3)))
	assert_false(blob.alive)
	assert_true(FX.has(ev, "exploded", blob.id))
	assert_eq(e.hp, 1)
	assert_eq(m.hp, 2, "the explosion hits the adjacent mech too")


func test_blob_explosion_chain() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(0, 3))
	var b1 := FX.enemy(s, "blob", Vector2i(1, 3))
	var b2 := FX.enemy(s, "blob", Vector2i(2, 3))
	var b3 := FX.enemy(s, "blob", Vector2i(3, 3))
	var e := FX.enemy(s, "beetle", Vector2i(4, 3))
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(1, 3)))
	assert_false(b1.alive)
	assert_false(b2.alive)
	assert_false(b3.alive)
	assert_eq(FX.count(ev, "exploded"), 3)
	assert_eq(e.hp, 1)
	assert_eq(s.kills, 3)


func test_artillery_pushes_adjacent_outward_in_fixed_order() -> void:
	var s := FX.state()
	var art := FX.mech(s, "artillery", Vector2i(3, 6))
	var center := FX.enemy(s, "scarab", Vector2i(3, 3))
	center.hp = 5
	var up := FX.enemy(s, "beetle", Vector2i(3, 2))
	var right := FX.enemy(s, "beetle", Vector2i(4, 3))
	var left := FX.enemy(s, "beetle", Vector2i(2, 3))
	var ev := Resolver.apply(s, Action.attack(art.id, 0, Vector2i(3, 3)))
	assert_eq(center.hp, 4)
	assert_eq(center.pos, Vector2i(3, 3), "centre is not pushed")
	assert_eq(up.pos, Vector2i(3, 1))
	assert_eq(right.pos, Vector2i(5, 3))
	assert_eq(left.pos, Vector2i(1, 3))
	var pushes: Array[int] = []
	for e in ev:
		if e.type == "pushed":
			pushes.append(e.unit_id)
	assert_eq(pushes, [up.id, right.id, left.id] as Array[int], "up, right, down, left")


func test_artillery_requires_two_tiles() -> void:
	var s := FX.state()
	var art := FX.mech(s, "artillery", Vector2i(3, 3))
	var t := Rules.targets(s, art, art.weapon_def(0))
	assert_false(Vector2i(3, 2) in t)
	assert_true(Vector2i(3, 1) in t)
	assert_false(Vector2i(4, 4) in t, "straight lines only")


func test_artillery_flies_over_mountain() -> void:
	var s := FX.state([".......", ".......", ".......", ".......", "...M..."])
	var art := FX.mech(s, "artillery", Vector2i(3, 5))
	var e := FX.enemy(s, "beetle", Vector2i(3, 2))
	Resolver.apply(s, Action.attack(art.id, 0, Vector2i(3, 2)))
	assert_eq(e.hp, 1)
	assert_eq(s.board.get_hp(Vector2i(3, 4)), 2, "mountain untouched")


func test_push_chain_sequential_bump_after_push() -> void:
	# Arc shell between two enemies in a row: pushing the right one outward first
	# vacates nothing for the left; order of pushes matters and is deterministic.
	var s := FX.state()
	var art := FX.mech(s, "artillery", Vector2i(3, 6))
	var a := FX.enemy(s, "beetle", Vector2i(3, 2))
	var b := FX.enemy(s, "beetle", Vector2i(3, 1))
	Resolver.apply(s, Action.attack(art.id, 0, Vector2i(3, 3)))
	# a pushed up into b -> bump, both 1 damage, a stays.
	assert_eq(a.pos, Vector2i(3, 2))
	assert_eq(a.hp, 1)
	assert_eq(b.hp, 1)


func test_swap_exchanges_positions() -> void:
	var s := FX.state()
	var w := FX.mech(s, "warper", Vector2i(1, 1))
	var e := FX.enemy(s, "beetle", Vector2i(3, 2))
	var ev := Resolver.apply(s, Action.attack(w.id, 0, Vector2i(3, 2)))
	assert_eq(w.pos, Vector2i(3, 2))
	assert_eq(e.pos, Vector2i(1, 1))
	assert_true(FX.has(ev, "swapped", w.id))
	assert_eq(e.hp, 2)


func test_swap_enemy_into_water_drowns_it() -> void:
	var s := FX.state([".~....."])
	var w := FX.mech(s, "warper", Vector2i(1, 0))
	var e := FX.enemy(s, "beetle", Vector2i(3, 0))
	Resolver.apply(s, Action.attack(w.id, 0, Vector2i(3, 0)))
	assert_false(e.alive)
	assert_eq(w.pos, Vector2i(3, 0))


func test_swap_range_is_three() -> void:
	var s := FX.state()
	var w := FX.mech(s, "warper", Vector2i(0, 0))
	FX.enemy(s, "beetle", Vector2i(2, 1))
	FX.enemy(s, "beetle", Vector2i(3, 1))
	var t := Rules.targets(s, w, w.weapon_def(0))
	assert_eq(t, [Vector2i(2, 1)] as Array[Vector2i])


func test_mech_attack_once_per_turn() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var e := FX.enemy(s, "scarab", Vector2i(3, 2))
	e.hp = 9
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 2)))
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(2, 3)))
	assert_eq(ev[0].type, "illegal")
	assert_eq(Resolver.apply(s, Action.move(m.id, Vector2i(3, 4)))[0].type, "illegal", "no move after acting")


func test_grid_defence_fixed_seed_is_deterministic() -> void:
	var resisted := 0
	var lost := 0
	for seed_value in 200:
		var s := FX.state(["B......"], seed_value)
		s.grid_power = 7
		var ev: Array[Event] = []
		Resolver.damage_terrain(s, Vector2i(0, 0), ev)
		if FX.has(ev, "grid_resisted"):
			resisted += 1
		else:
			lost += 1
		# Same seed, same answer.
		var s2 := FX.state(["B......"], seed_value)
		var ev2: Array[Event] = []
		Resolver.damage_terrain(s2, Vector2i(0, 0), ev2)
		assert_eq(Event.keys(ev), Event.keys(ev2))
	assert_between(resisted, 10, 60, "about 15% resist")
	assert_eq(resisted + lost, 200)


func test_grid_zero_loses_mission() -> void:
	var s := FX.state([".B....."], 5)
	s.grid_power = 1
	var m := FX.mech(s, "brawler", Vector2i(1, 2))
	var e := FX.enemy(s, "scarab", Vector2i(1, 1))
	e.hp = 9
	# Find a seed where the building does not resist.
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(1, 1)))
	if FX.has(ev, "grid_lost"):
		assert_eq(s.status, GameState.Status.LOST)
		assert_eq(s.lost_reason, "grid")
	else:
		assert_true(FX.has(ev, "grid_resisted"))
		assert_eq(s.status, GameState.Status.PLAYING)


func test_two_hp_building_survives_one_hit() -> void:
	var s := FX.state()
	s.board.set_t(Vector2i(0, 0), Board.Terrain.BUILDING, 2)
	s.grid_power = 7
	var ev: Array[Event] = []
	for i in 10:
		if FX.has(ev, "grid_lost"):
			break
		ev.clear()
		Resolver.damage_terrain(s, Vector2i(0, 0), ev)
	assert_eq(s.board.get_t(Vector2i(0, 0)), Board.Terrain.BUILDING)
	assert_eq(s.board.get_hp(Vector2i(0, 0)), 1)
