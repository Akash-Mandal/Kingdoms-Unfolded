extends SceneTree
## Catalog validation: every data/catalog/*.json parses and cross-links resolve.
## Run in CI: godot --headless --path . --script res://scripts/tests/test_catalogs.gd

var _fails := 0

func _fail(msg: String) -> void:
	printerr("FAIL: " + msg)
	_fails += 1

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("missing " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("unreadable " + path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null:
		_fail("malformed " + path)
	return parsed

func _check_main_quest() -> void:
	var parsed: Variant = _load_json("res://data/catalog/main_quest.json")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var acts: Array = (parsed as Dictionary).get("acts", [])
	if acts.size() != 11:
		_fail("main_quest acts = %d exp 11" % acts.size())
	var ids: Dictionary = {}
	for a in acts:
		if typeof(a) == TYPE_DICTIONARY:
			ids[String((a as Dictionary).get("id", ""))] = true
	for a in acts:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var ad: Dictionary = a as Dictionary
		var br: Variant = ad.get("branch", {})
		if typeof(br) != TYPE_DICTIONARY:
			_fail("act missing branch: " + String(ad.get("id", "?")))
			continue
		for key in ["success", "fail"]:
			var raw: Variant = (br as Dictionary).get(key, "")
			if raw == null:
				continue
			var target: String = str(raw)
			if target != "" and not ids.has(target):
				_fail("act %s branch.%s -> unknown %s" % [String(ad.get("id", "?")), key, target])
	var trial: Dictionary = {}
	for a in acts:
		if typeof(a) == TYPE_DICTIONARY and String((a as Dictionary).get("id", "")) == "act_08_trial":
			trial = a as Dictionary
	if trial.is_empty():
		_fail("act_08_trial missing")
	elif str((trial.get("branch", {}) as Dictionary).get("fail", "")) != "act_08_fail_recovery":
		_fail("act_08_trial has no fail recovery branch")
	if not ids.has("act_08_fail_recovery"):
		_fail("act_08_fail_recovery act missing")

func _check_missions() -> void:
	var parsed: Variant = _load_json("res://data/catalog/missions.json")
	if typeof(parsed) != TYPE_ARRAY:
		return
	var arr: Array = parsed as Array
	if arr.size() < 48:
		_fail("missions %d < 48" % arr.size())
	var ids: Dictionary = {}
	for m in arr:
		if typeof(m) == TYPE_DICTIONARY:
			ids[String((m as Dictionary).get("id", ""))] = true
	var chains := 0
	for m in arr:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var md: Dictionary = m as Dictionary
		if String(md.get("id", "")) == "":
			_fail("mission without id")
		var choices: Variant = md.get("choices", [])
		if typeof(choices) == TYPE_ARRAY:
			for ch in choices as Array:
				if typeof(ch) != TYPE_DICTIONARY:
					continue
				var raw_fu: Variant = (ch as Dictionary).get("follow_up", "")
				if raw_fu == null:
					continue
				var fu: String = str(raw_fu)
				if fu != "":
					chains += 1
					if not ids.has(fu):
						_fail("mission %s follow_up -> unknown %s" % [String(md.get("id", "?")), fu])
	if chains < 1:
		_fail("no mission follow_up chains")

func _check_events() -> void:
	var parsed: Variant = _load_json("res://data/catalog/events.json")
	if typeof(parsed) != TYPE_ARRAY:
		return
	var arr: Array = parsed as Array
	if arr.size() < 100:
		_fail("events %d < 100" % arr.size())
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var ed: Dictionary = e as Dictionary
		if String(ed.get("id", "")) == "":
			_fail("event without id")
		var choices: Variant = ed.get("choices", [])
		if typeof(choices) != TYPE_ARRAY or (choices as Array).is_empty():
			_fail("event without choices: " + String(ed.get("id", "?")))
			continue
		for ch in choices as Array:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			if typeof((ch as Dictionary).get("effects", {})) != TYPE_DICTIONARY:
				_fail("event choice without effects dict: " + String(ed.get("id", "?")))

func _check_balance() -> void:
	var parsed: Variant = _load_json("res://data/catalog/balance.json")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var diff: Variant = (parsed as Dictionary).get("difficulty", {})
	if typeof(diff) != TYPE_DICTIONARY:
		_fail("balance missing difficulty")
		return
	for dname in ["peaceful", "iron", "chaos", "legendary"]:
		var d: Variant = (diff as Dictionary).get(dname, {})
		if typeof(d) != TYPE_DICTIONARY:
			_fail("balance difficulty missing: " + dname)
			continue
		for key in ["plague_frequency", "rival_aggression", "event_severity", "production_multiplier", "consumption_multiplier", "start_resources_multiplier"]:
			if not (d as Dictionary).has(key):
				_fail("balance %s missing %s" % [dname, key])

func _check_scenarios() -> void:
	var parsed: Variant = _load_json("res://data/catalog/scenarios.json")
	if typeof(parsed) != TYPE_ARRAY:
		return
	for s in parsed as Array:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = s as Dictionary
		if String(sd.get("id", "")) == "":
			_fail("scenario without id")
		int(sd.get("duration_turns", 0))

func _check_tech() -> void:
	var parsed: Variant = _load_json("res://data/catalog/tech.json")
	if typeof(parsed) != TYPE_ARRAY:
		return
	var arr: Array = parsed as Array
	if arr.size() < 60:
		_fail("tech %d < 60" % arr.size())
	var saw_spoil := false
	var saw_mil := false
	var saw_trade := false
	for t in arr:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var bo: Variant = (t as Dictionary).get("bonuses", {})
		if typeof(bo) == TYPE_DICTIONARY:
			if (bo as Dictionary).has("spoilage_mult"):
				saw_spoil = true
			if (bo as Dictionary).has("military_power_mult"):
				saw_mil = true
			if (bo as Dictionary).has("trade_value_mult"):
				saw_trade = true
	if not saw_spoil:
		_fail("no tech with spoilage_mult")
	if not saw_mil:
		_fail("no tech with military_power_mult")
	if not saw_trade:
		_fail("no tech with trade_value_mult")

func _check_counts() -> void:
	var units: Variant = _load_json("res://data/catalog/units.json")
	if typeof(units) == TYPE_ARRAY and (units as Array).size() < 18:
		_fail("units < 18")
	var bld: Variant = _load_json("res://data/catalog/buildings.json")
	if typeof(bld) == TYPE_ARRAY and (bld as Array).size() < 40:
		_fail("buildings < 40")
	var traits: Variant = _load_json("res://data/catalog/traits.json")
	if typeof(traits) == TYPE_ARRAY and (traits as Array).size() < 24:
		_fail("traits < 24")

func _init() -> void:
	_check_main_quest()
	_check_missions()
	_check_events()
	_check_balance()
	_check_scenarios()
	_check_tech()
	_check_counts()
	if _fails > 0:
		printerr("CATALOGS: %d failures" % _fails)
		quit(1)
		return
	print("OK: catalogs validate (quest chains, missions, events, balance, scenarios, tech, counts)")
	quit(0)
