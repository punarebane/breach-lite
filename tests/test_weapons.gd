extends GutTest

const FX := preload("res://tests/fx.gd")


func test_all_twelve_pool_weapons_load() -> void:
	assert_eq(Data.weapons().size(), 12)
	for id in Data.weapons():
		var w := Data.weapon_def(id)
		assert_true(w["targeting"] in ["melee", "projectile", "artillery", "swap", "self", "line"], id)


func test_cannon_hits_first_thing_in_line() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(0, 3), "cannon")
	var near := FX.enemy(s, "scarab", Vector2i(3, 3))
	var far := FX.enemy(s, "scarab", Vector2i(5, 3))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(1, 3)))
	assert_eq(near.hp, 1)
	assert_eq(far.hp, 2)
	assert_eq(near.pos, Vector2i(4, 3), "pushed away")


func test_cannon_hits_mountain_before_unit() -> void:
	var s := FX.state([".......", ".......", ".......", "..M...."])
	var m := FX.mech_w(s, "brawler", Vector2i(0, 3), "cannon")
	var e := FX.enemy(s, "scarab", Vector2i(4, 3))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(1, 3)))
	assert_eq(e.hp, 2)
	assert_eq(s.board.get_hp(Vector2i(2, 3)), 1)


func test_grapple_pulls_toward() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(0, 3), "grapple")
	var e := FX.enemy(s, "beetle", Vector2i(4, 3))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(1, 3)))
	assert_eq(e.pos, Vector2i(3, 3))
	assert_eq(e.hp, 2)


func test_flame_jet_ignites_target() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(3, 3), "flame_jet")
	var e := FX.enemy(s, "scarab", Vector2i(3, 2))
	e.hp = 5
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 2)))
	assert_true(FX.has(ev, "fire_started"))
	assert_true(FX.has(ev, "caught_fire", e.id))
	assert_true(e.burning, "fire follows the unit after the push")
	assert_eq(e.pos, Vector2i(3, 1))


func test_slam_three_damage_no_push() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(3, 3), "slam")
	var e := FX.enemy(s, "queen", Vector2i(3, 2))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 2)))
	assert_eq(e.hp, e.max_hp - 3)


func test_spear_hits_two_tiles() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(3, 5), "spear")
	var a := FX.enemy(s, "scarab", Vector2i(3, 4))
	var b := FX.enemy(s, "scarab", Vector2i(3, 3))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 4)))
	assert_eq(a.hp, 1)
	assert_eq(b.hp, 1)
	assert_eq(b.pos, Vector2i(3, 2))


func test_cluster_spares_centre() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "artillery", Vector2i(3, 6), "cluster")
	var c := FX.enemy(s, "scarab", Vector2i(3, 3))
	var side := FX.enemy(s, "scarab", Vector2i(4, 3))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 3)))
	assert_eq(c.hp, 2)
	assert_eq(side.hp, 1)
	assert_eq(side.pos, Vector2i(5, 3))


func test_shockwave_pushes_all_neighbours() -> void:
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(3, 3), "shockwave")
	var n := FX.enemy(s, "beetle", Vector2i(3, 2))
	var w := FX.enemy(s, "beetle", Vector2i(2, 3))
	Resolver.apply(s, Action.attack(m.id, 0, Vector2i(3, 3)))
	assert_eq(n.pos, Vector2i(3, 1))
	assert_eq(w.pos, Vector2i(1, 3))
	assert_eq(n.hp, 2)


func test_upgrade_damage_and_range() -> void:
	var w := Data.weapon_def("punch", ["damage", "range"])
	assert_eq(w["damage"], 3)
	assert_eq(w["range_max"], 2)
	var s := FX.state()
	var m := FX.mech_w(s, "brawler", Vector2i(3, 3), "punch", ["range"])
	assert_true(Vector2i(3, 1) in Rules.targets(s, m, m.weapon_def(0)))


func test_upgrade_special_overrides() -> void:
	assert_true(Data.weapon_def("punch", ["special"])["ignite"])
	assert_eq(Data.weapon_def("arc_shell", ["special"])["adjacent_damage"], 1)


func test_cluster_damage_upgrade_boosts_adjacent() -> void:
	assert_eq(Data.weapon_def("cluster", ["damage"])["adjacent_damage"], 2)
	assert_eq(Data.weapon_def("cluster", ["damage"])["damage"], 0)


func test_attack_events_are_complete_story() -> void:
	var s := FX.state(["...~..."])
	var m := FX.mech(s, "brawler", Vector2i(1, 0))
	var e := FX.enemy(s, "scarab", Vector2i(2, 0))
	e.hp = 3
	var ev := Resolver.apply(s, Action.attack(m.id, 0, Vector2i(2, 0)))
	assert_eq(FX.types(ev), ["attack", "hit", "damaged", "pushed", "drowned", "destroyed"] as Array[String])
