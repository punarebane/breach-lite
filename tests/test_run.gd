extends GutTest

const FX := preload("res://tests/fx.gd")
const TMP := "user://test_save.json"


func _won_state(r: RunState, kills: int = 0, mech_damage: int = 0) -> GameState:
	var s := r.build_mission()
	s.status = GameState.Status.WON
	s.kills = kills
	s.mech_damage = mech_damage
	return s


func test_new_run_defaults() -> void:
	var r := RunState.new_run(5)
	assert_eq(r.grid_power, 7)
	assert_eq(r.squad.size(), 3)
	assert_eq(r.squad[0]["weapons"][0]["id"], "punch")
	assert_eq(r.island, 0)


func test_run_progression_islands_then_final() -> void:
	var r := RunState.new_run(5)
	var titles: Array = []
	var guard := 0
	while r.status == "playing" and guard < 20:
		guard += 1
		if r.shop_pending:
			r.leave_shop()
		titles.append(r.mission_title())
		r.complete_mission(_won_state(r))
	assert_eq(r.status, "won")
	assert_eq(titles.size(), 10, "4 islands x 2 + 2 final phases")
	assert_eq(titles[8], "HIVE 1/2")
	assert_eq(titles[9], "HIVE 2/2")


func test_shop_after_each_island() -> void:
	var r := RunState.new_run(5)
	r.complete_mission(_won_state(r))
	assert_false(r.shop_pending)
	r.complete_mission(_won_state(r))
	assert_true(r.shop_pending)
	assert_eq(r.island, 1)
	assert_gt(r.shop_items.size(), 2)
	assert_eq(r.shop_items[0]["type"], "grid")


func test_lost_mission_ends_run() -> void:
	var r := RunState.new_run(5)
	var s := r.build_mission()
	s.status = GameState.Status.LOST
	s.grid_power = 0
	r.complete_mission(s)
	assert_eq(r.status, "lost")


func test_bonus_objectives() -> void:
	var s := FX.state()
	s.mission = {"bonus": "kills"}
	s.kills = 7
	assert_true(RunState.bonus_met(s))
	s.kills = 6
	assert_false(RunState.bonus_met(s))
	s.mission = {"bonus": "objective"}
	assert_true(RunState.bonus_met(s))
	s.objective_lost = true
	assert_false(RunState.bonus_met(s))
	s.mission = {"bonus": "no_damage"}
	s.mech_damage = 1
	assert_true(RunState.bonus_met(s))
	s.mech_damage = 2
	assert_false(RunState.bonus_met(s))


func test_reputation_awarded() -> void:
	var r := RunState.new_run(5)
	var s := _won_state(r, 7, 0)
	s.mission["bonus"] = "kills"
	var rep := r.complete_mission(s)
	assert_true(rep["bonus"])
	assert_eq(r.reputation, 2)


func test_grid_carries_between_missions() -> void:
	var r := RunState.new_run(5)
	var s := _won_state(r)
	s.grid_power = 4
	r.complete_mission(s)
	assert_eq(r.build_mission().grid_power, 4)


func test_shop_buy_grid_and_cap() -> void:
	var r := RunState.new_run(5)
	r.reputation = 20
	r.shop_items = r.roll_shop()
	r.grid_power = int(Data.rule("max_grid")) - 1
	assert_true(r.buy(0))
	assert_eq(r.grid_power, int(Data.rule("max_grid")))
	assert_eq(r.reputation, 20 - int(Data.run_cfg()["cost_grid"]))
	assert_false(r.buy(0), "sold out")


func test_shop_buy_weapon_fills_second_slot() -> void:
	var r := RunState.new_run(5)
	r.reputation = 20
	r.shop_items = r.roll_shop()
	var idx := -1
	for i in r.shop_items.size():
		if r.shop_items[i]["type"] == "weapon":
			idx = i
	assert_gt(idx, -1)
	assert_true(r.buy(idx, 0))
	assert_eq(r.squad[0]["weapons"].size(), 2)
	var s := r.build_mission()
	assert_eq(s.mechs()[0].weapons.size(), 2, "mission mechs get the new weapon")


func test_shop_reactor_upgrade_applies() -> void:
	var r := RunState.new_run(5)
	r.reputation = 20
	r.shop_items = r.roll_shop()
	var idx := -1
	for i in r.shop_items.size():
		if r.shop_items[i]["type"] == "reactor":
			idx = i
	assert_gt(idx, -1)
	var it: Dictionary = r.shop_items[idx]
	assert_true(r.buy(idx))
	assert_true(it["upgrade"] in r.squad[it["mech"]]["weapons"][it["slot"]]["upgrades"])


func test_save_load_roundtrip() -> void:
	var r := RunState.new_run(77)
	r.reputation = 3
	r.complete_mission(_won_state(r))
	r.complete_mission(_won_state(r))
	r.squad[1]["weapons"][0]["upgrades"].append("damage")
	assert_true(r.save(TMP))
	var l := RunState.load_run(TMP)
	assert_eq(JSON.stringify(l.to_dict()), JSON.stringify(r.to_dict()))
	assert_eq(l.build_mission().fingerprint(), r.build_mission().fingerprint(), "same next mission")
	RunState.delete_save(TMP)
	assert_false(FileAccess.file_exists(TMP))


func test_final_phase_two_kill_boss_flag() -> void:
	var r := RunState.new_run(9)
	r.island = RunState.FINAL_ISLAND
	r.final_phase = 2
	var s := r.build_mission()
	assert_true(s.mission["kill_boss"])
	assert_eq(s.enemies().filter(func(u: Unit) -> bool: return u.boss).size(), 1)


func test_objective_missions_have_four_turns() -> void:
	var found := false
	for seed_value in 60:
		var s := MissionGen.generate(0, 0, seed_value)
		if s.mission["template"] == "objective_defense":
			found = true
			assert_eq(s.max_turns, 4)
			assert_eq(s.mission["bonus"], "objective")
			var has_obj := false
			for t in s.board.terrain:
				if t == Board.Terrain.OBJECTIVE:
					has_obj = true
			assert_true(has_obj)
	assert_true(found)


func test_bot_plays_full_run() -> void:
	var r := PlayerBot.play_run(3)
	assert_ne(r.status, "playing")
	assert_gt(r.history.size(), 0)
