extends GutTest

const FX := preload("res://tests/fx.gd")


func test_board_defaults_to_ground_7x7() -> void:
	var s := FX.state()
	assert_eq(s.board.width, 7)
	assert_eq(s.board.get_t(Vector2i(3, 3)), Board.Terrain.GROUND)
	assert_false(s.board.in_bounds(Vector2i(7, 0)))
	assert_false(s.board.in_bounds(Vector2i(-1, 0)))


func test_reachable_open_ground_diamond() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var r := Rules.reachable(s, m)
	# Manhattan diamond of radius 3 fully inside 7x7: 25 tiles.
	assert_eq(r.size(), 25)
	assert_true(Vector2i(3, 0) in r)
	assert_false(Vector2i(0, 0) in r)


func test_ground_blocked_by_mountain_wall() -> void:
	var s := FX.state([".......", ".......", "MMMMMMM", ".......", ".......", ".......", "......."])
	var m := FX.mech(s, "brawler", Vector2i(3, 4))
	for p in Rules.reachable(s, m):
		assert_true(p.y > 2, "ground mech crossed the wall at %s" % p)


func test_flying_crosses_mountain_wall() -> void:
	var s := FX.state([".......", ".......", "MMMMMMM", ".......", ".......", ".......", "......."])
	var m := FX.mech(s, "warper", Vector2i(3, 4))
	var r := Rules.reachable(s, m)
	assert_true(Vector2i(3, 1) in r)
	assert_false(Vector2i(3, 2) in r, "cannot end on a mountain")


func test_ground_cannot_enter_water_or_chasm() -> void:
	var s := FX.state(["...~...", "...~...", "..._...", "...~...", ".......", ".......", "......."])
	var m := FX.mech(s, "brawler", Vector2i(2, 1))
	var r := Rules.reachable(s, m)
	assert_false(Vector2i(3, 1) in r)
	assert_false(Vector2i(3, 2) in r)


func test_flying_can_end_on_water() -> void:
	var s := FX.state(["...~..."])
	var m := FX.mech(s, "warper", Vector2i(2, 0))
	assert_true(Vector2i(3, 0) in Rules.reachable(s, m))


func test_cannot_pass_through_enemy_but_can_pass_ally() -> void:
	var s := FX.state(["M.M....", "M.M....", "M.M....", ".......", ".......", ".......", "......."])
	var m := FX.mech(s, "brawler", Vector2i(1, 0))
	FX.enemy(s, "beetle", Vector2i(1, 1))
	assert_false(Vector2i(1, 2) in Rules.reachable(s, m), "enemy blocks the corridor")
	var s2 := FX.state(["M.M....", "M.M....", "M.M....", ".......", ".......", ".......", "......."])
	var m2 := FX.mech(s2, "brawler", Vector2i(1, 0))
	FX.mech(s2, "artillery", Vector2i(1, 1))
	var r2 := Rules.reachable(s2, m2)
	assert_true(Vector2i(1, 2) in r2, "ally can be passed through")
	assert_false(Vector2i(1, 1) in r2, "cannot end on ally")


func test_move_action_emits_moved_and_sets_flag() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var ev := Resolver.apply(s, Action.move(m.id, Vector2i(3, 1)))
	assert_eq(FX.types(ev), ["moved"] as Array[String])
	assert_eq(m.pos, Vector2i(3, 1))
	assert_true(m.has_moved)
	assert_eq(Resolver.apply(s, Action.move(m.id, Vector2i(3, 2)))[0].type, "illegal", "only one move")


func test_move_out_of_range_illegal() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(0, 0))
	var ev := Resolver.apply(s, Action.move(m.id, Vector2i(3, 3)))
	assert_eq(ev[0].type, "illegal")
	assert_eq(m.pos, Vector2i(0, 0))


func test_moving_onto_burning_forest_sets_burning() -> void:
	var s := FX.state(["..F...."])
	s.board.fire[s.board.idx(Vector2i(2, 0))] = 1
	var m := FX.mech(s, "brawler", Vector2i(0, 0))
	var ev := Resolver.apply(s, Action.move(m.id, Vector2i(2, 0)))
	assert_true(FX.has(ev, "caught_fire", m.id))
	assert_true(m.burning)


func test_digger_burrow_reaches_any_ground_tile() -> void:
	var s := FX.state(["~~~~~~~", "M......"])
	var d := FX.enemy(s, "digger", Vector2i(6, 6))
	var r := Rules.reachable(s, d)
	assert_true(Vector2i(1, 1) in r)
	assert_false(Vector2i(0, 0) in r)
	assert_false(Vector2i(0, 1) in r)


func test_duplicate_is_deep() -> void:
	var s := FX.state()
	var m := FX.mech(s, "brawler", Vector2i(3, 3))
	var c := s.duplicate()
	c.get_unit(m.id).pos = Vector2i(0, 0)
	c.board.set_t(Vector2i(1, 1), Board.Terrain.WATER)
	c.grid_rng.randf()
	assert_eq(m.pos, Vector2i(3, 3))
	assert_eq(s.board.get_t(Vector2i(1, 1)), Board.Terrain.GROUND)
	assert_ne(c.grid_rng.state, s.grid_rng.state)
