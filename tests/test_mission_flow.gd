extends GutTest
## Mission controller + MissionView interaction (headless, fast playback).

const FX := preload("res://tests/fx.gd")


func _mission() -> Mission:
	var s := Fixture.load_file("preview")
	var m := Mission.new(s)
	m.begin_turn()
	return m


func test_begin_turn_telegraphs_every_enemy() -> void:
	var m := _mission()
	for e in m.state.enemies():
		assert_gt(e.tele_order, 0, "%s telegraphs" % e.kind)
	var orders: Array = []
	for e in m.state.enemies():
		orders.append(e.tele_order)
	orders.sort()
	assert_eq(orders, [1, 2, 3])


func test_undo_restores_position() -> void:
	var m := _mission()
	var b := m.state.mechs()[1]
	var from := b.pos
	var dest: Vector2i = Rules.reachable(m.state, b).filter(func(p: Vector2i) -> bool: return p != from)[0]
	m.move(b.id, dest)
	assert_true(m.can_undo(b.id))
	m.undo(b.id)
	assert_eq(b.pos, from)
	assert_false(b.has_moved)


func test_no_undo_after_acting() -> void:
	var m := _mission()
	var w := m.state.mechs()[2]
	var dest: Vector2i = Rules.reachable(m.state, w).filter(func(p: Vector2i) -> bool: return p != w.pos)[0]
	m.move(w.id, dest)
	var targets := Rules.targets(m.state, w, w.weapon_def(0))
	if targets.is_empty():
		pass_test("no swap target in range")
		return
	m.attack(w.id, 0, targets[0])
	assert_false(m.can_undo(w.id))


func test_reset_turn_once() -> void:
	var m := _mission()
	var b := m.state.mechs()[0]
	var snapshot_pos := b.pos
	var dest: Vector2i = Rules.reachable(m.state, b).filter(func(p: Vector2i) -> bool: return p != b.pos)[0]
	m.move(b.id, dest)
	assert_true(m.reset_turn())
	assert_eq(m.state.mechs()[0].pos, snapshot_pos)
	assert_false(m.can_reset(), "reset only once per mission")
	assert_false(m.reset_turn())


func test_preview_does_not_mutate() -> void:
	var m := _mission()
	var b := m.state.mechs()[0]
	var before := m.state.duplicate()
	var t := Rules.targets(m.state, b, b.weapon_def(0))[0]
	m.preview(Action.attack(b.id, 0, t))
	assert_eq(m.state.grid_power, before.grid_power)
	for u in m.state.units:
		var o := before.get_unit(u.id)
		assert_eq(u.pos, o.pos)
		assert_eq(u.hp, o.hp)
	assert_eq(m.state.grid_rng.state, before.grid_rng.state)


func test_preview_matches_real() -> void:
	var m := _mission()
	var b := m.state.mechs()[0]
	for t in Rules.targets(m.state, b, b.weapon_def(0)):
		var a := Action.attack(b.id, 0, t)
		var pv: Array[Event] = m.preview(a)[0]
		var copy := m.state.duplicate()
		var real := Resolver.apply(copy, a)
		assert_eq(Event.keys(pv), Event.keys(real))


func test_view_click_select_move_attack() -> void:
	var m := _mission()
	var mv := MissionView.new()
	mv.setup(m, "TEST")
	mv.fast = true
	add_child_autofree(mv)
	await wait_frames(2)
	var b := m.state.mechs()[0]
	await mv.click_tile(b.pos)
	assert_eq(mv.selected, b.id)
	var dest: Vector2i = Rules.reachable(m.state, b).filter(func(p: Vector2i) -> bool: return p != b.pos)[0]
	await mv.click_tile(dest)
	assert_eq(b.pos, dest)
	assert_true(b.has_moved)
	mv._on_undo()
	await wait_frames(2)
	await wait_seconds(0.2)
	assert_false(b.has_moved, "undo via view")
	mv._on_weapon(0)
	assert_eq(mv.armed_slot, 0)
	var t := Rules.targets(m.state, b, b.weapon_def(0))[0]
	await mv.click_tile(t)
	assert_true(b.has_acted)
