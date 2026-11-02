class_name SeededRng
extends RefCounted
## Tiny deterministic Park-Miller RNG. Its whole state is one int, so copying a
## GameState copies the future random sequence too (previews stay exact).

var state: int = 1


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	state = (absi(seed_value) % 1000003 * 2654435 + 97531) % 2147483646 + 1
	for i in 4:
		next_int()


func next_int() -> int:
	state = (state * 48271) % 2147483647
	return state


func randf() -> float:
	return float(next_int() - 1) / 2147483646.0


func randi_range(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	return lo + next_int() % (hi - lo + 1)


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[next_int() % arr.size()]


func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := next_int() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func copy() -> SeededRng:
	var r := SeededRng.new()
	r.state = state
	return r
