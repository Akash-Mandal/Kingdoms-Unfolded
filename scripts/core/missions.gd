extends Node
signal mission_started(mission: Dictionary)
signal mission_completed(mission: Dictionary)
signal mission_failed(mission: Dictionary)
signal act_advanced(act: Dictionary)
signal act_completed(act: Dictionary)

var main_quest: Dictionary = {}
var mission_templates: Array[Dictionary] = []
var active: Array[Dictionary] = []
var completed: Array[Dictionary] = []
var failed: Array[Dictionary] = []
var current_act_idx: int = 0
var act_history: Array[Dictionary] = []
var crisis_survived: int = 0
var _rng := RandomNumberGenerator.new()
var _loaded := false

func _ready() -> void:
	_rng.seed = int(Time.get_ticks_msec())
	_load_all()
	_loaded = true

func _load_all() -> void:
	_load_main_quest()
	_load_missions()

func _load_main_quest() -> void:
	var path := "res://data/catalog/main_quest.json"
	if not FileAccess.file_exists(path):
		push_warning("Missions: main_quest.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		main_quest = parsed as Dictionary

func _load_missions() -> void:
	var path := "res://data/catalog/missions.json"
	if not FileAccess.file_exists(path):
		push_warning("Missions: missions.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Missions: missions.json malformed")
		return
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			mission_templates.append(e as Dictionary)

func get_acts() -> Array:
	var a: Variant = main_quest.get("acts", [])
	if typeof(a) == TYPE_ARRAY:
		return a as Array
	return []

func get_current_act() -> Dictionary:
	var acts: Array = get_acts()
	if acts.is_empty():
		return {}
	if current_act_idx < 0 or current_act_idx >= acts.size():
		return {}
	return acts[current_act_idx] as Dictionary

func _snapshot_state() -> Dictionary:
	var s: Dictionary = {}
	var g: Node = get_node_or_null("/root/Game")
	if g != null:
		var rs: Variant = g.get("resources")
		if typeof(rs) == TYPE_DICTIONARY:
			s["resources"] = rs
			for k in (rs as Dictionary).keys():
				var r: Dictionary = (rs as Dictionary)[k] as Dictionary
				s["resource_" + str(k)] = float(r.get("stock", 0.0))
		s["pop_count"] = float(g.get("pop_count"))
		s["pop_happiness"] = float(g.get("pop_happiness"))
		s["happiness"] = float(g.get("pop_happiness"))
		s["turn"] = int(g.get("turn"))
		s["month"] = int(g.get("month"))
		s["year"] = int(g.get("year"))
		if g.has_method("season"):
			s["season"] = str(g.call("season"))
		var cap: Variant = g.get("building_cap")
		if typeof(cap) == TYPE_DICTIONARY:
			for kk in (cap as Dictionary).keys():
				s["capacity_" + str(kk)] = float((cap as Dictionary)[kk])
			var base: float = float(g.get("pop_capacity_base"))
			var extra: float = float((cap as Dictionary).get("housing", 0.0))
			s["capacity_housing"] = base + extra
		else:
			s["capacity_housing"] = float(g.get("pop_capacity_base"))
		var placed: Variant = g.get("placed_buildings")
		if typeof(placed) == TYPE_ARRAY:
			var counts: Dictionary = {}
			for entry in placed as Array:
				if typeof(entry) == TYPE_DICTIONARY:
					var bid: String = str((entry as Dictionary).get("id", ""))
					counts[bid] = int(counts.get(bid, 0)) + 1
					counts["any"] = int(counts.get("any", 0)) + 1
			for bid in counts.keys():
				s["building_" + str(bid)] = int(counts[bid])
		s["events_crisis_survived"] = crisis_survived
		var _settings_v: Variant = g.get("settings")
		var _diff: String = str((_settings_v as Dictionary).get("difficulty", "peaceful")) if typeof(_settings_v) == TYPE_DICTIONARY else "peaceful"
		s["difficulty"] = _diff
	return s

func _compare(a: float, op: String, b: float) -> bool:
	match op:
		"<": return a < b
		"<=": return a <= b
		">": return a > b
		">=": return a >= b
		"==", "=": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
		_: return false

func _check_objective(obj: Dictionary, state: Dictionary) -> bool:
	var track: String = str(obj.get("track", ""))
	var op: String = str(obj.get("op", ">="))
	var val: float = float(obj.get("value", 0))
	if track == "season_survive_winter":
		return int(state.get("season", "" ) != "winter" or float(state.get("resource_food", 0.0)) > 0.0) == int(val)
	var cur: float = 0.0
	if state.has(track):
		cur = float(state[track])
	elif track.begins_with("resource_") or track.begins_with("building_") or track.begins_with("capacity_"):
		cur = float(state.get(track, 0.0))
	else:
		cur = float(state.get(track, 0.0))
	return _compare(cur, op, val)

func is_act_complete(state: Dictionary = {}) -> bool:
	var act: Dictionary = get_current_act()
	if act.is_empty():
		return false
	if state.is_empty():
		state = _snapshot_state()
	var objs: Variant = act.get("objectives", [])
	if typeof(objs) != TYPE_ARRAY or (objs as Array).is_empty():
		return true
	for o in objs as Array:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var od: Dictionary = o as Dictionary
		if bool(od.get("optional", false)):
			continue
		if not _check_objective(od, state):
			return false
	return true

func _apply_rewards(rewards: Dictionary) -> void:
	var g: Node = get_node_or_null("/root/Game")
	if g == null:
		return
	var rs: Variant = g.get("resources")
	for k in rewards.keys():
		var v: Variant = rewards[k]
		if k == "happiness":
			var cur: float = float(g.get("pop_happiness"))
			g.set("pop_happiness", clampf(cur + float(v), 0.0, 1.0))
		elif typeof(rs) == TYPE_DICTIONARY and (rs as Dictionary).has(k):
			var r: Dictionary = (rs as Dictionary)[k] as Dictionary
			r["stock"] = maxf(0.0, float(r.get("stock", 0.0)) + float(v))
	if g.has_signal("resources_changed"):
		g.emit_signal("resources_changed")
	if g.has_signal("population_changed"):
		g.emit_signal("population_changed")

func advance_act() -> bool:
	var act: Dictionary = get_current_act()
	if act.is_empty():
		return false
	var state: Dictionary = _snapshot_state()
	if not is_act_complete(state):
		return false
	var rewards: Variant = act.get("rewards", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		_apply_rewards(rewards as Dictionary)
	act_history.append({"id": act.get("id", ""), "turn": int(state.get("turn", 0)), "title": act.get("title", "")})
	act_completed.emit(act)
	var branch: Variant = act.get("branch", {})
	var next_id: String = ""
	if typeof(branch) == TYPE_DICTIONARY:
		next_id = str((branch as Dictionary).get("success", ""))
	var acts: Array = get_acts()
	var next_idx := -1
	if next_id != "":
		for i in acts.size():
			if str((acts[i] as Dictionary).get("id", "")) == next_id:
				next_idx = i
				break
	else:
		next_idx = current_act_idx + 1
	if next_idx >= 0 and next_idx < acts.size():
		current_act_idx = next_idx
		var next_act: Dictionary = acts[current_act_idx] as Dictionary
		act_advanced.emit(next_act)
	else:
		current_act_idx = acts.size()
		act_advanced.emit({})
	return true

func _is_mission_complete(m: Dictionary, state: Dictionary) -> bool:
	var objs: Variant = m.get("objectives", [])
	if typeof(objs) != TYPE_ARRAY or (objs as Array).is_empty():
		return true
	for o in objs as Array:
		if typeof(o) != TYPE_DICTIONARY:
			continue
		var od: Dictionary = o as Dictionary
		if bool(od.get("optional", false)):
			continue
		if not _check_objective(od, state):
			return false
	return true

func tick(state: Dictionary = {}) -> void:
	if state.is_empty():
		state = _snapshot_state()
	while is_act_complete(state):
		if not advance_act():
			break
		state = _snapshot_state()
	var to_complete: Array[Dictionary] = []
	var to_fail: Array[Dictionary] = []
	var turn: int = int(state.get("turn", 0))
	for m in active:
		var started: int = int(m.get("started_turn", 0))
		var expiry: int = int(m.get("expiry_turns", 9999))
		if turn - started > expiry:
			to_fail.append(m)
		elif _is_mission_complete(m, state):
			to_complete.append(m)
	for m in to_complete:
		complete_mission(str(m.get("id", "")), "")
	for m in to_fail:
		fail_mission(str(m.get("id", "")))

func complete_mission(mission_id: String, choice_id: String) -> bool:
	var idx := -1
	for i in active.size():
		if str(active[i].get("id", "")) == mission_id:
			idx = i
			break
	if idx == -1:
		return false
	var m: Dictionary = active[idx]
	active.remove_at(idx)
	if choice_id != "":
		var choices: Variant = m.get("choices", [])
		if typeof(choices) == TYPE_ARRAY:
			for ch in choices as Array:
				if typeof(ch) == TYPE_DICTIONARY and str((ch as Dictionary).get("id", "")) == choice_id:
					var eff: Variant = (ch as Dictionary).get("effects", {})
					if typeof(eff) == TYPE_DICTIONARY:
						_apply_rewards(eff as Dictionary)
					var fu: String = str((ch as Dictionary).get("follow_up", ""))
					if fu != "":
						start_mission(fu)
					break
	var rewards: Variant = m.get("rewards", {})
	if typeof(rewards) == TYPE_DICTIONARY:
		_apply_rewards(rewards as Dictionary)
	m["completed_turn"] = _snapshot_state().get("turn", 0)
	m["choice"] = choice_id
	completed.append(m)
	mission_completed.emit(m)
	return true

func fail_mission(mission_id: String) -> bool:
	var idx := -1
	for i in active.size():
		if str(active[i].get("id", "")) == mission_id:
			idx = i
			break
	if idx == -1:
		return false
	var m: Dictionary = active[idx]
	active.remove_at(idx)
	failed.append(m)
	mission_failed.emit(m)
	return true

func start_mission(template_id: String) -> Dictionary:
	for a in active:
		if str(a.get("id", "")) == template_id:
			return {}
	var tpl: Dictionary = {}
	for t in mission_templates:
		if str(t.get("id", "")) == template_id:
			tpl = t
			break
	if tpl.is_empty():
		return {}
	if active.size() >= 5:
		return {}
	var inst: Dictionary = tpl.duplicate(true)
	inst["started_turn"] = _snapshot_state().get("turn", 0)
	inst["status"] = "active"
	active.append(inst)
	mission_started.emit(inst)
	return inst

func auto_offer(state: Dictionary = {}) -> Dictionary:
	if active.size() >= 5:
		return {}
	if mission_templates.is_empty():
		return {}
	if state.is_empty():
		state = _snapshot_state()
	var candidates: Array[Dictionary] = []
	var weights: PackedFloat64Array = PackedFloat64Array()
	var total := 0.0
	for tpl in mission_templates:
		var tid: String = str(tpl.get("id", ""))
		var is_active := false
		for a in active:
			if str(a.get("id", "")) == tid:
				is_active = true
				break
		if is_active:
			continue
		var is_done := false
		for c in completed:
			if str(c.get("id", "")) == tid and not bool(tpl.get("repeatable", false)):
				is_done = true
				break
		if is_done:
			continue
		var w: float = float(tpl.get("weight", 10))
		var conds: Variant = tpl.get("conditions", [])
		if typeof(conds) == TYPE_ARRAY:
			for cond in conds as Array:
				if typeof(cond) == TYPE_DICTIONARY:
					var cd: Dictionary = cond as Dictionary
					var kind: String = str(cd.get("kind", ""))
					var mk: bool = false
					match kind:
						"resource":
							var key: String = str(cd.get("key", ""))
							var op: String = str(cd.get("op", ">"))
							var val: float = float(cd.get("value", 0))
							mk = _compare(float(state.get("resource_" + key, 0.0)), op, val)
						"happiness":
							mk = _compare(float(state.get("happiness", 0.5)), str(cd.get("op", ">")), float(cd.get("value", 0.5)))
						"pop":
							mk = _compare(float(state.get("pop_count", 0.0)), str(cd.get("op", ">")), float(cd.get("value", 0)))
						"turn":
							mk = _compare(float(state.get("turn", 0)), str(cd.get("op", ">")), float(cd.get("value", 0)))
						"season":
							mk = str(state.get("season", "")) == str(cd.get("value", ""))
						_: mk = false
					if mk:
						w *= float(cd.get("weight_mult", 1.0))
		if w <= 0.0:
			continue
		candidates.append(tpl)
		weights.append(w)
		total += w
	if candidates.is_empty():
		return {}
	var r: float = _rng.randf() * total
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if r <= acc:
			return start_mission(str(candidates[i].get("id", "")))
	return start_mission(str(candidates.back().get("id", "")))

func on_crisis_event_survived() -> void:
	crisis_survived += 1

func get_progress() -> Dictionary:
	var act: Dictionary = get_current_act()
	var total: int = get_acts().size()
	return {
		"current_act": act.get("id", ""),
		"current_title": act.get("title", ""),
		"act_idx": current_act_idx,
		"act_total": total,
		"active_missions": active.size(),
		"completed_missions": completed.size(),
		"crisis_survived": crisis_survived,
	}

func serialize() -> Dictionary:
	return {
		"current_act_idx": current_act_idx,
		"active": active.duplicate(true),
		"completed": completed.duplicate(true),
		"failed": failed.duplicate(true),
		"act_history": act_history.duplicate(true),
		"crisis_survived": crisis_survived,
	}

func restore(data: Dictionary) -> void:
	current_act_idx = int(data.get("current_act_idx", 0))
	var a: Variant = data.get("active", [])
	if typeof(a) == TYPE_ARRAY:
		active.clear()
		for e in a as Array:
			if typeof(e) == TYPE_DICTIONARY:
				active.append(e as Dictionary)
	var c: Variant = data.get("completed", [])
	if typeof(c) == TYPE_ARRAY:
		completed.clear()
		for e in c as Array:
			if typeof(e) == TYPE_DICTIONARY:
				completed.append(e as Dictionary)
	var f: Variant = data.get("failed", [])
	if typeof(f) == TYPE_ARRAY:
		failed.clear()
		for e in f as Array:
			if typeof(e) == TYPE_DICTIONARY:
				failed.append(e as Dictionary)
	var ah: Variant = data.get("act_history", [])
	if typeof(ah) == TYPE_ARRAY:
		act_history.clear()
		for e in ah as Array:
			if typeof(e) == TYPE_DICTIONARY:
				act_history.append(e as Dictionary)
	crisis_survived = int(data.get("crisis_survived", 0))

func templates_by_category(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in mission_templates:
		if str(t.get("category", "")) == cat:
			out.append(t)
	return out

func count_by_category() -> Dictionary:
	var m: Dictionary = {}
	for t in mission_templates:
		var c: String = str(t.get("category", ""))
		m[c] = int(m.get(c, 0)) + 1
	return m
