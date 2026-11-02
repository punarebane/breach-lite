class_name UI
extends RefCounted
## Small helpers to build a consistent code-only UI from the palette.


static func theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.c("panel")
	sb.border_color = Pal.c("panel_border")
	sb.set_border_width_all(2)
	sb.shadow_color = Pal.c("shadow")
	sb.shadow_offset = Vector2(5, 6)
	sb.shadow_size = 0
	sb.set_content_margin_all(12)
	th.set_stylebox("panel", "PanelContainer", sb)
	var b := StyleBoxFlat.new()
	b.bg_color = Pal.c("panel_border")
	b.set_content_margin_all(8)
	b.shadow_color = Pal.c("shadow")
	b.shadow_offset = Vector2(3, 4)
	var bh := b.duplicate()
	bh.bg_color = Pal.c("mech_dark")
	var bp := b.duplicate()
	bp.bg_color = Pal.c("mech")
	var bd := b.duplicate()
	bd.bg_color = Pal.c("panel")
	th.set_stylebox("normal", "Button", b)
	th.set_stylebox("hover", "Button", bh)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Pal.c("text"))
	th.set_color("font_disabled_color", "Button", Pal.c("text_dim"))
	th.set_color("font_color", "Label", Pal.c("text"))
	th.set_color("default_color", "RichTextLabel", Pal.c("text"))
	return th


static func label(text: String, size: int = 18, color_name: String = "text") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Pal.c(color_name))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(min_w, 40)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func panel() -> PanelContainer:
	return PanelContainer.new()
