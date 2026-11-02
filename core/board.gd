class_name Board
extends RefCounted
## Terrain grid. Pure data + queries.

enum Terrain { GROUND, MOUNTAIN, WATER, CHASM, FOREST, BUILDING, OBJECTIVE }

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const TERRAIN_NAMES := ["ground", "mountain", "water", "chasm", "forest", "building", "objective"]

var width: int = 7
var height: int = 7
var terrain: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var fire: PackedByteArray = PackedByteArray()
var rubble: PackedByteArray = PackedByteArray()


func _init(w: int = 7, h: int = 7) -> void:
	width = w
	height = h
	terrain.resize(w * h)
	terrain.fill(Terrain.GROUND)
	hp.resize(w * h)
	hp.fill(0)
	fire.resize(w * h)
	fire.fill(0)
	rubble.resize(w * h)
	rubble.fill(0)


func duplicate() -> Board:
	var b := Board.new(width, height)
	b.terrain = terrain.duplicate()
	b.hp = hp.duplicate()
	b.fire = fire.duplicate()
	b.rubble = rubble.duplicate()
	return b


func idx(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func get_t(p: Vector2i) -> int:
	return terrain[idx(p)]


func set_t(p: Vector2i, t: int, tile_hp: int = -1) -> void:
	var i := idx(p)
	terrain[i] = t
	if tile_hp >= 0:
		hp[i] = tile_hp
	elif t == Terrain.MOUNTAIN:
		hp[i] = int(Data.rule("mountain_hp"))
	elif t == Terrain.BUILDING or t == Terrain.OBJECTIVE:
		hp[i] = 1
	else:
		hp[i] = 0
	if t != Terrain.GROUND and t != Terrain.FOREST:
		fire[i] = 0


func get_hp(p: Vector2i) -> int:
	return hp[idx(p)]


func is_burning(p: Vector2i) -> bool:
	return fire[idx(p)] != 0


## Mountains, buildings and objectives block movement and pushes.
func is_blocking(p: Vector2i) -> bool:
	var t := get_t(p)
	return t == Terrain.MOUNTAIN or t == Terrain.BUILDING or t == Terrain.OBJECTIVE


func is_building(p: Vector2i) -> bool:
	var t := get_t(p)
	return t == Terrain.BUILDING or t == Terrain.OBJECTIVE


## Can a ground unit stand here?
func is_ground_standable(p: Vector2i) -> bool:
	var t := get_t(p)
	return t == Terrain.GROUND or t == Terrain.FOREST


func all_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			out.append(Vector2i(x, y))
	return out


func count_buildings() -> int:
	var n := 0
	for t in terrain:
		if t == Terrain.BUILDING or t == Terrain.OBJECTIVE:
			n += 1
	return n
