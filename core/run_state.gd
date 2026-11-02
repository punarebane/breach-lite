class_name RunState
extends RefCounted
## A whole run: 4 islands x 2 missions, a shop after each island, then the 2-phase
## Hive Queen finale. Serialisable to JSON for save/continue.

const SAVE_PATH := "user://save.json"
const FINAL_ISLAND := 4

var seed: int = 1
var grid_power: int = 7
var reputation: int = 0
var island: int = 0
var mission_idx: int = 0
var final_phase: int = 1
var squad: Array = []
var status: String = "playing"
var shop_pending: bool = false
var shop_items: Array = []
var history: Array = []


static func new_run(seed_value: int) -> RunState:
	var r := RunState.new()
	r.seed = seed_value
	r.grid_power = int(Data.rule("start_grid"))
	for k in Data.run_cfg()["squad"]:
		var weapons: Array = []
		for w in Data.mechs()[k]["weapons"]:
			weapons.append({"id": w, "upgrades": []})
		r.squad.append({"kind": k, "weapons": weapons})
	return r


func is_final() -> bool:
	return island >= FINAL_ISLAND


func mission_seed() -> int:
	return seed * 1000 + island * 37 + mission_idx * 7 + final_phase


func mission_title() -> String:
	if is_final():
		return "HIVE %d/2" % final_phase
	return "%s %d/2" % [String(Data.islands()[island]["name"]).to_upper(), mission_idx + 1]


func build_mission() -> GameState:
	if is_final():
		return MissionGen.generate(-1, 0, mission_seed(), grid_power, squad.duplicate(true), final_phase)
	return MissionGen.generate(island, mission_idx, mission_seed(), grid_power, squad.duplicate(true))


static func bonus_met(s: GameState) -> bool:
	var cfg := Data.run_cfg()
	match String(s.mission.get("bonus", "")):
		"kills":
			return s.kills >= int(cfg["bonus_kills"])
		"objective":
			return not s.objective_lost
		"no_damage":
			return s.mech_damage <= int(cfg["bonus_max_mech_damage"])
	return false


## Record a finished mission and advance. Returns a report dictionary.
func complete_mission(s: GameState) -> Dictionary:
	var cfg := Data.run_cfg()
	var won := s.status == GameState.Status.WON
	var bonus := won and bonus_met(s)
	var rep := 0
	if won:
		rep += int(cfg["rep_per_mission"])
		if bonus:
			rep += int(cfg["rep_per_bonus"])
	var report := {"island": island, "mission": mission_idx, "phase": final_phase, "won": won, "bonus": bonus,
		"bonus_type": s.mission.get("bonus", ""), "rep": rep, "grid_before": grid_power, "grid_after": s.grid_power,
		"kills": s.kills, "mech_damage": s.mech_damage, "turns": s.turn - 1, "lost_reason": s.lost_reason}
	history.append(report)
	grid_power = s.grid_power
	reputation += rep
	if not won:
		status = "lost"
		return report
	if is_final():
		if final_phase >= 2:
			status = "won"
		else:
			final_phase += 1
		return report
	mission_idx += 1
	if mission_idx >= int(cfg["missions_per_island"]):
		mission_idx = 0
		island += 1
		shop_pending = true
		shop_items = roll_shop()
	return report


# --- shop --------------------------------------------------------------------

func roll_shop() -> Array:
	var cfg := Data.run_cfg()
	var rng := SeededRng.new(seed * 7 + island * 101)
	var items: Array = [{"type": "grid", "cost": int(cfg["cost_grid"])}]
	var pool: Array = []
	# Reactor cores: an upgrade a squad weapon accepts but doesn't have yet.
	for mi in squad.size():
		var weapons: Array = squad[mi]["weapons"]
		for si in weapons.size():
			var w: Dictionary = weapons[si]
			for up in Data.weapons()[w["id"]].get("upgrades", []):
				if not (up in w["upgrades"]):
					pool.append({"type": "reactor", "cost": int(cfg["cost_reactor"]), "mech": mi, "slot": si, "upgrade": up, "weapon": w["id"]})
	rng.shuffle(pool)
	var reactors: Array = pool.slice(0, 2)
	var owned := {}
	for m in squad:
		for w in m["weapons"]:
			owned[w["id"]] = true
	var wpool: Array = []
	var ids := Data.weapons().keys()
	ids.sort()
	for id in ids:
		if not owned.has(id):
			wpool.append({"type": "weapon", "cost": int(cfg["cost_weapon"]), "weapon": id})
	rng.shuffle(wpool)
	items.append_array(reactors)
	items.append_array(wpool.slice(0, int(cfg["shop_offers"]) - reactors.size() + 1))
	return items


func can_buy(item: Dictionary) -> bool:
	if item.get("sold", false) or reputation < int(item["cost"]):
		return false
	if item["type"] == "grid":
		return grid_power < int(Data.rule("max_grid"))
	return true


## mech_index is only used for weapons (slot 2 is filled, or replaced if full).
func buy(i: int, mech_index: int = -1) -> bool:
	if i < 0 or i >= shop_items.size():
		return false
	var item: Dictionary = shop_items[i]
	if not can_buy(item):
		return false
	match String(item["type"]):
		"grid":
			grid_power = mini(grid_power + 1, int(Data.rule("max_grid")))
		"reactor":
			var w: Dictionary = squad[int(item["mech"])]["weapons"][int(item["slot"])]
			w["upgrades"].append(item["upgrade"])
		"weapon":
			if mech_index < 0 or mech_index >= squad.size():
				return false
			var weapons: Array = squad[mech_index]["weapons"]
			var entry := {"id": item["weapon"], "upgrades": []}
			if weapons.size() < 2:
				weapons.append(entry)
			else:
				weapons[1] = entry
	reputation -= int(item["cost"])
	item["sold"] = true
	return true


func leave_shop() -> void:
	shop_pending = false
	shop_items = []


static func item_text(item: Dictionary) -> String:
	match String(item["type"]):
		"grid":
			return "+1 Grid Power"
		"reactor":
			var w: Dictionary = Data.weapons()[item["weapon"]]
			var up := String(item["upgrade"])
			var what := "+1 damage" if up == "damage" else ("+1 range" if up == "range" else String(w["special"]["name"]) + ": " + String(w["special"]["desc"]))
			return "Reactor core: %s %s" % [w["name"], what]
		"weapon":
			var w: Dictionary = Data.weapons()[item["weapon"]]
			return "Weapon: %s. %s" % [w["name"], w["desc"]]
	return "?"


# --- save / load -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": 1, "seed": seed, "grid_power": grid_power, "reputation": reputation, "island": island,
		"mission_idx": mission_idx, "final_phase": final_phase, "squad": squad, "status": status,
		"shop_pending": shop_pending, "shop_items": shop_items, "history": history}


static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.seed = int(d["seed"])
	r.grid_power = int(d["grid_power"])
	r.reputation = int(d["reputation"])
	r.island = int(d["island"])
	r.mission_idx = int(d["mission_idx"])
	r.final_phase = int(d["final_phase"])
	r.squad = d["squad"].duplicate(true)
	for m in r.squad:
		for w in m["weapons"]:
			w["upgrades"] = Array(w["upgrades"])
	r.status = String(d["status"])
	r.shop_pending = bool(d["shop_pending"])
	r.shop_items = d.get("shop_items", []).duplicate(true)
	for it in r.shop_items:
		for k in ["cost", "mech", "slot"]:
			if it.has(k):
				it[k] = int(it[k])
	r.history = d.get("history", []).duplicate(true)
	for h in r.history:
		for k in h:
			if h[k] is float:
				h[k] = int(h[k])
	return r


func save(path: String = SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "  "))
	return true


static func has_save(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var r := load_run(path)
	return r != null and r.status == "playing"


static func load_run(path: String = SAVE_PATH) -> RunState:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return null
	return from_dict(d)


static func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
