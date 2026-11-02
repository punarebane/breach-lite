extends Node2D
## Entry point and screen flow: menu → run screen (shop) → mission → run screen ...

var screen: Node
var run: RunState


func _ready() -> void:
	RenderingServer.set_default_clear_color(Pal.c("background"))
	Sfx.ensure(self)
	var args := _args()
	if args.has("screenshot"):
		_screenshot(String(args["screenshot"]))
		return
	show_menu()


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


func _set_screen(n: Node) -> void:
	if screen:
		screen.queue_free()
	screen = n
	add_child(n)


func show_menu() -> void:
	var m := MenuScreen.new()
	m.new_run.connect(_on_new_run)
	m.continue_run.connect(_on_continue)
	m.tutorial.connect(_on_tutorial)
	_set_screen(m)


func _on_new_run() -> void:
	run = RunState.new_run(int(Time.get_unix_time_from_system()) % 1000000 + 1)
	run.save()
	show_run({})


func _on_continue() -> void:
	run = RunState.load_run()
	if run == null:
		show_menu()
		return
	show_run({})


func _on_tutorial() -> void:
	print("TUTORIAL_STARTED")
	var mv := MissionView.new()
	mv.setup(Mission.new(Fixture.load_file("tutorial")), "TUTORIAL")
	mv.tutorial = true
	_set_screen(mv)
	mv.finished.connect(func(_won: bool) -> void: show_menu())


func show_run(report: Dictionary) -> void:
	var rs := RunScreen.new()
	rs.setup(run, report)
	rs.start_mission.connect(_start_mission)
	rs.to_menu.connect(show_menu)
	_set_screen(rs)


func _start_mission() -> void:
	var mv := _show_mission(Mission.new(run.build_mission()), run.mission_title())
	mv.finished.connect(_on_mission_finished.bind(mv))


func _on_mission_finished(_won: bool, mv: MissionView) -> void:
	var report := run.complete_mission(mv.mission.state)
	if run.status == "playing":
		run.save()
	else:
		RunState.delete_save()
	show_run(report)


func _show_mission(m: Mission, title: String) -> MissionView:
	var mv := MissionView.new()
	mv.setup(m, title)
	_set_screen(mv)
	return mv


## --screenshot=<fixture>[:x:y] loads a fixture, renders a few frames, saves a PNG, quits.
## --screenshot=menu captures the main menu.
func _screenshot(spec: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("screenshot: skipped (headless, no renderer)")
		get_tree().quit(0)
		return
	var parts := spec.split(":")
	if parts[0] == "menu":
		show_menu()
	elif parts[0] == "run":
		run = RunState.new_run(42)
		run.island = 1
		run.reputation = 5
		run.shop_pending = true
		run.shop_items = run.roll_shop()
		run.squad[1]["weapons"][0]["upgrades"].append("damage")
		show_run({"won": true, "kills": 8, "mech_damage": 1, "grid_before": 7, "grid_after": 6, "bonus_type": "kills", "bonus": true, "rep": 2})
	elif parts[0] == "mission":
		var r := RunState.new_run(int(parts[1]) if parts.size() > 1 else 7)
		if parts.size() > 2:
			r.island = int(parts[2])
		var mv := _show_mission(Mission.new(r.build_mission()), r.mission_title())
		mv.fast = true
	else:
		var state := Fixture.load_file(parts[0])
		var mv := _show_mission(Mission.new(state), parts[0].to_upper())
		mv.fast = true
		mv.tutorial = parts[0] == "tutorial"
		for i in 30:
			await get_tree().process_frame
		if parts.size() > 2:
			mv.select(mv.mission.state.mechs()[0].id)
			mv.armed_slot = 0
			mv.hover_tile = Vector2i(int(parts[1]), int(parts[2]))
			mv.refresh()
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var path := "res://screenshots/%s.png" % spec.replace(":", "_")
	img.save_png(path)
	print("screenshot: saved ", path)
	get_tree().quit(0)
