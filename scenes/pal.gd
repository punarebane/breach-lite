class_name Pal
extends RefCounted
## Colours come only from data/palette.json.

static var _colors: Dictionary = {}


static func c(name: String) -> Color:
	if _colors.is_empty():
		var raw: Dictionary = Data.load_json("palette")
		for k in raw:
			_colors[k] = Color.html(String(raw[k]))
	return _colors.get(name, Color.MAGENTA)
