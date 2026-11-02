class_name GameState
extends RefCounted
## Everything needed to resolve a mission deterministically. duplicate() is a deep
## copy, including both RNG streams, so a preview on a copy is exact.

enum Status { PLAYING, WON, LOST }

var board: Board
var units: Array[Unit] = []
var next_id: int = 1
var grid_power: int = 7
var max_grid: int = 9
var grid_rng: SeededRng = SeededRng.new(1)
var ai_rng: SeededRng = SeededRng.new(2)
var turn: int = 1
var max_turns: int = 5
## Spawn markers for the next emergence: [{"pos": Vector2i, "kind": String}]
var spawns: Array = []
var next_order: int = 1
var kills: int = 0
var mech_damage: int = 0
var objective_lost: bool = false
var status: Status = Status.PLAYING
var lost_reason: String = ""
## Mission configuration (enemy pool, spawn counts, bonus objective...). Treated as read-only.
var mission: Dictionary = {}


func _init(size: int = 7) -> void:
	board = Board.new(size, size)


func duplicate() -> GameState:
	var s := GameState.new(board.width)
	s.board = board.duplicate()
	for u in units:
		s.units.append(u.duplicate())
	s.next_id = next_id
	s.grid_power = grid_power
	s.max_grid = max_grid
	s.grid_rng = grid_rng.copy()
	s.ai_rng = ai_rng.copy()
	s.turn = turn
	s.max_turns = max_turns
	s.spawns = spawns.duplicate(true)
	s.next_order = next_order
	s.kills = kills
	s.mech_damage = mech_damage
	s.objective_lost = objective_lost
	s.status = status
	s.lost_reason = lost_reason
	s.mission = mission
	return s


func add_unit(u: Unit, p: Vector2i) -> Unit:
	u.id = next_id
	next_id += 1
	u.pos = p
	units.append(u)
	return u


func get_unit(uid: int) -> Unit:
	for u in units:
		if u.id == uid:
			return u
	return null


func unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.alive and u.pos == p:
			return u
	return null


func alive_units(team: int = -1) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.alive and (team < 0 or u.team == team):
			out.append(u)
	return out


func mechs() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.team == Unit.Team.MECH:
			out.append(u)
	return out


func enemies() -> Array[Unit]:
	return alive_units(Unit.Team.ENEMY)


func spawn_at(p: Vector2i) -> int:
	for i in spawns.size():
		if spawns[i]["pos"] == p:
			return i
	return -1


func is_playing() -> bool:
	return status == Status.PLAYING
