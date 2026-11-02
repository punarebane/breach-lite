class_name UnitView
extends Node2D
## Code-drawn unit. Holds only display state; the mission view tweens it.

const T := 80.0

var unit_id: int = -1
var kind: String = ""
var is_mech: bool = true
var boss: bool = false
var flying: bool = false
var hp: int = 1
var max_hp: int = 1
var burning: bool = false
var selected: bool = false
var spent: bool = false
var flash: float = 0.0:
	set(v):
		flash = v
		queue_redraw()
var bob: float = 0.0


func setup(u: Unit) -> void:
	unit_id = u.id
	kind = u.kind
	is_mech = u.is_mech()
	boss = u.boss
	flying = u.flying
	sync(u)


func sync(u: Unit) -> void:
	hp = u.hp
	max_hp = u.max_hp
	burning = u.burning
	spent = u.is_mech() and u.has_acted
	queue_redraw()


func _ready() -> void:
	bob = float(unit_id) * 1.7


func _process(delta: float) -> void:
	bob += delta * 3.0
	queue_redraw()


func _body_color() -> Color:
	var col := Pal.c("mech") if is_mech else (Pal.c("boss") if boss else Pal.c("enemy"))
	if spent:
		col = col.darkened(0.35)
	return col.lerp(Color.WHITE, flash)


func _draw() -> void:
	var lift := 0.0
	if flying:
		lift = -8.0 + sin(bob) * 2.0
	else:
		lift = sin(bob * 0.7) * 1.0
	var breathe := 1.0 + sin(bob * 0.7) * 0.025
	var shadow := Pal.c("shadow")
	var col := _body_color()
	var dark := (Pal.c("mech_dark") if is_mech else Pal.c("enemy_dark")).lerp(Color.WHITE, flash * 0.5)
	var s := 26.0 if not boss else 34.0
	if kind == "larva":
		s = 16.0
	# Hard shadow.
	draw_set_transform(Vector2(6, 8), 0, Vector2.ONE)
	_shape(s, shadow, shadow)
	draw_set_transform(Vector2(0, lift), 0, Vector2(breathe, 1.0 / breathe))
	_shape(s, col, dark)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if selected:
		draw_arc(Vector2.ZERO, s + 10, 0, TAU, 32, Pal.c("accent"), 3.0)
	# HP pips.
	var pw := 10.0
	var total := pw * max_hp + 2.0 * (max_hp - 1)
	var x0 := -total / 2.0
	for i in max_hp:
		var r := Rect2(x0 + i * (pw + 2.0), T / 2.0 - 14.0, pw, 6.0)
		draw_rect(r, Pal.c("hp_full") if i < hp else Pal.c("hp_empty"))
	if burning:
		_flame(Vector2(s * 0.7, -s * 0.7 + lift), 8.0)


func _flame(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.6), c + Vector2(r, 0), c + Vector2(0, r * 0.8), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, Pal.c("fire"))
	draw_circle(c + Vector2(0, r * 0.1), r * 0.45, Pal.c("fire_core"))


func _poly(n: int, r: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _shape(s: float, col: Color, dark: Color) -> void:
	match kind:
		"brawler":
			draw_rect(Rect2(-s * 0.8, -s * 0.8, s * 1.6, s * 1.6), col)
			draw_rect(Rect2(-s * 1.05, -s * 0.3, s * 0.4, s * 0.7), dark)
			draw_rect(Rect2(s * 0.65, -s * 0.3, s * 0.4, s * 0.7), dark)
			draw_rect(Rect2(-s * 0.35, -s * 0.5, s * 0.7, s * 0.3), dark)
		"artillery":
			draw_rect(Rect2(-s * 0.8, -s * 0.6, s * 1.6, s * 1.3), col)
			draw_rect(Rect2(-s * 0.15, -s * 1.1, s * 0.3, s * 0.8), dark)
			draw_circle(Vector2(0, 0), s * 0.35, dark)
		"warper":
			draw_colored_polygon(_poly(4, s * 1.0, 0.0), col)
			draw_colored_polygon(_poly(4, s * 0.45, PI / 4), dark)
		"beetle":
			for i in 3:
				var y := -s * 0.5 + i * s * 0.5
				draw_line(Vector2(-s * 1.0, y), Vector2(s * 1.0, y), dark, 4.0)
			draw_circle(Vector2.ZERO, s * 0.75, col)
			draw_circle(Vector2(0, -s * 0.55), s * 0.35, dark)
		"hornet":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.8, s * 0.7), Vector2(-s * 0.8, s * 0.7)]), col)
			draw_line(Vector2(-s, -s * 0.2), Vector2(s, -s * 0.2), dark, 5.0)
		"spitter":
			draw_circle(Vector2.ZERO, s * 0.8, col)
			draw_circle(Vector2(0, -s * 0.2), s * 0.3, dark)
			draw_rect(Rect2(-s * 0.15, -s * 1.0, s * 0.3, s * 0.5), dark)
		"scarab":
			draw_colored_polygon(_poly(6, s * 0.9, PI / 6), col)
			draw_colored_polygon(_poly(6, s * 0.4, PI / 6), dark)
		"digger":
			draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.9, -s * 0.6), Vector2(s * 0.9, -s * 0.6), Vector2(0, s * 0.9)]), col)
			draw_line(Vector2(0, -s * 0.6), Vector2(0, s * 0.6), dark, 5.0)
		"blob":
			for i in 6:
				var a := TAU * i / 6.0
				draw_circle(Vector2(cos(a), sin(a)) * s * 0.55, s * 0.4, col)
			draw_circle(Vector2.ZERO, s * 0.6, col)
			draw_circle(Vector2.ZERO, s * 0.25, dark)
		"larva":
			draw_circle(Vector2.ZERO, s, col)
			draw_circle(Vector2(0, -s * 0.3), s * 0.35, dark)
		"queen":
			draw_colored_polygon(_poly(8, s, PI / 8), col)
			draw_colored_polygon(_poly(3, s * 0.5, -PI / 2), dark)
		_:
			draw_circle(Vector2.ZERO, s * 0.8, col)
