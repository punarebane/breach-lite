class_name BoardView
extends Node2D
## Draws the terrain grid and every overlay (ranges, telegraphs, spawns, previews).
## It only reads data handed to it; swapping this node is enough to change the renderer.

const T := 80.0

var board: Board
var spawns: Array = []
var move_tiles: Array[Vector2i] = []
var target_tiles: Array[Vector2i] = []
var hover: Vector2i = Vector2i(-1, -1)
var hover_kind: String = ""
## [{"from": Vector2i, "tiles": Array[Vector2i], "order": int, "dir": Vector2i, "target": Vector2i, "boss": bool}]
var telegraphs: Array = []
var preview: Array[Event] = []
var pulse: float = 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


static func center(p: Vector2i) -> Vector2:
	return Vector2(p.x * T + T / 2.0, p.y * T + T / 2.0)


func tile_at(local: Vector2) -> Vector2i:
	if board == null:
		return Vector2i(-1, -1)
	var p := Vector2i(floori(local.x / T), floori(local.y / T))
	return p if board.in_bounds(p) else Vector2i(-1, -1)


func _draw() -> void:
	if board == null:
		return
	# Board shadow + frame.
	draw_rect(Rect2(10, 12, board.width * T, board.height * T), Pal.c("shadow"))
	for p in board.all_tiles():
		_draw_tile(p)
	for p in board.all_tiles():
		draw_rect(Rect2(p.x * T, p.y * T, T, T), Pal.c("grid_line"), false, 1.0)
	for p in move_tiles:
		_fill(p, Pal.c("move_range"), 4)
	for p in target_tiles:
		_fill(p, Pal.c("target_range"), 4)
	if hover.x >= 0:
		var col := Pal.c("move_hover") if hover_kind == "move" else Pal.c("target_hover")
		if hover_kind != "":
			draw_rect(Rect2(hover.x * T + 3, hover.y * T + 3, T - 6, T - 6), col, false, 3.0)
		else:
			draw_rect(Rect2(hover.x * T + 2, hover.y * T + 2, T - 4, T - 4), Color(1, 1, 1, 0.25), false, 2.0)
	for s in spawns:
		_draw_spawn(s["pos"])


func _fill(p: Vector2i, col: Color, inset: float = 0.0) -> void:
	draw_rect(Rect2(p.x * T + inset, p.y * T + inset, T - inset * 2, T - inset * 2), col)


func _draw_tile(p: Vector2i) -> void:
	var o := Vector2(p.x * T, p.y * T)
	var t := board.get_t(p)
	var base := Pal.c("ground") if (p.x + p.y) % 2 == 0 else Pal.c("ground_alt")
	match t:
		Board.Terrain.GROUND:
			draw_rect(Rect2(o, Vector2(T, T)), base)
			if board.rubble[board.idx(p)]:
				for i in 4:
					var r := Vector2(12 + (i * 23) % 50, 16 + (i * 37) % 44)
					draw_rect(Rect2(o + r, Vector2(10, 8)), Pal.c("rubble"))
		Board.Terrain.MOUNTAIN:
			draw_rect(Rect2(o, Vector2(T, T)), base)
			var pts := PackedVector2Array([o + Vector2(8, T - 10), o + Vector2(T / 2, 10), o + Vector2(T - 8, T - 10)])
			draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(6, 6), pts[1] + Vector2(6, 6), pts[2] + Vector2(6, 6)]), Pal.c("shadow"))
			draw_colored_polygon(pts, Pal.c("mountain"))
			draw_colored_polygon(PackedVector2Array([o + Vector2(T / 2, 10), o + Vector2(T / 2 + 12, 30), o + Vector2(T / 2 - 12, 30)]), Pal.c("mountain_top"))
			if board.get_hp(p) < int(Data.rule("mountain_hp")):
				draw_line(o + Vector2(T / 2 - 6, 34), o + Vector2(T / 2 + 8, 56), Pal.c("shadow"), 3.0)
		Board.Terrain.WATER:
			draw_rect(Rect2(o, Vector2(T, T)), Pal.c("water"))
			for i in 3:
				var y := 18.0 + i * 22.0 + sin(pulse * 2.0 + p.x + i) * 2.0
				draw_line(o + Vector2(14, y), o + Vector2(T - 14, y), Pal.c("water_light"), 2.0)
		Board.Terrain.CHASM:
			draw_rect(Rect2(o, Vector2(T, T)), Pal.c("chasm"))
			draw_rect(Rect2(o + Vector2(4, 4), Vector2(T - 8, 8)), Pal.c("shadow"))
		Board.Terrain.FOREST:
			draw_rect(Rect2(o, Vector2(T, T)), Pal.c("forest"))
			for c: Vector2 in [Vector2(24, 26), Vector2(54, 30), Vector2(38, 54)]:
				draw_circle(o + c + Vector2(4, 4), 13, Pal.c("shadow"))
				draw_circle(o + c, 13, Pal.c("forest_tree"))
		Board.Terrain.BUILDING, Board.Terrain.OBJECTIVE:
			draw_rect(Rect2(o, Vector2(T, T)), base)
			var roof := Pal.c("objective") if t == Board.Terrain.OBJECTIVE else Pal.c("building_roof")
			draw_rect(Rect2(o + Vector2(16, 18), Vector2(T - 26, T - 26)), Pal.c("shadow"))
			draw_rect(Rect2(o + Vector2(10, 10), Vector2(T - 26, T - 26)), Pal.c("building"))
			draw_rect(Rect2(o + Vector2(10, 10), Vector2(T - 26, 14)), roof)
			for i in board.get_hp(p):
				draw_rect(Rect2(o + Vector2(16 + i * 14, T - 30), Vector2(10, 10)), Pal.c("grid_power"))
	if board.is_burning(p):
		for c: Vector2 in [Vector2(20, 60), Vector2(58, 58), Vector2(40, 46)]:
			var f := o + c + Vector2(0, sin(pulse * 8.0 + c.x) * 2.0)
			draw_colored_polygon(PackedVector2Array([f + Vector2(0, -16), f + Vector2(7, 0), f + Vector2(0, 5), f + Vector2(-7, 0)]), Pal.c("fire"))
			draw_circle(f, 3.5, Pal.c("fire_core"))


func _draw_spawn(p: Vector2i) -> void:
	var c := center(p)
	var a := 0.5 + 0.5 * sin(pulse * 4.0)
	var col := Pal.c("spawn")
	col.a *= 0.6 + 0.4 * a
	draw_circle(c, 24, Color(Pal.c("chasm"), 0.55))
	for i in 8:
		var a0 := TAU * i / 8.0 + pulse
		draw_arc(c, 28, a0, a0 + TAU / 16.0, 4, col, 5.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -6), c + Vector2(9, -6), c + Vector2(0, 8)]), col)


## Telegraphs are drawn above units by an overlay node (see OverlayView).
func draw_telegraphs(canvas: CanvasItem) -> void:
	var badge_count := {}
	for tg in telegraphs:
		var col := Pal.c("telegraph")
		col.a = 0.75 + 0.25 * sin(pulse * 5.0)
		var from: Vector2 = center(tg["from"])
		var tiles: Array = tg["tiles"]
		for p in tiles:
			var r := Rect2(p.x * T + 6, p.y * T + 6, T - 12, T - 12)
			var fillc := col
			fillc.a = 0.22
			canvas.draw_rect(r, fillc)
			canvas.draw_rect(r, col, false, 3.0)
		var tgt: Vector2 = center(tg["target"])
		var dir := (tgt - from).normalized()
		if dir != Vector2.ZERO:
			var start := from + dir * 22.0
			var end := tgt - dir * 16.0
			canvas.draw_line(start, end, col, 4.0)
			var side := Vector2(-dir.y, dir.x)
			canvas.draw_colored_polygon(PackedVector2Array([end + dir * 12.0, end + side * 8.0, end - side * 8.0]), col)
		# Order badge.
		var n: int = badge_count.get(tg["target"], 0)
		badge_count[tg["target"]] = n + 1
		var bpos := tgt + Vector2(-T / 2 + 14 + n * 24, -T / 2 + 14)
		canvas.draw_circle(bpos + Vector2(2, 2), 12, Pal.c("shadow"))
		canvas.draw_circle(bpos, 12, Pal.c("telegraph"))
		canvas.draw_string(font, bpos + Vector2(-5, 6), str(tg["order"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Pal.c("telegraph_badge"))


func draw_preview(canvas: CanvasItem) -> void:
	var dmg := {}
	for e in preview:
		match e.type:
			"damaged":
				dmg[e.pos] = int(dmg.get(e.pos, 0)) + e.amount
			"pushed":
				_arrow(canvas, center(e.pos), center(e.to), Pal.c("preview_push"), false)
			"bumped":
				_arrow(canvas, center(e.pos), center(e.to), Pal.c("preview_push"), true)
			"swapped":
				_arrow(canvas, center(e.pos), center(e.to), Pal.c("mech"), false)
				_arrow(canvas, center(e.to), center(e.pos), Pal.c("mech"), false)
			"grid_lost":
				var r := Rect2(e.pos.x * T + 4, e.pos.y * T + 4, T - 8, T - 8)
				canvas.draw_rect(r, Pal.c("preview_grid"), false, 4.0)
				canvas.draw_string(font, center(e.pos) + Vector2(-22, 8), "-1 GRID", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.c("preview_grid"))
			"grid_resisted":
				canvas.draw_arc(center(e.pos), 30, 0, TAU, 24, Pal.c("good"), 4.0)
				canvas.draw_string(font, center(e.pos) + Vector2(-26, 8), "RESIST", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.c("good"))
			"fire_started", "caught_fire":
				var f := center(e.pos) + Vector2(-24, 22)
				canvas.draw_colored_polygon(PackedVector2Array([f + Vector2(0, -14), f + Vector2(7, 0), f + Vector2(0, 5), f + Vector2(-7, 0)]), Pal.c("fire"))
			"destroyed", "disabled", "drowned", "fell":
				_skull(canvas, center(e.pos))
	for p in dmg:
		var c := center(p) + Vector2(18, -20)
		canvas.draw_circle(c + Vector2(2, 2), 14, Pal.c("shadow"))
		canvas.draw_circle(c, 14, Pal.c("preview_damage"))
		canvas.draw_string(font, c + Vector2(-10, 6), "-%d" % dmg[p], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _arrow(canvas: CanvasItem, a: Vector2, b: Vector2, col: Color, blocked: bool) -> void:
	var dir := (b - a).normalized()
	var end := a + (b - a) * (0.5 if blocked else 0.85)
	canvas.draw_line(a + dir * 10.0, end, Pal.c("shadow"), 8.0)
	canvas.draw_line(a + dir * 10.0, end, col, 5.0)
	var side := Vector2(-dir.y, dir.x)
	if blocked:
		canvas.draw_line(end + side * 14.0, end - side * 14.0, Pal.c("preview_damage"), 6.0)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([end + dir * 14.0, end + side * 10.0, end - side * 10.0]), col)


func _skull(canvas: CanvasItem, c: Vector2) -> void:
	c += Vector2(0, -4)
	canvas.draw_circle(c + Vector2(2, 3), 16, Pal.c("shadow"))
	canvas.draw_circle(c, 16, Pal.c("preview_death"))
	canvas.draw_rect(Rect2(c + Vector2(-9, 8), Vector2(18, 10)), Pal.c("preview_death"))
	canvas.draw_circle(c + Vector2(-6, -2), 5, Pal.c("background"))
	canvas.draw_circle(c + Vector2(6, -2), 5, Pal.c("background"))
