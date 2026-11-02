class_name Mission
extends RefCounted
## Turn-flow controller around a GameState: phases, undo, reset turn, previews.
## Pure logic; the presentation layer calls this and plays back the events.

var state: GameState
var turn_snapshot: GameState
var reset_available: bool = true
## uid -> {"from": Vector2i, "burning": bool}
var undo_info: Dictionary = {}


func _init(p_state: GameState) -> void:
	state = p_state


## Enemy phase A: enemies move + telegraph, spawn points are marked.
func begin_turn() -> Array[Event]:
	var ev: Array[Event] = []
	ev.append(Event.new("phase_a", -1, Vector2i(-1, -1), Vector2i(-1, -1), state.turn))
	ev.append_array(EnemyAI.plan_turn(state))
	ev.append_array(Spawner.mark(state))
	undo_info.clear()
	turn_snapshot = state.duplicate()
	return ev


func move(uid: int, to: Vector2i) -> Array[Event]:
	var u := state.get_unit(uid)
	var info := {"from": u.pos if u else Vector2i.ZERO, "burning": u.burning if u else false}
	var ev := Resolver.apply(state, Action.move(uid, to))
	if not ev.is_empty() and ev[0].type == "moved":
		undo_info[uid] = info
	return ev


func can_undo(uid: int) -> bool:
	var u := state.get_unit(uid)
	if u == null or not u.alive or u.has_acted or not undo_info.has(uid):
		return false
	var other := state.unit_at(undo_info[uid]["from"])
	return other == null or other == u


func undo(uid: int) -> Array[Event]:
	var ev: Array[Event] = []
	if not can_undo(uid):
		return ev
	var u := state.get_unit(uid)
	var from := u.pos
	u.pos = undo_info[uid]["from"]
	u.burning = undo_info[uid]["burning"]
	u.has_moved = false
	undo_info.erase(uid)
	ev.append(Event.new("undo_move", uid, from, u.pos))
	return ev


func attack(uid: int, slot: int, target: Vector2i) -> Array[Event]:
	var ev := Resolver.apply(state, Action.attack(uid, slot, target))
	undo_info.erase(uid)
	return ev


## Preview = the same resolver on a deep copy. Returns [events, resulting state].
func preview(a: Action) -> Array:
	var copy := state.duplicate()
	var ev := Resolver.apply(copy, a)
	return [ev, copy]


func can_reset() -> bool:
	return reset_available and turn_snapshot != null and state.is_playing()


func reset_turn() -> bool:
	if not can_reset():
		return false
	state = turn_snapshot.duplicate()
	reset_available = false
	undo_info.clear()
	return true


## Enemy phase B + spawns, then (if the mission continues) the next phase A.
func end_turn() -> Array[Event]:
	var ev := Resolver.apply(state, Action.end_turn())
	if state.is_playing():
		ev.append_array(begin_turn())
	return ev
