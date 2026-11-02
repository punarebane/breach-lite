extends Node2D
## Entry point. Screens: main menu, run map, mission, shop. M2: fixture mission.

var screen: Node


func _ready() -> void:
	RenderingServer.set_default_clear_color(Pal.c("background"))
	var args := _args()
	if args.has("screenshot"):
		_screenshot(String(args["screenshot"]))
		return
	var state := Fixture.load_file("demo")
	_show_mission(Mission.new(state), "DEMO")


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out


func _show_mission(m: Mission, title: String) -> MissionView:
	if screen:
		screen.queue_free()
	var mv := MissionView.new()
	mv.setup(m, title)
	add_child(mv)
	screen = mv
	return mv


## --screenshot=<fixture>[:select] loads a fixture, renders a few frames, saves a PNG, quits.
func _screenshot(spec: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("screenshot: skipped (headless, no renderer)")
		get_tree().quit(0)
		return
	var parts := spec.split(":")
	var state := Fixture.load_file(parts[0])
	var mv := _show_mission(Mission.new(state), parts[0].to_upper())
	mv.fast = true
	for i in 30:
		await get_tree().process_frame
	if parts.size() > 1:
		mv.select(mv.mission.state.mechs()[0].id)
		mv.armed_slot = 0
		mv.hover_tile = Vector2i(int(parts[1]), int(parts[2])) if parts.size() > 2 else Vector2i(-1, -1)
		mv.refresh()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var path := "res://screenshots/%s.png" % spec.replace(":", "_")
	img.save_png(path)
	print("screenshot: saved ", path)
	get_tree().quit(0)
