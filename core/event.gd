class_name Event
extends RefCounted
## One atomic thing that happened during resolution. The presentation layer only
## plays these back; previews render them as overlays.

var type: String
var unit_id: int = -1
var pos: Vector2i = Vector2i(-1, -1)
var to: Vector2i = Vector2i(-1, -1)
var amount: int = 0
var info: String = ""


func _init(p_type: String = "", p_unit_id: int = -1, p_pos: Vector2i = Vector2i(-1, -1), p_to: Vector2i = Vector2i(-1, -1), p_amount: int = 0, p_info: String = "") -> void:
	type = p_type
	unit_id = p_unit_id
	pos = p_pos
	to = p_to
	amount = p_amount
	info = p_info


func key() -> String:
	return "%s|%d|%d,%d|%d,%d|%d|%s" % [type, unit_id, pos.x, pos.y, to.x, to.y, amount, info]


func _to_string() -> String:
	return key()


static func keys(events: Array[Event]) -> PackedStringArray:
	var out := PackedStringArray()
	for e in events:
		out.append(e.key())
	return out
