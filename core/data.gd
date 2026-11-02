class_name Data
extends RefCounted
## Loads and caches the JSON tuning files in res://data. Pure logic, no nodes.

static var _cache: Dictionary = {}


static func load_json(name: String) -> Variant:
	if _cache.has(name):
		return _cache[name]
	var path := "res://data/%s.json" % name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Data: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Data: bad JSON in %s" % path)
		parsed = {}
	_cache[name] = parsed
	return parsed


static func rules() -> Dictionary:
	return load_json("rules")


static func rule(key: String) -> Variant:
	return rules()[key]


static func ai() -> Dictionary:
	return load_json("ai")


static func weapons() -> Dictionary:
	return load_json("weapons")


static func mechs() -> Dictionary:
	return load_json("mechs")


static func enemies() -> Dictionary:
	return load_json("enemies")


static func islands() -> Array:
	return load_json("islands")


static func run_cfg() -> Dictionary:
	return load_json("run")


const WEAPON_DEFAULTS := {
	"name": "?", "desc": "", "targeting": "melee", "range_min": 1, "range_max": 1, "damage": 0,
	"push": "none", "pierce": 1, "push_adjacent": false, "adjacent_damage": 0, "ignite": false,
}


static func _with_defaults(d: Dictionary) -> Dictionary:
	var out := WEAPON_DEFAULTS.duplicate(true)
	for k in d:
		out[k] = d[k]
	return out


## Effective weapon definition after reactor upgrades ("damage", "range", "special").
static func weapon_def(id: String, upgrades: Array = []) -> Dictionary:
	var base: Dictionary = weapons().get(id, {})
	var w := _with_defaults(base)
	w["id"] = id
	for up in upgrades:
		match up:
			"damage":
				if w["damage"] > 0 or w["adjacent_damage"] == 0:
					w["damage"] = int(w["damage"]) + 1
				else:
					w["adjacent_damage"] = int(w["adjacent_damage"]) + 1
			"range":
				w["range_max"] = int(w["range_max"]) + 1
			"special":
				var sp: Dictionary = base.get("special", {})
				var setd: Dictionary = sp.get("set", {})
				for k in setd:
					w[k] = setd[k]
	for k in ["range_min", "range_max", "damage", "pierce", "adjacent_damage"]:
		w[k] = int(w[k])
	return w


static func enemy_weapon(kind: String) -> Dictionary:
	var e: Dictionary = enemies().get(kind, {})
	var w := _with_defaults(e.get("weapon", {}))
	w["id"] = kind
	for k in ["range_min", "range_max", "damage", "pierce", "adjacent_damage"]:
		w[k] = int(w[k])
	return w
