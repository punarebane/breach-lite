class_name RandomBot
extends RefCounted
## Plays random legal actions. Used by the invariant fuzz.


static func play_turn(m: Mission, rng: SeededRng, on_step: Callable = Callable()) -> void:
	var steps := rng.randi_range(0, 6)
	for i in steps:
		if not m.state.is_playing():
			return
		var acts := Rules.legal_player_actions(m.state)
		if acts.is_empty():
			break
		var a: Action = acts[rng.next_int() % acts.size()]
		if a.kind == Action.Kind.MOVE:
			m.move(a.unit_id, a.target)
		else:
			m.attack(a.unit_id, a.slot, a.target)
		if rng.randf() < 0.1:
			m.undo(a.unit_id)
		if on_step.is_valid():
			on_step.call(m.state)
	if m.state.is_playing():
		m.end_turn()
		if on_step.is_valid():
			on_step.call(m.state)
