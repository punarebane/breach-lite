class_name MissionView
extends Node2D
## Presentation of one mission: input, overlays, HUD and event playback.
## All rules live in core/; this node only calls Mission and replays Events.

signal finished(won: bool)

const T := 80.0
const ORIGIN := Vector2(300, 90)

var mission: Mission
var title: String = ""
var board_view: BoardView
var overlay: OverlayView
var units_layer: Node2D
var views: Dictionary = {}
var selected: int = -1
var armed_slot: int = -1
var busy: bool = false
var hover_tile: Vector2i = Vector2i(-1, -1)
var fast: bool = false
var tutorial: bool = false
var tutor_label: Label

var hud: CanvasLayer
var top_label: Label
var info_label: Label
var weapon_buttons: Array[Button] = []
var undo_button: Button
var reset_button: Button
var end_button: Button
var tooltip: Label
var banner: Label
var result_panel: PanelContainer
var shake: float = 0.0


func setup(p_mission: Mission, p_title: String = "") -> void:
	mission = p_mission
	title = p_title


func _ready() -> void:
	board_view = BoardView.new()
	board_view.position = ORIGIN
	add_child(board_view)
	units_layer = Node2D.new()
	units_layer.position = ORIGIN
	add_child(units_layer)
	overlay = OverlayView.new()
	overlay.position = ORIGIN
	overlay.board_view = board_view
	add_child(overlay)
	_build_hud()
	board_view.board = mission.state.board.duplicate()
	_rebuild_views()
	if mission.turn_snapshot == null:
		await play(mission.begin_turn())
	refresh()


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	top_label = UI.label("", 21)
	top_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_label.position = Vector2(300, 34)
	top_label.size = Vector2(950, 40)
	root.add_child(top_label)
	var side := UI.panel()
	side.position = Vector2(905, 90)
	side.custom_minimum_size = Vector2(345, 560)
	root.add_child(side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	side.add_child(v)
	info_label = UI.label("", 17)
	info_label.custom_minimum_size = Vector2(320, 130)
	v.add_child(info_label)
	for i in 2:
		var b := UI.button("", _on_weapon.bind(i), 320)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		weapon_buttons.append(b)
	undo_button = UI.button("Undo move  [Z]", _on_undo, 320)
	v.add_child(undo_button)
	reset_button = UI.button("Reset turn (once)", _on_reset, 320)
	v.add_child(reset_button)
	end_button = UI.button("End turn  [Space]", _on_end_turn, 320)
	v.add_child(end_button)
	tooltip = UI.label("", 15, "text_dim")
	tooltip.custom_minimum_size = Vector2(320, 120)
	v.add_child(tooltip)
	var help := UI.label("1/2/3 select mech · Q/W weapon · right-click cancel", 13, "text_dim")
	v.add_child(help)
	var left := UI.panel()
	left.position = Vector2(30, 90)
	left.custom_minimum_size = Vector2(240, 300)
	root.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(UI.label("SQUAD", 16, "text_dim"))
	var squad := UI.label("", 16)
	squad.name = "Squad"
	lv.add_child(squad)
	tutor_label = UI.label("", 16, "accent")
	tutor_label.position = Vector2(30, 410)
	tutor_label.size = Vector2(250, 280)
	tutor_label.visible = false
	root.add_child(tutor_label)
	banner = UI.label("", 34, "accent")
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(300, 330)
	banner.size = Vector2(560, 60)
	banner.visible = false
	root.add_child(banner)


func _squad_label() -> Label:
	return hud.get_child(0).find_child("Squad", true, false)


func refresh() -> void:
	var s := mission.state
	var bonus := String(s.mission.get("bonus", ""))
	top_label.text = "%s   GRID %d   TURN %d/%d   %s" % [title, s.grid_power, mini(s.turn, s.max_turns), s.max_turns, _bonus_text(bonus)]
	var sq := ""
	for m in s.mechs():
		sq += "%s  %s\n" % [m.display_name(), ("HP %d/%d" % [m.hp, m.max_hp]) if m.alive else "DISABLED"]
	_squad_label().text = sq
	var u := s.get_unit(selected)
	if u != null and u.alive and u.is_mech():
		info_label.text = "%s\nHP %d/%d   Move %d%s\n%s" % [u.display_name(), u.hp, u.max_hp, u.move, "  (flying)" if u.flying else "",
			"Acted" if u.has_acted else ("Moved" if u.has_moved else "Ready")]
		for i in 2:
			var b := weapon_buttons[i]
			if i < u.weapons.size():
				var w := u.weapon_def(i)
				b.text = "%s %s%s" % ["QW"[i], w["name"], "  ◀" if armed_slot == i else ""]
				b.disabled = u.has_acted or busy
				b.tooltip_text = w["desc"]
				b.visible = true
			else:
				b.visible = false
	else:
		info_label.text = "Select a mech (1/2/3 or click)."
		for b in weapon_buttons:
			b.visible = false
	undo_button.disabled = busy or not mission.can_undo(selected)
	reset_button.disabled = busy or not mission.can_reset()
	end_button.disabled = busy or not s.is_playing()
	if tutorial:
		tutor_label.visible = true
		tutor_label.text = _tutor_text()
	_refresh_overlays()


func _tutor_text() -> String:
	var t: Dictionary = Data.load_json("tutorial")
	var s := mission.state
	if s.status == GameState.Status.WON:
		return t["won"]
	var u := s.get_unit(selected)
	var key := "no_selection"
	var all_done := true
	for m in s.alive_units(Unit.Team.MECH):
		if not m.has_acted:
			all_done = false
	if all_done:
		key = "all_done"
	elif u != null and u.alive:
		if armed_slot >= 0:
			key = "armed"
		elif u.has_acted:
			key = "acted"
		elif u.has_moved:
			key = "moved"
		else:
			key = "can_move"
	var txt := String(t[key])
	if s.turn == 1 and key == "no_selection":
		txt = String(t["intro"]) + "\n\n" + txt
	return txt


func _bonus_text(bonus: String) -> String:
	var s := mission.state
	match bonus:
		"kills":
			return "BONUS kill 7 (%d)" % s.kills
		"objective":
			return "BONUS protect objective%s" % (" (lost)" if s.objective_lost else "")
		"no_damage":
			return "BONUS mech damage < 2 (%d)" % s.mech_damage
	return ""


func _refresh_overlays() -> void:
	var s := mission.state
	board_view.move_tiles.clear()
	board_view.target_tiles.clear()
	board_view.preview.clear()
	board_view.hover = hover_tile
	board_view.hover_kind = ""
	board_view.spawns = s.spawns
	var shown := s
	var u := s.get_unit(selected)
	if not busy and u != null and u.alive and u.is_mech() and s.is_playing():
		if armed_slot >= 0:
			var w := u.weapon_def(armed_slot)
			board_view.target_tiles = _target_display(u, w)
			if hover_tile.x >= 0:
				var tgt := Rules.canonical_target(u, w, hover_tile)
				if tgt in Rules.targets(s, u, w):
					var res := mission.preview(Action.attack(u.id, armed_slot, tgt))
					board_view.preview = res[0]
					shown = res[1]
					board_view.hover_kind = "target"
		elif not u.has_moved and not u.has_acted:
			for p in Rules.reachable(s, u):
				if p != u.pos:
					board_view.move_tiles.append(p)
			if hover_tile in board_view.move_tiles:
				board_view.hover_kind = "move"
	board_view.telegraphs = [] if busy else telegraphs_for(shown)
	_update_tooltip()


## Projectile/line weapons aim by direction: highlight the whole line.
func _target_display(u: Unit, w: Dictionary) -> Array[Vector2i]:
	var s := mission.state
	var out: Array[Vector2i] = []
	var t := String(w["targeting"])
	if t == "projectile" or t == "line":
		for dir in Board.DIRS:
			var p: Vector2i = u.pos + dir
			while s.board.in_bounds(p):
				out.append(p)
				p += dir
		return out
	return Rules.targets(s, u, w)


static func telegraphs_for(s: GameState) -> Array:
	var out: Array = []
	for e in s.enemies():
		if e.tele_order <= 0:
			continue
		var w := e.weapon_def()
		var tiles := Rules.hit_tiles(s, e, w, e.pos, e.tele_dir, e.tele_dist)
		var target: Vector2i = e.pos + e.tele_dir * maxi(e.tele_dist, 1)
		if String(w["targeting"]) == "projectile":
			if tiles.is_empty():
				var p := e.pos
				while s.board.in_bounds(p + e.tele_dir):
					p += e.tele_dir
				target = p
			else:
				target = tiles[0]
		elif String(w["targeting"]) == "line" and not tiles.is_empty():
			target = tiles[tiles.size() - 1]
		if not s.board.in_bounds(target):
			continue
		out.append({"from": e.pos, "tiles": tiles, "order": e.tele_order, "dir": e.tele_dir, "target": target, "boss": e.boss})
	return out


func _update_tooltip() -> void:
	if hover_tile.x < 0:
		tooltip.text = ""
		return
	var s := mission.state
	var tiles: Dictionary = Data.load_json("tiles")
	var txt := ""
	var u := s.unit_at(hover_tile)
	if u != null:
		if u.is_mech():
			txt += "%s (HP %d/%d)\n%s\n" % [u.display_name(), u.hp, u.max_hp, Data.mechs()[u.kind]["desc"]]
		else:
			txt += "%s (HP %d/%d)\n%s\n" % [u.display_name(), u.hp, u.max_hp, Data.enemies()[u.kind]["desc"]]
			if u.tele_order > 0:
				txt += "Attacks #%d this turn.\n" % u.tele_order
		if u.burning:
			txt += "Burning: 1 damage per turn.\n"
	var tn: String = Board.TERRAIN_NAMES[s.board.get_t(hover_tile)]
	txt += String(tiles.get(tn, tn))
	if s.board.is_building(hover_tile):
		txt += " HP %d." % s.board.get_hp(hover_tile)
	if s.board.is_burning(hover_tile):
		txt += "\n" + String(tiles["burning"])
	if s.spawn_at(hover_tile) >= 0:
		txt += "\n" + String(tiles["spawn"])
	tooltip.text = txt


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var t := board_view.tile_at(board_view.get_local_mouse_position())
		if t != hover_tile:
			hover_tile = t
			_refresh_overlays()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			click_tile(board_view.tile_at(board_view.get_local_mouse_position()))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				_select_index(event.keycode - KEY_1)
			KEY_Q:
				_on_weapon(0)
			KEY_W:
				_on_weapon(1)
			KEY_Z:
				_on_undo()
			KEY_SPACE:
				_on_end_turn()
			KEY_ESCAPE:
				_cancel()


func _select_index(i: int) -> void:
	var ms := mission.state.mechs()
	if i < ms.size() and ms[i].alive:
		select(ms[i].id)


func select(uid: int) -> void:
	if uid >= 0 and uid != selected:
		Sfx.play("select")
	selected = uid
	armed_slot = -1
	for id in views:
		views[id].selected = (id == uid)
		views[id].queue_redraw()
	refresh()


func _cancel() -> void:
	if armed_slot >= 0:
		armed_slot = -1
	else:
		select(-1)
	refresh()


func click_tile(t: Vector2i) -> void:
	if busy or not mission.state.is_playing() or t.x < 0:
		return
	var s := mission.state
	var u := s.get_unit(selected)
	if u != null and u.alive and armed_slot >= 0:
		var w := u.weapon_def(armed_slot)
		var tgt := Rules.canonical_target(u, w, t)
		if tgt in Rules.targets(s, u, w):
			var slot := armed_slot
			armed_slot = -1
			await run_events(mission.attack(u.id, slot, tgt))
			return
	var clicked := s.unit_at(t)
	if clicked != null and clicked.is_mech():
		select(clicked.id)
		return
	if u != null and u.alive and not u.has_moved and t in Rules.reachable(s, u) and t != u.pos:
		await run_events(mission.move(u.id, t))
		return
	select(-1)


func _on_weapon(i: int) -> void:
	var u := mission.state.get_unit(selected)
	if busy or u == null or not u.alive or u.has_acted or i >= u.weapons.size():
		return
	armed_slot = -1 if armed_slot == i else i
	refresh()


func _on_undo() -> void:
	if busy:
		return
	var uid := selected
	if not mission.can_undo(uid):
		for id in mission.undo_info:
			if mission.can_undo(id):
				uid = id
	if mission.can_undo(uid):
		await run_events(mission.undo(uid))


func _on_reset() -> void:
	if busy or not mission.reset_turn():
		return
	board_view.board = mission.state.board.duplicate()
	_rebuild_views()
	select(-1)


func _on_end_turn() -> void:
	if busy or not mission.state.is_playing():
		return
	armed_slot = -1
	await run_events(mission.end_turn())


func run_events(ev: Array[Event]) -> void:
	busy = true
	refresh()
	await play(ev)
	busy = false
	refresh()
	if not mission.state.is_playing():
		_show_result()


# --- playback ------------------------------------------------------------------

func _rebuild_views() -> void:
	for c in units_layer.get_children():
		c.queue_free()
	views.clear()
	for u in mission.state.units:
		if u.alive:
			_add_view(u)


func _add_view(u: Unit) -> UnitView:
	var v := UnitView.new()
	v.setup(u)
	v.position = BoardView.center(u.pos)
	units_layer.add_child(v)
	views[u.id] = v
	return v


func _sync_views() -> void:
	var s := mission.state
	for u in s.units:
		if u.alive and not views.has(u.id):
			_add_view(u)
		if views.has(u.id):
			var v: UnitView = views[u.id]
			if not u.alive:
				v.queue_free()
				views.erase(u.id)
			else:
				v.position = BoardView.center(u.pos)
				v.sync(u)
				v.selected = (u.id == selected)
	board_view.board = s.board.duplicate()


func _dur(t: float) -> float:
	return t * (0.05 if fast else 1.0)


func _tween() -> Tween:
	return create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play(ev: Array[Event]) -> void:
	for e in ev:
		await _play_one(e)
	_sync_views()
	refresh()


func _view(uid: int) -> UnitView:
	return views.get(uid, null)


func _play_one(e: Event) -> void:
	var v := _view(e.unit_id)
	var b := board_view.board
	match e.type:
		"phase_a":
			await _banner("ENEMY TURN %d" % e.amount)
		"phase_b":
			await _banner("ENEMIES ATTACK")
		"moved", "undo_move":
			Sfx.play("move")
			if v:
				var tw := _tween()
				tw.tween_property(v, "position", BoardView.center(e.to), _dur(0.22))
				await tw.finished
		"pushed":
			if v:
				var tw := _tween()
				tw.tween_property(v, "position", BoardView.center(e.to), _dur(0.14))
				await tw.finished
		"bumped":
			Sfx.play("bump")
			if v:
				var a := BoardView.center(e.pos)
				var tw := _tween()
				tw.tween_property(v, "position", a.lerp(BoardView.center(e.to), 0.3), _dur(0.07))
				tw.tween_property(v, "position", a, _dur(0.1))
				await tw.finished
				shake = 4.0
		"swapped":
			Sfx.play("swap")
			var other := _view(e.amount)
			var tw := _tween().set_parallel(true)
			if v:
				tw.tween_property(v, "position", BoardView.center(e.to), _dur(0.2))
			if other:
				tw.tween_property(other, "position", BoardView.center(e.pos), _dur(0.2))
			await tw.finished
		"attack":
			Sfx.play("shell" if e.info in ["arc_shell", "rocket", "cluster", "scarab"] else "punch")
			if v:
				var a := v.position
				var dir := (BoardView.center(e.to) - a).normalized()
				var tw := _tween()
				tw.tween_property(v, "position", a + dir * 12.0, _dur(0.06))
				tw.tween_property(v, "position", a, _dur(0.08))
				await tw.finished
		"damaged":
			Sfx.play("damage", 0.9 + 0.1 * e.amount)
			if v:
				v.hp = maxi(0, v.hp - e.amount)
				var tw := _tween()
				v.flash = 1.0
				tw.tween_property(v, "flash", 0.0, _dur(0.25))
				_float_text(BoardView.center(e.pos), "-%d" % e.amount, Pal.c("preview_damage"))
				shake = maxf(shake, 3.0 + e.amount)
				if e.amount >= 2:
					await _hit_pause(0.07)
				await _pause(0.12)
		"destroyed", "disabled", "drowned", "fell":
			if e.type == "drowned" or e.type == "fell":
				Sfx.play("drown")
			await _hit_pause(0.09)
			if v and is_instance_valid(v):
				var tw := _tween().set_parallel(true)
				tw.tween_property(v, "scale", Vector2(0.2, 0.2), _dur(0.25))
				tw.tween_property(v, "modulate:a", 0.0, _dur(0.25))
				await tw.finished
				v.visible = false
		"exploded":
			Sfx.play("explode")
			_float_text(BoardView.center(e.pos), "BOOM", Pal.c("fire"))
			shake = 8.0
			await _pause(0.12)
		"spawned":
			Sfx.play("spawn")
			var u := mission.state.get_unit(e.unit_id)
			if u and not views.has(u.id):
				var nv := _add_view(u)
				nv.scale = Vector2(0.1, 0.1)
				var tw := _tween()
				tw.tween_property(nv, "scale", Vector2.ONE, _dur(0.2))
				await tw.finished
		"spawn_blocked":
			_float_text(BoardView.center(e.pos), "BLOCKED", Pal.c("accent"))
			await _pause(0.15)
		"grid_lost":
			Sfx.play("grid")
			b.hp[b.idx(e.pos)] = maxi(0, b.hp[b.idx(e.pos)] - 1)
			_float_text(BoardView.center(e.pos), "-1 GRID", Pal.c("preview_grid"))
			shake = 10.0
			await _pause(0.2)
		"grid_resisted":
			Sfx.play("resist")
			_float_text(BoardView.center(e.pos), "RESISTED", Pal.c("good"))
			await _pause(0.2)
		"building_destroyed", "mountain_destroyed":
			b.set_t(e.pos, Board.Terrain.GROUND)
			b.rubble[b.idx(e.pos)] = 1
		"mountain_damaged":
			b.hp[b.idx(e.pos)] = e.amount
		"fire_started":
			Sfx.play("fire")
			b.fire[b.idx(e.pos)] = 1
		"caught_fire":
			if v:
				v.burning = true
				v.queue_redraw()
		"burn":
			_float_text(BoardView.center(e.pos), "BURN", Pal.c("fire"))
		"mission_won":
			Sfx.play("win")
			await _banner("MISSION COMPLETE")
		"mission_lost":
			Sfx.play("lose")
			await _banner("MISSION FAILED")


## Freeze-frame on big hits: time slows to a crawl for a few real milliseconds.
func _hit_pause(t: float) -> void:
	if fast:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _pause(t: float) -> void:
	if fast:
		return
	await get_tree().create_timer(t).timeout


func _banner(text: String) -> void:
	if fast:
		return
	banner.text = text
	banner.visible = true
	await _pause(0.6)
	banner.visible = false


func _float_text(at: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Pal.c("shadow"))
	l.add_theme_constant_override("outline_size", 6)
	l.position = ORIGIN + at + Vector2(-20, -40)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		board_view.position = ORIGIN + off
		units_layer.position = ORIGIN + off
		overlay.position = ORIGIN + off
	for id in views:
		var v: UnitView = views[id]
		if is_instance_valid(v):
			v.selected = (id == selected)


func _show_result() -> void:
	if result_panel != null:
		return
	var s := mission.state
	result_panel = UI.panel()
	result_panel.position = Vector2(400, 260)
	result_panel.custom_minimum_size = Vector2(480, 200)
	hud.get_child(0).add_child(result_panel)
	var v := VBoxContainer.new()
	result_panel.add_child(v)
	var won := s.status == GameState.Status.WON
	v.add_child(UI.label("MISSION COMPLETE" if won else "MISSION FAILED", 30, "good" if won else "bad"))
	v.add_child(UI.label("Enemies killed: %d   Mech damage taken: %d   Grid: %d" % [s.kills, s.mech_damage, s.grid_power], 16))
	v.add_child(UI.button("Continue", func() -> void: finished.emit(won), 200))
