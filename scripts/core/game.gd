extends Node
signal turned
signal event_occurred(event: Dictionary)
signal resources_changed
signal population_changed
signal mission_changed
signal military_changed

const TURNS_PER_YEAR := 12
const SAVE_VERSION := 4

const RESOURCE_KEYS: PackedStringArray = [
	"food", "gold", "wood", "stone", "iron", "cloth", "horses", "knowledge"
]
const CHAIN_KEYS: PackedStringArray = ["grain", "flour"]
const ALL_KEYS: PackedStringArray = [
	"food", "gold", "wood", "stone", "iron", "cloth", "horses", "knowledge",
	"grain", "flour"
]

var turn := 0
var month := 1
var year := 0

var resources: Dictionary = {}
var building_prod: Dictionary = {}
var building_cons: Dictionary = {}
var building_cap: Dictionary = {}

var pop_count := 50.0
var pop_capacity_base := 60.0
var pop_happiness := 0.6

var military: Dictionary = {}
var events: Array[Dictionary] = []
var placed_buildings: Array[Dictionary] = []

var settings := {
	"world_seed": 0,
	"era": "medieval",
	"difficulty": "peaceful",
	"kingdom_name": "Eterna",
	"ruler_name": "Aurelia",
	"banner_color": "#4a6fa5",
	"sigil": "eagle",
	"gov": "feudal",
	"religion": "old_gods",
	"culture": "highland",
	"ruler_age": 28,
	"ruler_gender": "male",
	"traits": [],
	"legacy_path": "builder",
	"territory_size": "medium",
	"rivals": 3,
	"scenario": "default",
	"starting_season": "spring",
}

var _balance_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _event_cooldown: Dictionary = {}
var _crisis_survived: int = 0

func _get_balance() -> Dictionary:
	if not _balance_cache.is_empty():
		return _balance_cache
	var cat: Node = get_node_or_null("/root/Catalog")
	if cat != null and "balance" in cat:
		var b: Variant = cat.get("balance")
		if typeof(b) == TYPE_DICTIONARY and not (b as Dictionary).is_empty():
			_balance_cache = b as Dictionary
			return _balance_cache
	var path := "res://data/catalog/balance.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var p: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(p) == TYPE_DICTIONARY:
				_balance_cache = p as Dictionary
				return _balance_cache
	return _balance_cache

func _bal(path: String, default: Variant) -> Variant:
	var b: Dictionary = _get_balance()
	var cur: Variant = b
	for part in path.split("."):
		if typeof(cur) == TYPE_DICTIONARY and (cur as Dictionary).has(part):
			cur = (cur as Dictionary)[part]
		else:
			return default
	return cur

func _ready() -> void:
	reset()

func reset() -> void:
	turn = 0
	month = 1
	year = 0
	events.clear()
	placed_buildings.clear()
	resources.clear()
	for key in ALL_KEYS:
		resources[key] = {
			"stock": 100.0 if RESOURCE_KEYS.has(key) else 0.0,
			"prod": _base_production(key),
			"cons": _base_consumption(key),
		}
	building_prod.clear()
	building_cons.clear()
	building_cap.clear()
	pop_count = 50.0
	pop_happiness = 0.6
	_event_cooldown.clear()
	_crisis_survived = 0
	_init_military_defaults()
	if has_node("/root/Tech"):
		var tn3: Node = get_node("/root/Tech")
		if tn3.has_method("deserialize"):
			tn3.call("deserialize", {})
	var mn: Node = get_node_or_null("/root/Missions")
	if mn != null and mn.has_method("restore"):
		mn.call("restore", {"current_act_idx": 0, "active": [], "completed": [], "failed": [], "act_history": [], "crisis_survived": 0})
	var evn: Node = get_node_or_null("/root/Events")
	if evn != null and evn.has_method("restore"):
		evn.call("restore", {"cooldown": {}})
	_rng.seed = hash(str(settings.world_seed) + str(Time.get_ticks_msec())) & 0x7fffffff
	if _rng.state == 0:
		_rng.state = 1
		if _rng.seed == 0:
			_rng.seed = 1

func _base_production(key: String) -> float:
	var v: Variant = _bal("production.base_production." + key, null)
	if v != null:
		return float(v)
	match key:
		"food": return 42.0
		"gold": return 12.0
		"wood": return 18.0
		"stone": return 8.0
		"iron": return 4.0
		"cloth": return 6.0
		"horses": return 2.0
		"knowledge": return 3.0
	return 0.0

func _base_consumption(key: String) -> float:
	var v: Variant = _bal("production.base_consumption." + key, null)
	if v != null:
		return float(v)
	match key:
		"food": return 36.0
		"gold": return 9.0
		"wood": return 10.0
		"stone": return 4.0
		"iron": return 2.0
		"cloth": return 5.0
		"horses": return 1.0
		"knowledge": return 1.0
	return 0.0

func advance() -> void:
	turn += 1
	month = (month % TURNS_PER_YEAR) + 1
	if month == 1:
		year += 1
	_apply_flows()
	_tick_tech()
	_apply_military_upkeep()
	_apply_population()
	_roll_events()
	_tick_missions()
	turned.emit()
	resources_changed.emit()
	population_changed.emit()
	military_changed.emit()
	if has_node("/root/SaveSlots") and get_node("/root/SaveSlots").has_method("autosave_check"):
		get_node("/root/SaveSlots").call("autosave_check")

func _season_yield_mult(key: String) -> float:
	var s := season()
	var v: Variant = _bal("seasonal_yield." + key + "." + s, null)
	if v != null:
		return float(v)
	var fallback: Variant = _bal("seasonal_yield." + key, null)
	if fallback is float or fallback is int:
		return float(fallback)
	var def: Variant = _bal("seasonal_yield.default", null)
	if def != null and key != "grain" and key != "flour":
		return float(def)
	var s2 := season()
	if key == "grain":
		match s2:
			"spring": return 1.15
			"summer": return 1.25
			"autumn": return 0.9
			"winter": return 0.35
	elif key == "flour":
		match s2:
			"spring": return 1.08
			"summer": return 1.12
			"autumn": return 0.95
			"winter": return 0.6
	return 1.0

func _difficulty_prod_mult() -> float:
	var v: Variant = _bal("difficulty." + str(settings.difficulty) + ".production_multiplier", null)
	if v != null:
		return float(v)
	match settings.difficulty:
		"peaceful": return 1.15
		"iron": return 1.0
		"chaos": return 0.9
		"legendary": return 0.8
		_: return 1.0

func _difficulty_cons_mult() -> float:
	var v: Variant = _bal("difficulty." + str(settings.difficulty) + ".consumption_multiplier", null)
	if v != null:
		return float(v)
	match settings.difficulty:
		"peaceful": return 0.9
		"iron": return 1.0
		"chaos": return 1.1
		"legendary": return 1.2
		_: return 1.0

func _tech_prod_mult(key: String) -> float:
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null and tn.has_method("get_total_prod_mult"):
		return float(tn.call("get_total_prod_mult", key))
	return 1.0

func _tech_cap_add(key: String) -> float:
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null and tn.has_method("get_total_cap_add"):
		return float(tn.call("get_total_cap_add", key))
	return 0.0

func _tick_tech() -> void:
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null and tn.has_method("tick"):
		tn.call("tick")

func _sanitize_resources() -> void:
	for k in ALL_KEYS:
		if resources.has(k):
			var rr: Dictionary = resources[k] as Dictionary
			rr["stock"] = clampf(float(rr.get("stock",0.0)), 0.0, 999999.0)
func _apply_flows() -> void:
	var p_mult := _difficulty_prod_mult()
	var c_mult := _difficulty_cons_mult()
	var is_winter := season() == "winter"
	var s_grain := _season_yield_mult("grain")
	var s_flour := _season_yield_mult("flour")
	var grain_prod_raw: float = (float(resources["grain"]["prod"]) + float(building_prod.get("grain", 0.0))) * s_grain * p_mult * _tech_prod_mult("grain")
	var grain_cons_raw: float = (float(resources["grain"]["cons"]) + float(building_cons.get("grain", 0.0))) * c_mult
	var grain_avail: float = float(resources["grain"]["stock"]) + grain_prod_raw
	var grain_cons_eff: float = minf(grain_cons_raw, grain_avail)
	var grain_ratio: float = grain_cons_eff / maxf(grain_cons_raw, 0.0001) if grain_cons_raw > 0.0 else 1.0
	var flour_prod_raw: float = (float(resources["flour"]["prod"]) + float(building_prod.get("flour", 0.0))) * s_flour * p_mult * _tech_prod_mult("flour")
	var flour_prod_eff: float = flour_prod_raw * grain_ratio
	var flour_cons_raw: float = (float(resources["flour"]["cons"]) + float(building_cons.get("flour", 0.0))) * c_mult
	var flour_avail: float = float(resources["flour"]["stock"]) + flour_prod_eff
	var flour_cons_eff: float = minf(flour_cons_raw, flour_avail)
	var flour_ratio: float = flour_cons_eff / maxf(flour_cons_raw, 0.0001) if flour_cons_raw > 0.0 else 1.0
	var food_base_prod: float = float(resources["food"]["prod"]) * p_mult * _tech_prod_mult("food")
	var food_build_prod_raw: float = float(building_prod.get("food", 0.0)) * p_mult * _tech_prod_mult("food")
	var food_prod_eff: float = food_base_prod + food_build_prod_raw * flour_ratio
	var food_cons_raw: float = (float(resources["food"]["cons"]) + float(building_cons.get("food", 0.0))) * c_mult
	if is_winter:
		food_cons_raw *= float(_bal("consumption.winter_multiplier", 1.3))
	resources["grain"]["stock"] = clampf(grain_avail - grain_cons_eff, 0.0, 999999.0)
	resources["flour"]["stock"] = clampf(flour_avail - flour_cons_eff, 0.0, 999999.0)
	resources["food"]["stock"] = clampf(float(resources["food"]["stock"]) + food_prod_eff - food_cons_raw, 0.0, 999999.0)
	for key in ALL_KEYS:
		if key == "grain" or key == "flour" or key == "food":
			continue
		var r: Dictionary = resources[key]
		var prod: float = (float(r["prod"]) + float(building_prod.get(key, 0.0))) * p_mult * _tech_prod_mult(key)
		var cons: float = (float(r["cons"]) + float(building_cons.get(key, 0.0))) * c_mult
		r["stock"] = clampf(float(r["stock"]) + prod - cons, 0.0, 999999.0)
	_sanitize_resources()

func _apply_population() -> void:
	var food_stock := maxf(0.0, get_stock("food"))
	var c_mult := _difficulty_cons_mult()
	var food_cons: float = (float(resources["food"]["cons"]) + float(building_cons.get("food", 0.0))) * c_mult
	if season() == "winter":
		food_cons *= float(_bal("consumption.winter_multiplier", 1.3))
	var surplus: float = food_stock - food_cons
	var h_base: float = float(_bal("happiness.current_impl.base", 0.4))
	var h_w: float = float(_bal("happiness.current_impl.surplus_weight", 0.4))
	var h_div: float = float(_bal("happiness.current_impl.surplus_divisor", 50.0))
	var h_off: float = float(_bal("happiness.current_impl.surplus_offset", 0.5))
	pop_happiness = clampf(h_base + h_w * (surplus / h_div + h_off), 0.0, 1.0)
	var tn2: Node = get_node_or_null("/root/Tech")
	if tn2 != null and tn2.has_method("get_total_happiness_add"):
		pop_happiness = clampf(pop_happiness + float(tn2.call("get_total_happiness_add")), 0.0, 1.0)
	pop_happiness = clampf(pop_happiness, 0.0, 1.0)
	pop_count = maxf(0.0, pop_count)
	var cap: float = maxf(1.0, pop_capacity_base + float(building_cap.get("housing", 0.0)) + _tech_cap_add("housing"))
	var starve_rate: float = float(_bal("population.famine_starvation_rate", 0.2))
	var birth_rate: float = float(_bal("population.base_birth_rate", 0.02))
	if surplus < 0.0:
		pop_count = maxf(0.0, pop_count + surplus * starve_rate)
	elif pop_count < cap:
		pop_count += pop_count * birth_rate * pop_happiness * (1.0 - pop_count / maxf(cap, 1.0))
	pop_count = clampf(pop_count, 0.0, cap) if surplus >= 0.0 else maxf(0.0, pop_count)
	pop_count = clampf(pop_count, 0.0, float(_bal("population.max_pop", 99999.0)))
	if food_stock <= 0.0:
		pop_happiness = maxf(0.0, pop_happiness + float(_bal("happiness.current_impl.famine_penalty", -0.05)))
		var ev := {"id": events.size(), "turn": turn, "type": "shortage", "category": "disaster", "severity": 2, "text": "Granaries stand empty! Hunger gnaws at the realm.", "choices": [{"id": "ration", "label": "Ration strictly", "effects": {"happiness": -0.05}}, {"id": "import", "label": "Import at great cost", "effects": {"gold": -20, "food": 15}}]}
		events.push_front(ev)
		event_occurred.emit(ev)

func _state_snapshot() -> Dictionary:
	var s: Dictionary = {}
	s["resources"] = resources
	for k in ALL_KEYS:
		if resources.has(k):
			s["resource_" + k] = float(resources[k].get("stock", 0.0))
	s["pop_count"] = pop_count
	s["pop_happiness"] = pop_happiness
	s["happiness"] = pop_happiness
	s["season"] = season()
	s["turn"] = turn
	s["month"] = month
	s["year"] = year
	s["difficulty"] = str(settings.difficulty)
	s["recent_events"] = events.slice(0, 5)
	s["crisis_survived"] = _crisis_survived
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

func _eval_condition(cond: Dictionary, state: Dictionary) -> bool:
	var kind: String = str(cond.get("kind", ""))
	match kind:
		"resource":
			var key: String = str(cond.get("key", ""))
			var op: String = str(cond.get("op", ">"))
			var val: float = float(cond.get("value", 0))
			var stock: float = float(state.get("resource_" + key, 0.0))
			return _compare(stock, op, val)
		"happiness":
			return _compare(float(state.get("happiness", 0.5)), str(cond.get("op", ">")), float(cond.get("value", 0.5)))
		"pop":
			return _compare(float(state.get("pop_count", 0.0)), str(cond.get("op", ">")), float(cond.get("value", 0)))
		"season":
			return str(state.get("season", "")) == str(cond.get("value", ""))
		"turn":
			return _compare(float(state.get("turn", 0)), str(cond.get("op", ">")), float(cond.get("value", 0)))
		"month":
			return _compare(float(state.get("month", 1)), str(cond.get("op", "==")), float(cond.get("value", 0)))
		"year":
			return _compare(float(state.get("year", 0)), str(cond.get("op", ">")), float(cond.get("value", 0)))
		_:
			return false

func _catalog_events() -> Array[Dictionary]:
	var cat: Node = get_node_or_null("/root/Catalog")
	if cat != null and "events" in cat and cat.events is Array and not (cat.events as Array).is_empty():
		return cat.events as Array[Dictionary]
	var evn: Node = get_node_or_null("/root/Events")
	if evn != null and "templates" in evn and evn.templates is Array and not (evn.templates as Array).is_empty():
		return evn.templates as Array[Dictionary]
	return []

func _ensure_catalog_events() -> Array[Dictionary]:
	var arr: Array[Dictionary] = _catalog_events()
	if not arr.is_empty():
		return arr
	var path := "res://data/catalog/events.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_ARRAY:
				for e in parsed as Array:
					if typeof(e) == TYPE_DICTIONARY:
						arr.append(e as Dictionary)
	return arr

func _weighted_event_pick(state: Dictionary, pool: Array[Dictionary]) -> Dictionary:
	var cands: Array[Dictionary] = []
	var weights: PackedFloat64Array = PackedFloat64Array()
	var total := 0.0
	for tpl in pool:
		var tid: String = str(tpl.get("id", ""))
		if int(_event_cooldown.get(tid, -999)) > state.get("turn", 0):
			continue
		var w: float = float(tpl.get("weight", 10))
		var conds: Variant = tpl.get("conditions", [])
		if typeof(conds) == TYPE_ARRAY:
			for c in conds as Array:
				if typeof(c) == TYPE_DICTIONARY and _eval_condition(c as Dictionary, state):
					w *= float((c as Dictionary).get("weight_mult", 1.0))
		w *= float(tpl.get("base_prob", 0.03)) * 100.0
		if w <= 0.001:
			continue
		cands.append(tpl)
		weights.append(w)
		total += w
	if cands.is_empty() or total <= 0.0:
		return {}
	var r: float = _rng.randf() * total
	var acc := 0.0
	for i in cands.size():
		acc += weights[i]
		if r <= acc:
			return cands[i]
	return cands.back()

func _roll_events() -> void:
	var state: Dictionary = _state_snapshot()
	var base_chance := float(_bal("event_roll.base_chance", 0.32))
	var diff_mult: Variant = _bal("event_roll.difficulty_mult." + str(settings.difficulty), null)
	if diff_mult != null:
		base_chance *= float(diff_mult)
	else:
		var diff2: Variant = _bal("difficulty." + str(settings.difficulty) + ".event_roll_mult", null)
		if diff2 != null:
			base_chance *= float(diff2)
		else:
			match str(settings.difficulty):
				"peaceful": base_chance *= 0.7
				"chaos": base_chance *= 1.3
				"legendary": base_chance *= 1.6
				_: pass
	if _rng.randf() > base_chance:
		return
	var pool: Array[Dictionary] = _ensure_catalog_events()
	if pool.is_empty():
		if _rng.randf() > 0.7:
			var ev := {
				"id": events.size(),
				"turn": turn,
				"type": "harvest",
				"category": "random",
				"severity": 1,
				"text": "A mild harvest season fills the granaries.",
				"choices": [{"id": "store", "label": "Store surplus", "effects": {"food": 25}}, {"id": "feast", "label": "Hold feast", "effects": {"food": 10, "happiness": 0.08}}],
			}
			events.push_front(ev)
			resources["food"]["stock"] = float(resources["food"]["stock"]) + 25.0
			event_occurred.emit(ev)
		return
	var tpl: Dictionary = _weighted_event_pick(state, pool)
	if tpl.is_empty():
		return
	var tid: String = str(tpl.get("id", ""))
	_event_cooldown[tid] = turn + int(tpl.get("cooldown", 5))
	var ev := {
		"id": "%s_%d" % [tid, turn],
		"turn": turn,
		"type": str(tpl.get("category", "random")),
		"category": str(tpl.get("category", "random")),
		"severity": int(tpl.get("severity", 1)),
		"text": str(tpl.get("text", "")),
		"name": str(tpl.get("name", tid)),
		"template_id": tid,
		"choices": (tpl.get("choices", []) as Array).duplicate(true),
	}
	events.push_front(ev)
	if str(ev["category"]) in ["plague", "revolt", "disaster"]:
		_crisis_survived += 0
	event_occurred.emit(ev)
	var evn: Node = get_node_or_null("/root/Events")
	if evn != null and evn.has_method("serialize"):
		pass

func apply_event_choice(event_id: Variant, choice_id: String) -> bool:
	var ev: Dictionary = {}
	for e in events:
		if str(e.get("id", "")) == str(event_id) or str(e.get("template_id", "")) == str(event_id):
			ev = e
			break
	if ev.is_empty():
		return false
	var choices: Variant = ev.get("choices", [])
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
	if typeof(effects) == TYPE_DICTIONARY:
		for k in (effects as Dictionary).keys():
			var v: Variant = (effects as Dictionary)[k]
			if k == "happiness":
				pop_happiness = clampf(pop_happiness + float(v), 0.0, 1.0)
				pop_happiness = clampf(pop_happiness,0,1)
			elif resources.has(k):
				var r: Dictionary = resources[k] as Dictionary
				r["stock"] = maxf(0.0, float(r.get("stock", 0.0)) + float(v))
		resources_changed.emit()
		population_changed.emit()
	var cat: String = str(ev.get("category", ""))
	if cat in ["plague", "revolt", "disaster"]:
		_crisis_survived += 1
		var mn: Node = get_node_or_null("/root/Missions")
		if mn != null and mn.has_method("on_crisis_event_survived"):
			mn.call("on_crisis_event_survived")
	return true

func _tick_missions() -> void:
	var mn: Node = get_node_or_null("/root/Missions")
	if mn != null and mn.has_method("tick"):
		mn.call("tick", _state_snapshot())
		if mn.has_method("auto_offer") and _rng.randf() < 0.22:
			mn.call("auto_offer", _state_snapshot())
		mission_changed.emit()
	else:
		_fallback_mission_tick()

func _fallback_mission_tick() -> void:
	pass

func set_building_contributions(prod: Dictionary, cons: Dictionary, cap: Dictionary) -> void:
	building_prod = prod
	building_cons = cons
	building_cap = cap

func record_building(id: String, x: float, z: float) -> void:
	placed_buildings.append({"id": id, "x": x, "z": z})

func season() -> String:
	match month:
		3, 4, 5: return "spring"
		6, 7, 8: return "summer"
		9, 10, 11: return "autumn"
		_: return "winter"

func get_stock(key: String) -> float:
	return maxf(0.0, float(resources.get(key, {}).get("stock", 0.0)))

func _init_military_defaults() -> void:
	var _tn: Node = get_node_or_null("/root/Tech")
	if _tn != null and _tn.has_method("reset_state"):
		_tn.call("reset_state")
	military.clear()
	var ids: Array = []
	var cat: Node = get_node_or_null("/root/Catalog")
	if cat != null and cat.has_method("unit_ids"):
		ids = cat.unit_ids()
	if ids.is_empty():
		ids = ["infantry_t1","archers_t1","cavalry_t1","siege_t1","navy_t1","elite_t1"]
	for id in ids:
		if typeof(id) == TYPE_STRING and not military.has(id):
			military[id] = {"count": 0, "morale": 0.7, "supply": 1.0, "experience": 0.0, "commander": "none"}
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("restore"):
		mil.restore(military)

func military_train(type: String, n: int) -> bool:
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("train"):
		var ok: bool = mil.train(type, n)
		if ok:
			military = mil.units.duplicate(true)
			military_changed.emit()
		return ok
	if not military.has(type):
		military[type] = {"count": 0, "morale": 0.7, "supply": 1.0, "experience": 0.0, "commander": "none"}
	var def: Dictionary = {}
	var cat: Node = get_node_or_null("/root/Catalog")
	if cat != null and cat.has_method("get_unit"):
		def = cat.get_unit(type)
	if def.is_empty():
		return false
	var cost: Dictionary = def.get("cost", {})
	for k in cost:
		if get_stock(k) < float(cost[k]) * float(n):
			return false
	for k in cost:
		var r: Dictionary = resources.get(k, {})
		if not r.is_empty():
			r["stock"] = maxf(0.0, float(r["stock"]) - float(cost[k]) * float(n))
			r["stock"] = clampf(float(r["stock"]), 0.0, 999999.0)
	military[type]["count"] = int(military[type]["count"]) + n
	military[type]["morale"] = clampf(float(military[type]["morale"]) + 0.02, 0.1, 1.0)
	resources_changed.emit()
	military_changed.emit()
	return true

func military_power(terrain: String = "plains") -> float:
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("calc_power"):
		return mil.calc_power(military, terrain)
	var s: float = 0.0
	for id in military.keys():
		var c: int = int(military[id].get("count", 0))
		var def: Dictionary = {}
		var cat: Node = get_node_or_null("/root/Catalog")
		if cat != null and cat.has_method("get_unit"):
			def = cat.get_unit(id)
		var st: float = float(def.get("strength", 5.0))
		s += float(c) * st * float(military[id].get("morale", 0.7))
	return s

func resolve_battle(attacker_power: float, defender_power: float, terrain: String = "plains") -> Dictionary:
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("resolve_battle"):
		return mil.resolve_battle(attacker_power, defender_power, terrain)
	var total: float = attacker_power + defender_power
	var roll: float = _rng.randf() * total
	var win: bool = roll < attacker_power
	return {"winner": "attacker" if win else "defender", "attacker_power": attacker_power, "defender_power": defender_power, "terrain": terrain}

func auto_resolve(attackers: Dictionary, defenders: Dictionary, terrain: String = "plains") -> Dictionary:
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("auto_resolve"):
		var r: Dictionary = mil.auto_resolve(attackers, defenders, terrain)
		military = mil.units.duplicate(true)
		military_changed.emit()
		return r
	var ap: float = 0.0
	var dp: float = 0.0
	for k in attackers.keys():
		var v: Variant = attackers[k]
		var c: int = int(v.get("count", 0)) if typeof(v)==TYPE_DICTIONARY else int(v)
		ap += float(c) * 5.0
	for k in defenders.keys():
		var v2: Variant = defenders[k]
		var c2: int = int(v2.get("count", 0)) if typeof(v2)==TYPE_DICTIONARY else int(v2)
		dp += float(c2) * 5.0
	return resolve_battle(ap, dp, terrain)

func _apply_military_upkeep() -> void:
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("apply_seasonal_upkeep"):
		mil.units = military.duplicate(true)
		mil.apply_seasonal_upkeep(season())
		military = mil.units.duplicate(true)
		return
	var sm: Dictionary = _bal("military_upkeep.season_mult", {}) as Dictionary
	var mult: float = float(sm.get(season(), 1.35 if season() == "winter" else (1.05 if season() == "autumn" else 1.0)))
	var upkeep: Dictionary = {}
	for id in military.keys():
		var cnt: int = int(military[id].get("count", 0))
		if cnt <= 0:
			continue
		var def: Dictionary = {}
		var cat: Node = get_node_or_null("/root/Catalog")
		if cat != null and cat.has_method("get_unit"):
			def = cat.get_unit(id)
		var up: Dictionary = def.get("upkeep", {})
		for k in up:
			upkeep[k] = float(upkeep.get(k, 0.0)) + float(up[k]) * float(cnt) * mult
	var shortage: bool = false
	for k in upkeep:
		var need: float = float(upkeep[k])
		var stock: float = get_stock(k)
		var pay: float = minf(stock, need)
		var r: Dictionary = resources.get(k, {})
		if not r.is_empty():
			r["stock"] = maxf(0.0, stock - pay)
		if pay < need - 0.01:
			shortage = true
	if shortage:
		var pen_morale: float = float(_bal("military_upkeep.shortage_penalty.morale", -0.07))
		var pen_supply: float = float(_bal("military_upkeep.shortage_penalty.supply", -0.12))
		for id in military.keys():
			if int(military[id].get("count", 0)) > 0:
				military[id]["morale"] = maxf(0.1, float(military[id].get("morale", 0.7)) + pen_morale)
				military[id]["supply"] = maxf(0.2, float(military[id].get("supply", 1.0)) + pen_supply)
		var ev := {"id": events.size(), "turn": turn, "type": "upkeep_shortage", "severity": 1, "text": "Coin runs short — troops grumble, supplies thin."}
		events.push_front(ev)
		event_occurred.emit(ev)
		resources_changed.emit()
		military_changed.emit()

func apply_start_config(cfg: Dictionary) -> void:
	reset()
	settings.world_seed = int(cfg.get("world_seed", settings.world_seed))
	settings.era = str(cfg.get("era", settings.era)).to_lower()
	settings.difficulty = str(cfg.get("difficulty", settings.difficulty)).to_lower()
	settings.kingdom_name = str(cfg.get("kingdom_name", settings.kingdom_name))
	settings.banner_color = str(cfg.get("banner_color", settings.banner_color))
	settings.sigil = str(cfg.get("sigil", settings.sigil)).to_lower()
	settings.gov = str(cfg.get("gov", settings.gov)).to_lower()
	settings.religion = str(cfg.get("religion", settings.religion)).to_lower()
	settings.culture = str(cfg.get("culture", settings.culture)).to_lower()
	settings.ruler_name = str(cfg.get("ruler_name", settings.ruler_name))
	settings.ruler_age = int(cfg.get("ruler_age", settings.ruler_age))
	settings.ruler_gender = str(cfg.get("ruler_gender", settings.ruler_gender)).to_lower()
	var tr: Variant = cfg.get("traits", [])
	if typeof(tr) == TYPE_ARRAY:
		settings.traits = tr
	settings.legacy_path = str(cfg.get("legacy_path", settings.legacy_path)).to_lower()
	settings.territory_size = str(cfg.get("territory_size", settings.territory_size)).to_lower()
	settings.rivals = clampi(int(cfg.get("rivals", settings.rivals)), 2, 5)
	settings.scenario = str(cfg.get("scenario", settings.scenario)).to_lower()
	settings.starting_season = str(cfg.get("starting_season", settings.starting_season)).to_lower()
	var res_cfg: Variant = cfg.get("resources", {})
	if typeof(res_cfg) == TYPE_DICTIONARY:
		for k in RESOURCE_KEYS:
			if (res_cfg as Dictionary).has(k):
				resources[k]["stock"] = clampf(float((res_cfg as Dictionary)[k]), 0.0, 200.0)
	var cap_map: Dictionary = _bal("population.capacity_base_by_territory", {"small": 40.0, "medium": 60.0, "large": 90.0, "huge": 120.0}) as Dictionary
	pop_capacity_base = float(cap_map.get(settings.territory_size, 60.0))
	pop_count = pop_capacity_base * float(_bal("population.initial_pop_ratio", 0.83))
	var season_month := {"spring": 3, "summer": 6, "autumn": 9, "winter": 12}
	month = int(season_month.get(settings.starting_season, 3))
	year = 0
	turn = month - 1
	var sd: int = int(settings.world_seed)
	if sd == 0:
		sd = 1
	_rng.seed = sd
	_rng.state = sd if sd != 0 else 1
	if _rng.state == 0:
		_rng.state = 1
	_rng.randf()
	var dip: Node = get_node_or_null("/root/Diplomacy")
	if dip != null and dip.has_method("generate_rivals"):
		dip.call("generate_rivals", int(settings.rivals), int(settings.world_seed))
	resources_changed.emit()
	population_changed.emit()

func serialize() -> Dictionary:
	var mission_data: Dictionary = {}
	var mn: Node = get_node_or_null("/root/Missions")
	if mn != null and mn.has_method("serialize"):
		mission_data = mn.call("serialize") as Dictionary
	else:
		mission_data = {"current_act_idx": 0, "active": [], "completed": [], "failed": [], "act_history": [], "crisis_survived": _crisis_survived}
	mission_data["crisis_survived"] = _crisis_survived
	var event_data: Dictionary = {}
	var evn: Node = get_node_or_null("/root/Events")
	if evn != null and evn.has_method("serialize"):
		event_data = evn.call("serialize") as Dictionary
	else:
		event_data = {"cooldown": _event_cooldown.duplicate(true)}
	var chron_data: Array = []
	var chron: Node = get_node_or_null("/root/Chronicle")
	if chron != null and chron.has_method("serialize"):
		chron_data = chron.call("serialize") as Array
	return {
		"meta": {
			"version": SAVE_VERSION,
			"saveDate": Time.get_datetime_string_from_system(),
			"turnCount": turn,
			"kingdomName": settings.kingdom_name,
		},
		"gameState": {
			"resources": resources,
			"population": {
				"count": pop_count,
				"capacity": pop_capacity_base + building_cap.get("housing", 0.0),
				"happiness": pop_happiness,
			},
			"buildings": placed_buildings,
			"military": get_node_or_null("/root/Military").call("serialize") if has_node("/root/Military") and get_node("/root/Military").has_method("serialize") else military,
			"diplomacy": get_node_or_null("/root/Diplomacy").call("serialize") if has_node("/root/Diplomacy") and get_node("/root/Diplomacy").has_method("serialize") else {},
			"tech": get_node_or_null("/root/Tech").call("serialize") if has_node("/root/Tech") and get_node("/root/Tech").has_method("serialize") else {},
		},
		"eventHistory": events,
		"missionLog": mission_data,
		"storyProgress": mission_data,
		"chronicle": chron_data,
		"settings": settings,
		"ceState": {
			"nextEventId": events.size(),
			"rngState": _rng.state,
			"buildingProd": building_prod,
			"buildingCons": building_cons,
			"buildingCap": building_cap,
			"tech": get_node_or_null("/root/Tech").call("serialize") if has_node("/root/Tech") and get_node("/root/Tech").has_method("serialize") else {},
			"eventCooldown": event_data.get("cooldown", _event_cooldown),
			"crisisSurvived": _crisis_survived,
		},
	}

func save_to_file(path: String = "user://saves/slot_0.json") -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % path)
		return false
	f.store_string(JSON.stringify(serialize(), "\t"))
	f.close()
	return true

func load_from_file(path: String = "user://saves/slot_0.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	_restore(parsed)
	return true

func _restore(data: Dictionary) -> void:
	var meta: Dictionary = data.get("meta", {})
	var ver: int = int(meta.get("version", 1))
	if ver < SAVE_VERSION:
		data = _migrate_save(data, ver)
	var state: Dictionary = data.get("gameState", {})
	var res_in: Variant = state.get("resources", resources)
	if typeof(res_in) == TYPE_DICTIONARY:
		for k in ALL_KEYS:
			if not (res_in as Dictionary).has(k):
				(res_in as Dictionary)[k] = {"stock": 100.0 if RESOURCE_KEYS.has(k) else 0.0, "prod": _base_production(k), "cons": _base_consumption(k)}
			else:
				var rv: Dictionary = (res_in as Dictionary)[k] as Dictionary
				rv["stock"] = clampf(float(rv.get("stock", 0.0)), 0.0, 99999.0)
				rv["prod"] = float(rv.get("prod", _base_production(k)))
				rv["cons"] = float(rv.get("cons", _base_consumption(k)))
		resources = res_in as Dictionary
	else:
		resources = resources
	var pb: Array = state.get("buildings", placed_buildings)
	placed_buildings.clear()
	for e in pb:
		if typeof(e) == TYPE_DICTIONARY:
			placed_buildings.append(e)
	var eh: Array = data.get("eventHistory", [])
	events.clear()
	for e in eh:
		if typeof(e) == TYPE_DICTIONARY:
			events.append(e)
	var incoming_settings: Variant = data.get("settings", null)
	if typeof(incoming_settings) == TYPE_DICTIONARY:
		for k in settings.keys():
			if (incoming_settings as Dictionary).has(k):
				settings[k] = (incoming_settings as Dictionary)[k]
	turn = int(meta.get("turnCount", data.get("turn", 0)))
	year = turn / TURNS_PER_YEAR
	month = (turn % TURNS_PER_YEAR) + 1
	month = clampi(month, 1, 12)
	var pop: Dictionary = state.get("population", {})
	pop_count = maxf(0.0, float(pop.get("count", pop_count)))
	pop_happiness = clampf(float(pop.get("happiness", pop.get("pop_happiness", pop_happiness))), 0.0, 1.0)
	pop_count = clampf(pop_count, 0.0, 99999.0)
	var ce: Dictionary = data.get("ceState", {})
	building_prod = ce.get("buildingProd", {})
	building_cons = ce.get("buildingCons", {})
	building_cap = ce.get("buildingCap", {})
	_event_cooldown = ce.get("eventCooldown", {})
	if typeof(_event_cooldown) != TYPE_DICTIONARY:
		_event_cooldown = {}
	_crisis_survived = int(ce.get("crisisSurvived", 0))
	var rngs: Variant = ce.get("rngState", null)
	if rngs != null:
		var rs: int = int(rngs)
		_rng.state = rs if rs != 0 else 1
		if _rng.state == 0:
			_rng.state = 1
	var mission_data: Variant = data.get("missionLog", data.get("storyProgress", {}))
	if typeof(mission_data) == TYPE_DICTIONARY and mission_data.size() > 0:
		_crisis_survived = int((mission_data as Dictionary).get("crisis_survived", _crisis_survived))
		var mn: Node = get_node_or_null("/root/Missions")
		if mn != null and mn.has_method("restore"):
			mn.call("restore", mission_data)
		if (mission_data as Dictionary).has("eventCooldown"):
			_event_cooldown = (mission_data as Dictionary).get("eventCooldown", _event_cooldown)
	var evn: Node = get_node_or_null("/root/Events")
	if evn != null and evn.has_method("restore"):
		evn.call("restore", {"cooldown": _event_cooldown})
	var mil_data: Variant = state.get("military", {})
	if typeof(mil_data) == TYPE_DICTIONARY and not (mil_data as Dictionary).is_empty():
		military.clear()
		for k in (mil_data as Dictionary).keys():
			var v: Variant = (mil_data as Dictionary)[k]
			if typeof(v) == TYPE_DICTIONARY:
				military[k] = {"count": int(v.get("count", 0)), "morale": float(v.get("morale", 0.7)), "supply": float(v.get("supply", 1.0)), "experience": float(v.get("experience", 0.0)), "commander": str(v.get("commander", "none"))}
		if has_node("/root/Military"):
			var mil: Node = get_node("/root/Military")
			if mil.has_method("restore"):
				mil.call("restore", mil_data)
	else:
		_init_military_defaults()
	var tech_data: Variant = state.get("tech", ce.get("tech", {}))
	if typeof(tech_data) == TYPE_DICTIONARY and has_node("/root/Tech"):
		var tn3: Node = get_node("/root/Tech")
		if tn3.has_method("deserialize"):
			tn3.call("deserialize", tech_data)
	var dip_data: Variant = state.get("diplomacy", {})
	if typeof(dip_data) == TYPE_DICTIONARY and has_node("/root/Diplomacy"):
		var dip: Node = get_node("/root/Diplomacy")
		if dip.has_method("restore"):
			dip.call("restore", dip_data)
	var chron_data: Variant = data.get("chronicle", [])
	if typeof(chron_data) == TYPE_ARRAY and has_node("/root/Chronicle"):
		var chron: Node = get_node("/root/Chronicle")
		if chron.has_method("restore"):
			chron.call("restore", chron_data)
	resources_changed.emit()
	population_changed.emit()
	military_changed.emit()

func _migrate_save(data: Dictionary, from_ver: int) -> Dictionary:
	var v: int = from_ver
	if v < 2:
		if not data.has("ceState"):
			data["ceState"] = {}
		if not data.has("meta"):
			data["meta"] = {"version": 2, "turnCount": 0}
		v = 2
	if v < 3:
		var gs: Dictionary = data.get("gameState", {})
		if not gs.has("resources"):
			gs["resources"] = resources.duplicate(true)
		for k in ["grain", "flour"]:
			if not (gs["resources"] as Dictionary).has(k):
				(gs["resources"] as Dictionary)[k] = {"stock": 0.0, "prod": _base_production(k), "cons": _base_consumption(k)}
		data["gameState"] = gs
		v = 3
	if v < 4:
		var ce2: Dictionary = data.get("ceState", {})
		if not ce2.has("buildingCap"):
			ce2["buildingCap"] = {}
		if not ce2.has("crisisSurvived"):
			ce2["crisisSurvived"] = ce2.get("crisis_survived", 0)
		data["ceState"] = ce2
		var meta2: Dictionary = data.get("meta", {})
		meta2["version"] = SAVE_VERSION
		data["meta"] = meta2
		v = 4
	return data
