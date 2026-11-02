extends GutTest
## Signature guarantees: preview == real resolution; invariants hold under random play.


func test_preview_equals_real_for_2000_random_pairs() -> void:
	var rng := SeededRng.new(2024)
	var pairs := 0
	var mismatches := 0
	var seed_value := 0
	while pairs < 2000:
		seed_value += 1
		var m := Mission.new(MissionGen.generate(seed_value % 4, seed_value % 2, seed_value))
		m.begin_turn()
		var guard := 0
		while m.state.is_playing() and pairs < 2000 and guard < 40:
			guard += 1
			var acts := Rules.legal_player_actions(m.state)
			var a: Action
			if acts.is_empty() or rng.randf() < 0.08:
				a = Action.end_turn()
			else:
				a = acts[rng.next_int() % acts.size()]
			var pv: Array = m.preview(a)
			var copy := m.state.duplicate()
			var real := Resolver.apply(copy, a)
			pairs += 1
			var pk := Event.keys(pv[0])
			var rk := Event.keys(real)
			if pk != rk or pv[1].fingerprint() != copy.fingerprint():
				mismatches += 1
				if mismatches < 3:
					gut.p("MISMATCH %s\n preview %s\n real    %s" % [a, pk, rk])
			# Advance the real game with the same action.
			if a.kind == Action.Kind.END_TURN:
				m.end_turn()
			elif a.kind == Action.Kind.MOVE:
				m.move(a.unit_id, a.target)
			else:
				m.attack(a.unit_id, a.slot, a.target)
	assert_eq(pairs, 2000)
	assert_eq(mismatches, 0, "preview must exactly equal real resolution")


func test_invariant_fuzz_500_missions() -> void:
	var violations: Array[String] = []
	var counter := {"steps": 0}
	var outcomes := {"won": 0, "lost": 0}
	for i in 500:
		var island := i % 5 - 1
		var s: GameState
		if island < 0:
			s = MissionGen.generate(-1, 0, 1000 + i, 7, [], 1 + (i / 5) % 2)
		else:
			s = MissionGen.generate(island, i % 2, 1000 + i)
		var m := Mission.new(s)
		var rng := SeededRng.new(i)
		var check := func(st: GameState) -> void:
			counter["steps"] += 1
			for v in Invariants.check(st):
				if violations.size() < 10:
					violations.append("mission %d turn %d: %s" % [i, st.turn, v])
		m.begin_turn()
		check.call(m.state)
		var guard := 0
		while m.state.is_playing() and guard < 20:
			guard += 1
			RandomBot.play_turn(m, rng, check)
		assert_false(m.state.is_playing(), "mission %d ended" % i)
		outcomes["won" if m.state.status == GameState.Status.WON else "lost"] += 1
	gut.p("fuzz: %d steps, outcomes %s" % [counter["steps"], outcomes])
	assert_gt(counter["steps"], 5000)
	assert_eq(violations.size(), 0, "\n".join(violations))
