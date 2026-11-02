extends SceneTree
## Balance sim: godot --headless -s tools/sim.gd -- --runs=300 [--start=0] [--out=path.json]
## Plays seeded runs with the greedy PlayerBot and reports mission win rate per island,
## grid lost per mission and run win rate.


func _init() -> void:
	var args := {"runs": "300", "start": "0", "out": ""}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var runs := int(args["runs"])
	var start := int(args["start"])
	var t0 := Time.get_ticks_msec()
	var reports: Array = []
	var run_wins := 0
	for i in runs:
		var r := PlayerBot.play_run(start + i + 1)
		if r.status == "won":
			run_wins += 1
		reports.append({"seed": start + i + 1, "status": r.status, "history": r.history, "squad": r.squad})
		if (i + 1) % 10 == 0:
			printerr("  %d/%d runs, %.1fs" % [i + 1, runs, (Time.get_ticks_msec() - t0) / 1000.0])
	var summary := summarize(reports)
	print(format(summary))
	if args["out"] != "":
		var f := FileAccess.open(args["out"], FileAccess.WRITE)
		f.store_string(JSON.stringify(reports))
	quit()


static func summarize(reports: Array) -> Dictionary:
	var per := {}
	var grid_lost := 0
	var missions := 0
	var wins := 0
	var bonus := 0
	for rep in reports:
		if rep["status"] == "won":
			wins += 1
		for h in rep["history"]:
			var key := "final%d" % int(h["phase"]) if int(h["island"]) >= 4 else "island%d" % (int(h["island"]) + 1)
			if not per.has(key):
				per[key] = {"played": 0, "won": 0, "grid_lost": 0}
			per[key]["played"] += 1
			if h["won"]:
				per[key]["won"] += 1
			if h["bonus"]:
				bonus += 1
			per[key]["grid_lost"] += int(h["grid_before"]) - int(h["grid_after"])
			grid_lost += int(h["grid_before"]) - int(h["grid_after"])
			missions += 1
	return {"runs": reports.size(), "run_wins": wins, "per": per, "missions": missions, "grid_lost": grid_lost, "bonus": bonus}


static func format(s: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("runs: %d   run win rate: %.1f%%" % [s["runs"], 100.0 * s["run_wins"] / maxf(1, s["runs"])])
	lines.append("missions: %d   grid lost per mission: %.2f   bonus rate: %.1f%%" % [s["missions"], float(s["grid_lost"]) / maxf(1, s["missions"]), 100.0 * s["bonus"] / maxf(1, s["missions"])])
	var keys: Array = s["per"].keys()
	keys.sort()
	for k in keys:
		var p: Dictionary = s["per"][k]
		lines.append("  %-8s played %4d  win %5.1f%%  grid lost/mission %.2f" % [k, p["played"], 100.0 * p["won"] / maxf(1, p["played"]), float(p["grid_lost"]) / maxf(1, p["played"])])
	return "\n".join(lines)
