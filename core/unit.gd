class_name Unit
extends RefCounted
## A mech or an enemy. Pure data.

enum Team { MECH, ENEMY }

var id: int = -1
var kind: String = ""
var team: Team = Team.ENEMY
var pos: Vector2i = Vector2i.ZERO
var hp: int = 1
var max_hp: int = 1
var move: int = 3
var flying: bool = false
var burrow: bool = false
var immovable: bool = false
var boss: bool = false
var explode: int = 0
var larvae: int = 0
var alive: bool = true
var burning: bool = false
## Mech weapons: [{"id": String, "upgrades": Array}], max 2 slots.
var weapons: Array = []
var has_moved: bool = false
var has_acted: bool = false
## Enemy telegraph: dir + dist relative to the attacker's CURRENT position.
var tele_dir: Vector2i = Vector2i.ZERO
var tele_dist: int = 0
var tele_order: int = 0


func is_mech() -> bool:
	return team == Team.MECH


func is_enemy() -> bool:
	return team == Team.ENEMY


func has_telegraph() -> bool:
	return tele_dist > 0 or (tele_dir != Vector2i.ZERO)


func clear_telegraph() -> void:
	tele_dir = Vector2i.ZERO
	tele_dist = 0
	tele_order = 0


func weapon_def(slot: int = 0) -> Dictionary:
	if is_enemy():
		return Data.enemy_weapon(kind)
	if slot < 0 or slot >= weapons.size():
		return {}
	var w: Dictionary = weapons[slot]
	return Data.weapon_def(w["id"], w.get("upgrades", []))


func display_name() -> String:
	if is_mech():
		return Data.mechs().get(kind, {}).get("name", kind)
	return Data.enemies().get(kind, {}).get("name", kind)


func duplicate() -> Unit:
	var u := Unit.new()
	u.id = id
	u.kind = kind
	u.team = team
	u.pos = pos
	u.hp = hp
	u.max_hp = max_hp
	u.move = move
	u.flying = flying
	u.burrow = burrow
	u.immovable = immovable
	u.boss = boss
	u.explode = explode
	u.larvae = larvae
	u.alive = alive
	u.burning = burning
	u.weapons = weapons.duplicate(true)
	u.has_moved = has_moved
	u.has_acted = has_acted
	u.tele_dir = tele_dir
	u.tele_dist = tele_dist
	u.tele_order = tele_order
	return u


static func make_mech(kind_id: String, weapon_list: Array = []) -> Unit:
	var d: Dictionary = Data.mechs()[kind_id]
	var u := Unit.new()
	u.kind = kind_id
	u.team = Team.MECH
	u.hp = int(d.get("hp", Data.rule("mech_hp")))
	u.max_hp = u.hp
	u.move = int(d["move"])
	u.flying = bool(d.get("flying", false))
	if weapon_list.is_empty():
		for w in d["weapons"]:
			u.weapons.append({"id": w, "upgrades": []})
	else:
		u.weapons = weapon_list.duplicate(true)
	return u


static func make_enemy(kind_id: String) -> Unit:
	var d: Dictionary = Data.enemies()[kind_id]
	var u := Unit.new()
	u.kind = kind_id
	u.team = Team.ENEMY
	u.hp = int(d["hp"])
	u.max_hp = u.hp
	u.move = int(d["move"])
	u.flying = bool(d.get("flying", false))
	u.burrow = bool(d.get("burrow", false))
	u.immovable = bool(d.get("immovable", false))
	u.boss = bool(d.get("boss", false))
	u.explode = int(d.get("explode", 0))
	u.larvae = int(d.get("larvae", 0))
	return u
