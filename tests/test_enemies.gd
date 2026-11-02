extends GutTest

const FX := preload("res://tests/fx.gd")


func _plan(s: GameState, u: Unit) -> Action:
	return EnemyAI.choose(s, u)


func test_ai_attacks_building_when_possible() -> void:
	var s := FX.state([".......", ".......", "...B..."])
	var e := FX.enemy(s, "beetle", Vector2i(3, 5))
	var a := _plan(s, e)
	Resolver.apply(s, a)
	var tiles := Rules.hit_tiles(s, e, e.weapon_def(), e.pos, e.tele_dir, e.tele_dist)
	assert_eq(tiles, [Vector2i(3, 2)] as Array[Vector2i])


func test_ai_avoids_hitting_other_enemies() -> void:
	for seed_value in 20:
		var s := FX.state([], seed_value)
		var e := FX.enemy(s, "beetle", Vector2i(3, 3))
		e.move = 0
		FX.enemy(s, "scarab", Vector2i(3, 2))
		Resolver.apply(s, _plan(s, e))
		assert_ne(e.tele_dir, Vector2i(0, -1), "seed %d hit its friend" % seed_value)


func test_ai_prefers_objective_over_mech() -> void:
	for seed_value in 10:
		var s := FX.state([".......", "...O..."], seed_value)
		var e := FX.enemy(s, "beetle", Vector2i(3, 2))
		e.move = 0
		FX.mech(s, "brawler", Vector2i(3, 3))
		Resolver.apply(s, _plan(s, e))
		assert_eq(e.tele_dir, Vector2i(0, -1))


func test_ai_plans_against_previous_moves() -> void:
	# Only (3,1) is adjacent to the building and standable; the first enemy takes it.
	var s := FX.state(["..MBM..", "M.....M", "MMM.MMM"])
	var a := FX.enemy(s, "beetle", Vector2i(1, 1))
	var b := FX.enemy(s, "beetle", Vector2i(5, 1))
	FX.mech(s, "brawler", Vector2i(6, 6))
	Mission.new(s).begin_turn()
	assert_eq(a.pos, Vector2i(3, 1))
	assert_ne(b.pos, Vector2i(3, 1))
	assert_eq(a.tele_order, 1)
	assert_eq(b.tele_order, 2)


func test_ai_is_deterministic_for_seed() -> void:
	var s1 := Fixture.load_file("demo")
	var s2 := Fixture.load_file("demo")
	Mission.new(s1).begin_turn()
	Mission.new(s2).begin_turn()
	assert_eq(s1.fingerprint(), s2.fingerprint())


func test_scarab_artillery_two_damage_over_mountain() -> void:
	var s := FX.state([".......", ".......", "...M..."])
	var sc := FX.enemy(s, "scarab", Vector2i(3, 3))
	var m := FX.mech(s, "brawler", Vector2i(3, 1))
	Resolver.apply(s, Action.enemy_plan(sc.id, sc.pos, Vector2i(0, -1), 2))
	Resolver.apply(s, Action.end_turn())
	assert_eq(m.hp, 1)


func test_spitter_hits_first_thing_now() -> void:
	var s := FX.state()
	var sp := FX.enemy(s, "spitter", Vector2i(0, 3))
	var far := FX.mech(s, "artillery", Vector2i(5, 3))
	Resolver.apply(s, Action.enemy_plan(sp.id, sp.pos, Vector2i(1, 0), 1))
	var near := FX.mech(s, "brawler", Vector2i(2, 3))
	Resolver.apply(s, Action.end_turn())
	assert_eq(near.hp, 2, "the mech that stepped in takes the hit")
	assert_eq(far.hp, 3)


func test_attack_hits_whatever_is_on_tile_now() -> void:
	var s := FX.state([".......", ".B....."])
	var m := FX.mech(s, "brawler", Vector2i(0, 2))
	var e := FX.enemy(s, "beetle", Vector2i(1, 2))
	e.hp = 5
	Resolver.apply(s, Action.enemy_plan(e.id, e.pos, Vector2i(0, -1), 1))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(1, 2)))
	assert_eq(e.pos, Vector2i(2, 2))
	var grid := s.grid_power
	Resolver.apply(s, Action.end_turn())
	assert_eq(s.grid_power, grid, "attack moved with the beetle; it hits empty (2,1)")


func test_pushed_enemy_redirects_into_another_enemy() -> void:
	var s := FX.state()
	var a := FX.enemy(s, "scarab", Vector2i(2, 2))
	a.hp = 5
	var victim := FX.enemy(s, "scarab", Vector2i(3, 0))
	var m := FX.mech(s, "brawler", Vector2i(1, 2))
	Resolver.apply(s, Action.enemy_plan(a.id, a.pos, Vector2i(0, -1), 2))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(2, 2)))
	assert_eq(a.pos, Vector2i(3, 2))
	Resolver.apply(s, Action.end_turn())
	assert_false(victim.alive, "scarab shell now lands on its friend")


func test_resolution_order_kill_cancels_later_attack() -> void:
	var s := FX.state([".......", ".......", ".......", ".......", ".....B."])
	var m := FX.mech(s, "brawler", Vector2i(0, 6))
	var sc := FX.enemy(s, "scarab", Vector2i(3, 0))
	var blob := FX.enemy(s, "blob", Vector2i(3, 3))
	var beetle := FX.enemy(s, "beetle", Vector2i(4, 3))
	beetle.hp = 1
	Resolver.apply(s, Action.enemy_plan(sc.id, sc.pos, Vector2i(0, 1), 3))
	Resolver.apply(s, Action.enemy_plan(beetle.id, Vector2i(5, 3), Vector2i(0, 1), 1))
	beetle.pos = Vector2i(4, 3)
	var grid := s.grid_power
	var ev := Resolver.apply(s, Action.end_turn())
	assert_false(blob.alive)
	assert_false(beetle.alive, "blob explosion kills attacker #2 first")
	assert_eq(s.grid_power, grid)
	assert_eq(FX.count(ev, "attack"), 1)


func test_resolution_order_numbers_follow_planning() -> void:
	var s := FX.state()
	FX.mech(s, "brawler", Vector2i(3, 6))
	for x in 3:
		FX.enemy(s, "beetle", Vector2i(x * 2, 0))
	EnemyAI.plan_turn(s)
	var orders: Array = []
	for e in s.enemies():
		orders.append(e.tele_order)
	assert_eq(orders, [1, 2, 3])


func test_spawn_emerges() -> void:
	var s := FX.state()
	FX.mech(s, "brawler", Vector2i(3, 6))
	s.spawns.append({"pos": Vector2i(1, 1), "kind": "hornet"})
	var ev := Resolver.apply(s, Action.end_turn())
	var u := s.unit_at(Vector2i(1, 1))
	assert_not_null(u)
	assert_eq(u.kind, "hornet")
	assert_true(FX.has(ev, "spawned"))
	assert_eq(s.spawns.size(), 0)


func test_spawn_blocked_by_unit_damages_it() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(1, 1))
	s.spawns.append({"pos": Vector2i(1, 1), "kind": "beetle"})
	var ev := Resolver.apply(s, Action.end_turn())
	assert_eq(m.hp, 2)
	assert_true(FX.has(ev, "spawn_blocked", m.id))
	assert_eq(s.enemies().size(), 0)


func test_spawner_marks_in_top_rows_and_respects_cap() -> void:
	var s := FX.state()
	s.mission = {"enemy_pool": {"beetle": 1}, "spawns_per_turn": 10, "enemy_cap": 4}
	FX.enemy(s, "beetle", Vector2i(6, 6))
	var ev := Spawner.mark(s)
	assert_eq(s.spawns.size(), 3)
	assert_eq(FX.count(ev, "spawn_marked"), 3)
	for sp in s.spawns:
		assert_lt(sp["pos"].y, 3)


func test_no_spawns_marked_on_last_turn() -> void:
	var s := FX.state()
	s.mission = {"enemy_pool": {"beetle": 1}, "spawns_per_turn": 2}
	s.turn = s.max_turns
	assert_eq(Spawner.mark(s).size(), 0)


func test_queen_marks_larvae_nearby() -> void:
	var s := FX.state()
	s.mission = {"enemy_pool": {"beetle": 1}, "spawns_per_turn": 0}
	var q := FX.enemy(s, "queen", Vector2i(3, 0))
	Spawner.mark(s)
	assert_eq(s.spawns.size(), q.larvae)
	for sp in s.spawns:
		assert_eq(sp["kind"], "larva")
		assert_lte(Rules.manhattan(sp["pos"], q.pos), 2)


func test_queen_line_attack_hits_three_tiles() -> void:
	var s := FX.state([".......", ".......", ".......", "...B..."])
	var q := FX.enemy(s, "queen", Vector2i(3, 0))
	var m := FX.mech(s, "brawler", Vector2i(3, 1))
	m.hp = 3
	var e := FX.enemy(s, "beetle", Vector2i(3, 2))
	Resolver.apply(s, Action.enemy_plan(q.id, q.pos, Vector2i(0, 1), 1))
	var ev := Resolver.apply(s, Action.end_turn())
	assert_eq(m.hp, 2)
	assert_eq(e.hp, 1)
	assert_true(FX.has(ev, "grid_lost") or FX.has(ev, "grid_resisted"))


func test_mission_won_after_max_turns() -> void:
	var s := FX.state()
	s.max_turns = 2
	FX.mech(s, "brawler", Vector2i(3, 6))
	var m := Mission.new(s)
	m.begin_turn()
	m.end_turn()
	assert_true(s.is_playing())
	var ev := m.end_turn()
	assert_eq(s.status, GameState.Status.WON)
	assert_true(FX.has(ev, "mission_won"))


func test_mission_lost_when_all_mechs_disabled() -> void:
	var s := FX.state()
	var mech := FX.mech(s, "brawler", Vector2i(3, 3))
	mech.hp = 1
	var e := FX.enemy(s, "beetle", Vector2i(3, 2))
	Resolver.apply(s, Action.enemy_plan(e.id, e.pos, Vector2i(0, 1), 1))
	Resolver.apply(s, Action.end_turn())
	assert_eq(s.status, GameState.Status.LOST)
	assert_eq(s.lost_reason, "mechs")


func test_kill_boss_wins_phase_two() -> void:
	var s := FX.state()
	s.mission = {"kill_boss": true}
	var m := FX.mech_w(s, "brawler", Vector2i(3, 1), "slam", ["damage", "damage", "damage"])
	var q := FX.enemy(s, "queen", Vector2i(3, 0))
	q.hp = 6
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 0)))
	assert_false(q.alive)
	assert_eq(s.status, GameState.Status.WON)
	assert_true(FX.has(ev, "mission_won"))


func test_enemy_on_spawn_tile_blocks_and_takes_damage() -> void:
	var s := FX.state()
	FX.mech(s, "brawler", Vector2i(6, 6))
	var e := FX.enemy(s, "scarab", Vector2i(2, 2))
	s.spawns.append({"pos": Vector2i(2, 2), "kind": "beetle"})
	Resolver.apply(s, Action.end_turn())
	assert_eq(e.hp, 1)
	assert_eq(s.enemies().size(), 1)


func test_generator_is_seeded_and_valid() -> void:
	for island in 4:
		for seed_value in 10:
			var a := MissionGen.generate(island, 0, seed_value)
			var b := MissionGen.generate(island, 0, seed_value)
			assert_eq(a.fingerprint(), b.fingerprint())
			assert_eq(Invariants.check(a).size(), 0, str(Invariants.check(a)))
			assert_eq(a.mechs().size(), 3)
			assert_gt(a.board.count_buildings(), 3)


func test_generator_islands_have_flavour() -> void:
	var counts := [0, 0, 0, 0]
	var want := [Board.Terrain.FOREST, Board.Terrain.WATER, Board.Terrain.MOUNTAIN, Board.Terrain.CHASM]
	for island in 4:
		var s := MissionGen.generate(island, 0, 99)
		for t in s.board.terrain:
			if t == want[island]:
				counts[island] += 1
	for island in 4:
		assert_gt(counts[island], 3, "island %d flavour" % island)


func test_final_phase_two_has_queen() -> void:
	var s := MissionGen.generate(-1, 0, 5, 7, [], 2)
	var bosses := s.enemies().filter(func(u: Unit) -> bool: return u.boss)
	assert_eq(bosses.size(), 1)
	assert_true(s.mission["kill_boss"])
