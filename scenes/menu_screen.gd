class_name MenuScreen
extends Control
## Main menu.

signal new_run
signal continue_run
signal tutorial


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.c("background")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var deco := MenuDeco.new()
	add_child(deco)
	var v := VBoxContainer.new()
	v.position = Vector2(120, 150)
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := UI.label("BREACH-LITE", 64, "accent")
	title.add_theme_color_override("font_shadow_color", Pal.c("shadow"))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 6)
	v.add_child(title)
	v.add_child(UI.label("Three mechs. A 7x7 city. Every attack telegraphed.\nToo few actions.", 18, "text_dim"))
	v.add_child(Control.new())
	var b_tut := UI.button("Tutorial", func() -> void: tutorial.emit(), 320)
	b_tut.name = "TutorialButton"
	v.add_child(b_tut)
	var b_new := UI.button("New run", func() -> void: new_run.emit(), 320)
	b_new.name = "NewRunButton"
	v.add_child(b_new)
	var b_cont := UI.button("Continue", func() -> void: continue_run.emit(), 320)
	b_cont.name = "ContinueButton"
	b_cont.disabled = not RunState.has_save()
	v.add_child(b_cont)
	if OS.get_name() != "Web":
		v.add_child(UI.button("Quit", func() -> void: get_tree().quit(), 320))
	print("MAIN_MENU_READY")


class MenuDeco:
	extends Node2D
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var o := Vector2(700, 120)
		var s := 64.0
		for y in 7:
			for x in 7:
				var c := Pal.c("ground") if (x + y) % 2 == 0 else Pal.c("ground_alt")
				if (x * 3 + y * 5) % 11 == 0:
					c = Pal.c("building")
				draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), c)
		var a := o + Vector2(1.5, 4.5) * s
		var b := o + Vector2(4.5, 4.5) * s
		var col := Pal.c("telegraph")
		col.a = 0.6 + 0.4 * sin(t * 4.0)
		draw_rect(Rect2(b - Vector2(16, 14), Vector2(44, 44)), Pal.c("shadow"))
		draw_rect(Rect2(b - Vector2(22, 22), Vector2(44, 44)), Pal.c("mech"))
		draw_circle(a + Vector2(6, 8), 22, Pal.c("shadow"))
		draw_circle(a, 22, Pal.c("enemy"))
		draw_line(a + Vector2(26, 0), b - Vector2(34, 0), col, 5.0)
		draw_colored_polygon(PackedVector2Array([b - Vector2(26, 0), b - Vector2(40, 10), b - Vector2(40, -10)]), col)
