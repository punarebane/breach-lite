extends SceneTree
## Merges sim worker outputs: godot --headless -s tools/sim_merge.gd -- <dir>
const Sim := preload("res://tools/sim.gd")


func _init() -> void:
	var dir := String(OS.get_cmdline_user_args()[0])
	var reports: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			reports.append_array(JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f)))
	print(Sim.format(Sim.summarize(reports)))
	quit()
