extends SceneTree
## Systems tests: difficulty wiring, mission fail-paths, diplomacy tick,
## event flags, tech mults, story-flag save round-trip. Headless-safe.
## Run in CI: godot --headless --path . --script res://scripts/tests/test_systems.gd

var _fails := 0

func _fail(msg: String) -> void:
	printerr("FAIL: " + msg)
	_fails += 1

func _check_difficulty() -> void:
	var g = load("res://scripts/core/game.gd").new()
	g.reset()
	if float(g.call("difficulty_plague_mult")) != 0.5:
		_fail("peaceful plague mult")
	if float(g.call("difficulty_aggression_mult")) != 0.5:
		_fail("peaceful aggression mult")
	if float(g.call("difficulty_event_mult")) != 0.6:
		_fail("peaceful event mult")
	if float(g.call("tax_rate")) != 0.0:
		_fail("tax stub nonzero")
	g.free()

func _check_mission_fail_path() -> void:
	var m = load("res://scripts/core/missions.gd").new()
	m.call("_load_all")
	var acts: Array = m.call("get_acts")
	var idx08 := -1
	for i in acts.size():
		if String((acts[i] as Dictionary).get("id", "")) == "act_08_trial":
			idx08 = i
	if idx08 < 0:
		_fail("act_08_trial not loaded")
		m.free()
		return
	m.set("current_act_idx", idx08)
	m.set("crisis_failed", 3)
	if not bool(m.call("is_act_failed")):
		_fail("is_act_failed false at 3 crises")
		m.free()
		return
	if not bool(m.call("advance_act")):
		_fail("fail-branch advance rejected")
		m.free()
		return
	var cur: Dictionary = m.call("get_current_act")
	if String(cur.get("id", "")) != "act_08_fail_recovery":
		_fail("fail-branch landed on " + String(cur.get("id", "")))
	if int(m.get("crisis_failed")) != 0:
		_fail("crisis_failed not reset after fail advance")
	m.free()

func _check_diplomacy() -> void:
	var d = load("res://scripts/core/diplomacy.gd").new()
	d.call("generate_rivals", 3, 999)
	if int(d.get("kingdoms").size()) != 3:
		_fail("rivals count")
		d.free()
		return
	d.call("tick")
	for kid in (d.get("kingdoms") as Dictionary).keys():
		var p: float = float(((d.get("kingdoms") as Dictionary)[kid] as Dictionary).get("power", 0.0))
		if p < 30.0 or p > 200.0:
			_fail("rival power out of range")
	var choice: String = String(d.call("decide", "kingdom_0"))
	if choice == "":
		_fail("decide empty")
	if float(d.call("difficulty_aggression_mult")) != 1.0:
		_fail("aggression fallback without Game")
	d.free()

func _check_events() -> void:
	var e = load("res://scripts/core/events.gd").new()
	e.call("_load")
	if (e.get("templates") as Array).size() < 100:
		_fail("event templates < 100")
		e.free()
		return
	var w: float = float(e.call("evaluate_weight", {"weight": 10.0, "category": "religious"}, {"turn": 5}))
	if w != 10.0:
		_fail("flagless weight != 10")
	var rolled: Dictionary = e.call("roll", {"turn": 5, "difficulty": "iron", "happiness": 0.6, "pop_count": 60.0, "season": "spring", "month": 3, "year": 1})
	if typeof(rolled) != TYPE_DICTIONARY:
		_fail("roll not a dict")
	e.free()

func _check_tech() -> void:
	var t = load("res://scripts/core/tech.gd").new()
	t.call("_load_catalog")
	if float(t.call("get_spoilage_mult")) != 1.0:
		_fail("spoilage base != 1")
	if float(t.call("get_military_mult")) != 1.0:
		_fail("military base != 1")
	if float(t.call("get_trade_mult")) != 1.0:
		_fail("trade base != 1")
	var spoil_id := ""
	for tid in (t.get("catalog") as Dictionary).keys():
		var bo: Variant = ((t.get("catalog") as Dictionary)[tid] as Dictionary).get("bonuses", {})
		if typeof(bo) == TYPE_DICTIONARY and (bo as Dictionary).has("spoilage_mult"):
			spoil_id = String(tid)
			break
	if spoil_id == "":
		_fail("no spoilage tech in catalog")
	else:
		(t.get("unlocked") as Array).append(spoil_id)
		if float(t.call("get_spoilage_mult")) >= 1.0:
			_fail("spoilage mult not applied")
	t.free()

func _check_storyflag_save() -> void:
	var g = load("res://scripts/core/game.gd").new()
	g.reset()
	(g.get("story_flags") as Dictionary)["smoke_flag"] = true
	var path := "user://saves/slot_test_flags.json"
	if not bool(g.call("save_to_file", path)):
		_fail("flag save failed")
		g.free()
		return
	var g2 = load("res://scripts/core/game.gd").new()
	if not bool(g2.call("load_from_file", path)):
		_fail("flag load failed")
	else:
		var sf: Variant = g2.get("story_flags")
		if typeof(sf) != TYPE_DICTIONARY or not (sf as Dictionary).has("smoke_flag"):
			_fail("story flag lost in round-trip")
	g.free()
	g2.free()

func _init() -> void:
	_check_difficulty()
	_check_mission_fail_path()
	_check_diplomacy()
	_check_events()
	_check_tech()
	_check_storyflag_save()
	if _fails > 0:
		printerr("SYSTEMS: %d failures" % _fails)
		quit(1)
		return
	print("OK: systems (difficulty, fail-path, diplomacy, events, tech, flag save)")
	quit(0)
