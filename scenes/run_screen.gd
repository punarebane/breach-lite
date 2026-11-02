class_name RunScreen
extends Control
## Between missions: run progress, squad loadout, Reputation shop, start next mission.

signal start_mission
signal to_menu

var run: RunState
var last_report: Dictionary = {}
var pending_weapon: int = -1
var body: VBoxContainer


func setup(r: RunState, report: Dictionary = {}) -> void:
	run = r
	last_report = report


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.c("background")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 30)
	scroll.size = Vector2(1160, 670)
	add_child(scroll)
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(1140, 0)
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	rebuild()


func rebuild() -> void:
	for c in body.get_children():
		c.queue_free()
	if run.status == "won":
		body.add_child(UI.label("VICTORY. The Hive Queen is dead.", 40, "good"))
	elif run.status == "lost":
		body.add_child(UI.label("RUN OVER", 40, "bad"))
	else:
		body.add_child(UI.label("NEXT: " + run.mission_title(), 34, "accent"))
	body.add_child(UI.label("Grid power %d/%d    Reputation %d" % [run.grid_power, int(Data.rule("max_grid")), run.reputation], 22))
	if not last_report.is_empty():
		var r := last_report
		var txt := "Last mission: %s. Kills %d, mech damage %d, grid %d → %d." % ["won" if r["won"] else "lost", r["kills"], r["mech_damage"], r["grid_before"], r["grid_after"]]
		if r["won"]:
			txt += "  Bonus (%s): %s.  +%d reputation." % [r["bonus_type"], "complete" if r["bonus"] else "missed", r["rep"]]
		body.add_child(UI.label(txt, 16, "text_dim"))
	body.add_child(_progress())
	body.add_child(UI.label("SQUAD", 16, "text_dim"))
	for mi in run.squad.size():
		var m: Dictionary = run.squad[mi]
		var names := PackedStringArray()
		for w in m["weapons"]:
			var d := Data.weapon_def(w["id"], w["upgrades"])
			names.append("%s%s" % [d["name"], (" [" + ", ".join(PackedStringArray(w["upgrades"])) + "]") if not w["upgrades"].is_empty() else ""])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var ml := UI.label("%s: %s" % [Data.mechs()[m["kind"]]["name"], " / ".join(names)], 18)
		ml.autowrap_mode = TextServer.AUTOWRAP_OFF
		ml.custom_minimum_size = Vector2(600, 0)
		row.add_child(ml)
		if pending_weapon >= 0:
			row.add_child(UI.button("Equip here", _equip.bind(mi), 160))
		body.add_child(row)
	if run.shop_pending and run.status == "playing":
		body.add_child(UI.label("REPUTATION SHOP", 16, "text_dim"))
		for i in run.shop_items.size():
			var it: Dictionary = run.shop_items[i]
			var b := UI.button("%s   (%d rep)%s" % [RunState.item_text(it), it["cost"], "  SOLD" if it.get("sold", false) else ""], _buy.bind(i), 1000)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not run.can_buy(it)
			body.add_child(b)
		if pending_weapon >= 0:
			body.add_child(UI.label("Choose a mech for the new weapon (fills slot 2, or replaces it).", 16, "accent"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if run.status == "playing":
		var go := UI.button("Start mission", _start, 260)
		go.name = "StartButton"
		row.add_child(go)
	row.add_child(UI.button("Main menu", func() -> void: to_menu.emit(), 200))
	body.add_child(row)


func _progress() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var names: Array = []
	for isl in Data.islands():
		names.append(isl["name"])
	names.append("Hive")
	for i in names.size():
		var done := i < run.island
		var cur := i == run.island
		var l := UI.label(("✓ " if done else ("▶ " if cur else "  ")) + names[i], 18, "good" if done else ("accent" if cur else "text_dim"))
		l.custom_minimum_size = Vector2(200, 0)
		h.add_child(l)
	return h


func _buy(i: int) -> void:
	if run.shop_items[i]["type"] == "weapon":
		pending_weapon = i
		rebuild()
		return
	run.buy(i)
	run.save()
	rebuild()


func _equip(mi: int) -> void:
	run.buy(pending_weapon, mi)
	pending_weapon = -1
	run.save()
	rebuild()


func _start() -> void:
	if run.shop_pending:
		run.leave_shop()
		run.save()
	start_mission.emit()
