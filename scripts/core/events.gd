extends Node
signal event_triggered(event: Dictionary)
signal choice_applied(event_id: String, choice_id: String)

var templates: Array[Dictionary] = []
var _cooldown: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _loaded := false

func _ready() -> void:
	_rng.seed = int(Time.get_ticks_msec())
	_load()
	_loaded = true

func _load() -> void:
	var path := "res://data/catalog/events.json"
	if not FileAccess.file_exists(path):
		push_warning("Events: events.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Events: malformed events.json")
		return
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			templates.append(e as Dictionary)

func evaluate_weight(tpl: Dictionary, state: Dictionary) -> float:
	var w: float = float(tpl.get("weight", 10))
	var conds: Variant = tpl.get("conditions", [])
	if typeof(conds) != TYPE_ARRAY:
		return w
	for c in conds as Array:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = c as Dictionary
		if _check_condition(cd, state):
			w *= float(cd.get("weight_mult", 1.0))
	return w

func _check_condition(c: Dictionary, state: Dictionary) -> bool:
	var kind: String = str(c.get("kind", ""))
	match kind:
		"resource":
			var key: String = str(c.get("key", ""))
			var op: String = str(c.get("op", ">"))
			var val: float = float(c.get("value", 0))
			var stock: float = 0.0
			if state.has("resources"):
				var rs: Dictionary = state["resources"] as Dictionary
				if rs.has(key):
					var r: Dictionary = rs[key] as Dictionary
					stock = float(r.get("stock", 0.0))
			else:
				stock = float(state.get("resource_" + key, state.get(key, 0.0)))
			return _compare(stock, op, val)
		"happiness":
			var op2: String = str(c.get("op", ">"))
			var v2: float = float(c.get("value", 0.5))
			return _compare(float(state.get("happiness", state.get("pop_happiness", 0.5))), op2, v2)
		"pop":
			var op3: String = str(c.get("op", ">"))
			var v3: float = float(c.get("value", 0))
			return _compare(float(state.get("pop_count", state.get("pop", 0.0))), op3, v3)
		"season":
			return str(state.get("season", "")) == str(c.get("value", ""))
		"turn":
			return _compare(float(state.get("turn", 0)), str(c.get("op", ">")), float(c.get("value", 0)))
		"month":
			return _compare(float(state.get("month", 1)), str(c.get("op", "==")), float(c.get("value", 0)))
		"year":
			return _compare(float(state.get("year", 0)), str(c.get("op", ">")), float(c.get("value", 0)))
		_:
			return false

func _compare(a: float, op: String, b: float) -> bool:
	match op:
		"<": return a < b
		"<=": return a <= b
		">": return a > b
		">=": return a >= b
		"==", "=": return is_equal_approx(a, b)
		"!=": return not is_equal_approx(a, b)
		_: return false

func _snapshot_state() -> Dictionary:
	var s: Dictionary = {}
	if Engine.has_singleton("Game") or has_node("/root/Game"):
		var g: Node = get_node_or_null("/root/Game")
		if g == null:
			g = Engine.get_singleton("Game") as Node
		if g != null:
			var rs: Variant = g.get("resources")
			if typeof(rs) == TYPE_DICTIONARY:
				s["resources"] = rs
			s["pop_count"] = float(g.get("pop_count"))
			s["pop_happiness"] = float(g.get("pop_happiness"))
			s["happiness"] = float(g.get("pop_happiness"))
			if g.has_method("season"):
				s["season"] = str(g.call("season"))
			s["turn"] = int(g.get("turn"))
			s["month"] = int(g.get("month"))
			s["year"] = int(g.get("year"))
			var ev: Variant = g.get("events")
			if typeof(ev) == TYPE_ARRAY:
				var arr: Array = ev as Array
				s["recent_events"] = arr.slice(0, 5)
	return s

func is_on_cooldown(id: String, turn: int) -> bool:
	return int(_cooldown.get(id, -999)) > turn

func weighted_pick(state: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var weights: PackedFloat64Array = PackedFloat64Array()
	var total := 0.0
	var turn: int = int(state.get("turn", 0))
	for tpl in templates:
		var tid: String = str(tpl.get("id", ""))
		if is_on_cooldown(tid, turn):
			continue
		var w: float = evaluate_weight(tpl, state) * float(tpl.get("base_prob", 0.03)) * 100.0
		if w <= 0.0:
			continue
		candidates.append(tpl)
		weights.append(w)
		total += w
	if candidates.is_empty() or total <= 0.0:
		return {}
	var r: float = _rng.randf() * total
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if r <= acc:
			return candidates[i]
	return candidates.back()

func roll(state: Dictionary = {}) -> Dictionary:
	if templates.is_empty():
		_load()
	if state.is_empty():
		state = _snapshot_state()
	var base_chance := 0.32
	var diff: String = str(state.get("difficulty", "peaceful"))
	match diff:
		"peaceful": base_chance *= 0.7
		"chaos": base_chance *= 1.3
		"legendary": base_chance *= 1.6
		_: pass
	if _rng.randf() > base_chance:
		return {}
	var tpl: Dictionary = weighted_pick(state)
	if tpl.is_empty():
		return {}
	var turn: int = int(state.get("turn", 0))
	var cd: int = int(tpl.get("cooldown", 5))
	_cooldown[str(tpl.get("id", ""))] = turn + cd
	var inst: Dictionary = {
		"id": tpl.get("id", ""),
		"turn": turn,
		"category": tpl.get("category", "random"),
		"type": tpl.get("category", "random"),
		"severity": int(tpl.get("severity", 1)),
		"text": tpl.get("text", ""),
		"name": tpl.get("name", ""),
		"choices": (tpl.get("choices", []) as Array).duplicate(true),
		"template_id": tpl.get("id", ""),
	}
	return inst

func roll_and_emit(state: Dictionary = {}) -> Dictionary:
	var ev: Dictionary = roll(state)
	if ev.is_empty():
		return {}
	ev["id"] = "%s_%d" % [str(ev.get("template_id", "ev")), int(state.get("turn", 0))]
	event_triggered.emit(ev)
	var g: Node = get_node_or_null("/root/Game")
	if g != null and g.has_signal("event_occurred"):
		g.emit_signal("event_occurred", ev)
	return ev

func apply_choice(event: Dictionary, choice_id: String) -> bool:
	var choices: Variant = event.get("choices", [])
	if typeof(choices) != TYPE_ARRAY:
		return false
	var chosen: Dictionary = {}
	for ch in choices as Array:
		if typeof(ch) == TYPE_DICTIONARY and str((ch as Dictionary).get("id", "")) == choice_id:
			chosen = ch as Dictionary
			break
	if chosen.is_empty():
		return false
	var effects: Variant = chosen.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		return true
	var g: Node = get_node_or_null("/root/Game")
	if g == null:
		return true
	var rs: Variant = g.get("resources")
	var happy: Variant = g.get("pop_happiness")
	var edict: Dictionary = effects as Dictionary
	for k in edict.keys():
		var v: Variant = edict[k]
		if k == "happiness":
			if typeof(happy) == TYPE_FLOAT or typeof(happy) == TYPE_INT:
				var cur: float = float(g.get("pop_happiness"))
				g.set("pop_happiness", clampf(cur + float(v), 0.0, 1.0))
		elif typeof(rs) == TYPE_DICTIONARY and (rs as Dictionary).has(k):
			var r: Dictionary = (rs as Dictionary)[k] as Dictionary
			r["stock"] = maxf(0.0, float(r.get("stock", 0.0)) + float(v))
	choice_applied.emit(str(event.get("id", "")), choice_id)
	if g.has_signal("resources_changed"):
		g.emit_signal("resources_changed")
	if g.has_signal("population_changed"):
		g.emit_signal("population_changed")
	return true

func serialize() -> Dictionary:
	return {"cooldown": _cooldown.duplicate(true)}

func restore(data: Dictionary) -> void:
	var cd: Variant = data.get("cooldown", {})
	if typeof(cd) == TYPE_DICTIONARY:
		_cooldown = (cd as Dictionary).duplicate(true)

func templates_by_category(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in templates:
		if str(t.get("category", "")) == cat:
			out.append(t)
	return out

func count_by_category() -> Dictionary:
	var m: Dictionary = {}
	for t in templates:
		var c: String = str(t.get("category", ""))
		m[c] = int(m.get(c, 0)) + 1
	return m
