class_name Action
extends RefCounted
## A command applied by Resolver.apply(). Player and enemy commands share this type.

enum Kind { MOVE, ATTACK, ENEMY_PLAN, END_TURN }

var kind: Kind
var unit_id: int = -1
var target: Vector2i = Vector2i(-1, -1)
var slot: int = 0
var dir: Vector2i = Vector2i.ZERO
var dist: int = 0


static func move(p_unit_id: int, p_to: Vector2i) -> Action:
	var a := Action.new()
	a.kind = Kind.MOVE
	a.unit_id = p_unit_id
	a.target = p_to
	return a


static func attack(p_unit_id: int, p_slot: int, p_target: Vector2i) -> Action:
	var a := Action.new()
	a.kind = Kind.ATTACK
	a.unit_id = p_unit_id
	a.slot = p_slot
	a.target = p_target
	return a


static func enemy_plan(p_unit_id: int, p_to: Vector2i, p_dir: Vector2i, p_dist: int) -> Action:
	var a := Action.new()
	a.kind = Kind.ENEMY_PLAN
	a.unit_id = p_unit_id
	a.target = p_to
	a.dir = p_dir
	a.dist = p_dist
	return a


static func end_turn() -> Action:
	var a := Action.new()
	a.kind = Kind.END_TURN
	return a


func _to_string() -> String:
	return "Action(%s u%d t%s s%d d%s/%d)" % [Kind.keys()[kind], unit_id, target, slot, dir, dist]
