extends GutTest
## Drives real screens through the UI (clicks/keys) to catch presentation-only bugs.


func _bot_click_turn(mv: MissionView) -> void:
	var m := mv.mission
	for u in m.state.alive_units(Unit.Team.MECH):
		if not m.state.is_playing():
			return
		var plan: Array = PlayerBot.best_for(m.state, u)
		await mv.click_tile(u.pos)
		if plan[1] != u.pos:
			await mv.click_tile(plan[1])
		if plan[2] >= 0 and m.state.is_playing():
			mv.select(u.id)
			mv._on_weapon(plan[2])
			await mv.click_tile(plan[3])
	if m.state.is_playing():
		await mv._on_end_turn()


func test_full_mission_through_view() -> void:
	for seed_value in [3, 8]:
		var r := RunState.new_run(seed_value)
		r.island = 2
		var mv := MissionView.new()
		mv.setup(Mission.new(r.build_mission()), r.mission_title())
		mv.fast = true
		add_child_autofree(mv)
		await wait_frames(3)
		var finished := {"won": null}
		mv.finished.connect(func(w: bool) -> void: finished["won"] = w)
		var guard := 0
		while mv.mission.state.is_playing() and guard < 12:
			guard += 1
			await _bot_click_turn(mv)
		assert_false(mv.mission.state.is_playing(), "mission finished")
		assert_not_null(mv.result_panel, "result panel shown")
		for u in mv.mission.state.alive_units():
			assert_true(mv.views.has(u.id))
		assert_eq(Invariants.check(mv.mission.state).size(), 0)


func test_main_menu_to_run_to_mission() -> void:
	RunState.delete_save()
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	assert_true(main.screen is MenuScreen)
	var cont: Button = main.screen.find_child("ContinueButton", true, false)
	assert_true(cont.disabled, "no save yet")
	main.screen.find_child("NewRunButton", true, false).pressed.emit()
	await wait_frames(2)
	assert_true(main.screen is RunScreen)
	assert_true(RunState.has_save())
	main.screen.find_child("StartButton", true, false).pressed.emit()
	await wait_frames(2)
	assert_true(main.screen is MissionView)
	var mv: MissionView = main.screen
	mv.fast = true
	await wait_seconds(0.5)
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	mv._unhandled_input(key)
	assert_eq(mv.selected, mv.mission.state.mechs()[0].id, "key 1 selects first mech")
	RunState.delete_save()


func test_tutorial_from_menu() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	main.screen.find_child("TutorialButton", true, false).pressed.emit()
	await wait_frames(2)
	assert_true(main.screen is MissionView)
	assert_true(main.screen.tutorial)
	assert_ne(main.screen.tutor_label.text, "")
