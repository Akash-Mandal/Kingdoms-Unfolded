extends Node

signal diplomacy_changed
signal relation_changed(kingdom_id: String)
signal treaty_changed(kingdom_id: String, treaty_id: String)

const MEMORY_SIZE := 16
const CULTURES: PackedStringArray = ["highland", "lowland", "desert", "northern", "riverfolk", "imperial"]
const RIVAL_NAME_POOL: PackedStringArray = [
	"Albion", "Nordhold", "Sungard", "Drakmoor", "Evershade", "Ironmere",
	"Valdris", "Caelora", "Brantholm", "Myrrdin", "Kethra", "Osswold",
	"Ravenspire", "Highmere", "Dunhollow", "Silverhollow"
]
const SIGIL_POOL: PackedStringArray = ["eagle", "lion", "dragon", "wolf", "bear", "stag", "raven", "sun"]
const BANNER_COLORS: PackedStringArray = ["#6a3a2a", "#2a5a8a", "#3a7a3a", "#8a3a5a", "#5a4a8a", "#8a6a2a", "#2a8a7a", "#7a2a2a"]

var kingdoms: Dictionary = {}
var relations: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _turn_cache := 0
var _last_tick_turn := -1

class RingBuffer:
	var capacity: int
	var _data: Array
	var _head: int = 0
	var _count: int = 0
	func _init(cap: int) -> void:
		capacity = cap
		_data.resize(cap)
	func push(v: Variant) -> void:
		_data[_head] = v
		_head = (_head + 1) % capacity
		if _count < capacity:
			_count += 1
	func to_array() -> Array:
		var out: Array = []
		for i in _count:
			var idx: int = (_head - _count + i) % capacity
			if idx < 0:
				idx += capacity
			out.append(_data[idx])
		return out
	func from_array(arr: Array) -> void:
		_count = 0
		_head = 0
		for v in arr:
			push(v)
	func size() -> int:
		return _count
	func clear() -> void:
		_count = 0
		_head = 0

func _ready() -> void:
	_rng.randomize()
	if has_node("/root/TimeClock"):
		var tc: Node = get_node("/root/TimeClock")
		if tc.has_signal("month_ended"):
			tc.month_ended.connect(tick)
		call_deferred("_deferred_bind_game")

func _player_power() -> float:
	if has_node("/root/Game"):
		var g: Variant = get_node("/root/Game")
		var pop: float = float(g.get("pop_count")) if "pop_count" in g else 50.0
		var gold: float = 0.0
		var food: float = 0.0
		if "resources" in g and g.resources is Dictionary:
			gold = float(g.resources.get("gold", {}).get("stock", 0.0))
			food = float(g.resources.get("food", {}).get("stock", 0.0))
		return pop * 1.2 + gold * 0.35 + food * 0.15
	return 60.0

func generate_rivals(count: int, base_seed: int) -> void:
	count = clampi(count, 2, 5)
	kingdoms.clear()
	relations.clear()
	_rng.seed = int(base_seed) ^ 0x9E3779B9
	if base_seed == 0:
		_rng.randomize()
	var used_names: Dictionary = {}
	for i in count:
		var id: String = "kingdom_%d" % i
		var name: String = ""
		for _t in 20:
			var cand: String = RIVAL_NAME_POOL[_rng.randi() % RIVAL_NAME_POOL.size()]
			if not used_names.has(cand):
				name = cand
				used_names[cand] = true
				break
			name = cand
		var culture: String = CULTURES[_rng.randi() % CULTURES.size()]
		var power: float = _rng.randf_range(45.0, 135.0)
		var ambition: float = _rng.randf_range(0.2, 0.92)
		var banner: String = BANNER_COLORS[_rng.randi() % BANNER_COLORS.size()]
		var sigil: String = SIGIL_POOL[_rng.randi() % SIGIL_POOL.size()]
		kingdoms[id] = {
			"id": id,
			"name": name,
			"culture": culture,
			"power": power,
			"ambition": ambition,
			"banner_color": banner,
			"sigil": sigil,
		}
		var rb := RingBuffer.new(MEMORY_SIZE)
		relations[id] = {
			"score": _rng.randi_range(-18, 18),
			"trust": clampf(_rng.randf_range(-0.18, 0.18), -1.0, 1.0),
			"treaty": "none",
			"memory": rb,
			"last_event": 0,
		}
	diplomacy_changed.emit()

func ensure_relations() -> void:
	for id in kingdoms:
		if not relations.has(id):
			var rb := RingBuffer.new(MEMORY_SIZE)
			relations[id] = {"score": 0, "trust": 0.0, "treaty": "none", "memory": rb, "last_event": 0}

func get_relation(kingdom_id: String) -> Dictionary:
	return relations.get(kingdom_id, {})

func get_kingdom(kingdom_id: String) -> Dictionary:
	return kingdoms.get(kingdom_id, {})

func kingdom_ids() -> Array:
	return kingdoms.keys()

func _relation_for(kingdom_id: String) -> Dictionary:
	if not relations.has(kingdom_id):
		var rb := RingBuffer.new(MEMORY_SIZE)
		relations[kingdom_id] = {"score": 0, "trust": 0.0, "treaty": "none", "memory": rb, "last_event": 0}
	return relations[kingdom_id]

func modify_score(kingdom_id: String, delta: int, tag: String = "") -> void:
	var r: Dictionary = _relation_for(kingdom_id)
	r["score"] = clampi(int(r["score"]) + delta, -100, 100)
	if tag != "":
		_push_memory(r, {"turn": _current_turn(), "tag": tag, "score_delta": delta})
	r["last_event"] = _current_turn()
	relation_changed.emit(kingdom_id)
	diplomacy_changed.emit()

func modify_trust(kingdom_id: String, delta: float) -> void:
	var r: Dictionary = _relation_for(kingdom_id)
	r["trust"] = clampf(float(r["trust"]) + delta, -1.0, 1.0)
	r["last_event"] = _current_turn()
	relation_changed.emit(kingdom_id)
	diplomacy_changed.emit()

func set_treaty(kingdom_id: String, treaty_id: String) -> bool:
	var valid: PackedStringArray = ["none", "non_aggression_pact", "nap", "trade_agreement", "royal_marriage", "marriage", "alliance", "vassalage", "confederation"]	if not valid.has(treaty_id):
		return false
	var norm: String = _normalize_treaty(treaty_id)
	var r: Dictionary = _relation_for(kingdom_id)
	var prev: String = String(r["treaty"])
	if prev == norm:
		return false
	r["treaty"] = norm
	var bonus: Dictionary = _treaty_bonus(norm)
	if bonus.has("score_bonus"):
		r["score"] = clampi(int(r["score"]) + int(bonus["score_bonus"]), -100, 100)
	if bonus.has("trust_bonus"):
		r["trust"] = clampf(float(r["trust"]) + float(bonus["trust_bonus"]), -1.0, 1.0)
	_push_memory(r, {"turn": _current_turn(), "tag": "treaty:%s" % norm, "score_delta": int(bonus.get("score_bonus", 0))})
	r["last_event"] = _current_turn()
	treaty_changed.emit(kingdom_id, norm)
	diplomacy_changed.emit()
	return true

func break_treaty(kingdom_id: String) -> bool:
	var r: Dictionary = _relation_for(kingdom_id)
	var cur: String = String(r["treaty"])
	if cur == "none":
		return false
	var penalty: Dictionary = _treaty_break_penalty(cur)
	r["treaty"] = "none"
	if penalty.has("score_delta"):
		r["score"] = clampi(int(r["score"]) + int(penalty["score_delta"]), -100, 100)
	if penalty.has("trust_delta"):
		r["trust"] = clampf(float(r["trust"]) + float(penalty["trust_delta"]), -1.0, 1.0)
	_push_memory(r, {"turn": _current_turn(), "tag": penalty.get("memory_tag", "betrayal"), "score_delta": int(penalty.get("score_delta", 0))})
	r["last_event"] = _current_turn()
	treaty_changed.emit(kingdom_id, "none")
	diplomacy_changed.emit()
	return true

func gift_to(kingdom_id: String, gold_amount: int = 10) -> bool:
	var g: Variant = get_node_or_null("/root/Game")
	var cost: int = clampi(gold_amount, 5, 50)	if g != null and "resources" in g and g.resources is Dictionary:
		var stock: float = float(g.resources.get("gold", {}).get("stock", 999.0))
		if stock < float(cost):
			return false
		g.resources["gold"]["stock"] = stock - float(cost)
		if g.has_signal("resources_changed"):
			g.resources_changed.emit()
	var r: Dictionary = _relation_for(kingdom_id)
	var gain: int = clampi(int(cost * 0.7 + 4), 3, 22)
	r["score"] = clampi(int(r["score"]) + gain, -100, 100)
	r["trust"] = clampf(float(r["trust"]) + 0.06, -1.0, 1.0)
	_push_memory(r, {"turn": _current_turn(), "tag": "gift", "score_delta": gain, "gold": cost})
	r["last_event"] = _current_turn()
	diplomacy_changed.emit()
	relation_changed.emit(kingdom_id)
	return true

func tribute_income() -> float:
	var total: float = 0.0
	for kid in relations.keys():
		var r: Dictionary = relations[kid] as Dictionary
		match str(r.get("treaty", "none")):
			"vassalage":
				total += 6.0
			"trade_agreement":
				total += 3.0
			"alliance":
				total += 1.0
	return total

func _apply_raid_damage(kingdom_id: String) -> void:
	if not has_node("/root/Game"):
		return
	var g: Variant = get_node("/root/Game")
	if not ("resources" in g and g.resources is Dictionary):
		return
	# Small raid: steal 4-10 gold, 2-6 food if undefended.
	var mil: Node = get_node_or_null("/root/Military")
	var power: float = 0.0
	if mil != null and mil.has_method("total_strength"):
		power = float(mil.call("total_strength"))
	var scale: float = clampf(1.0 - power / 200.0, 0.3, 1.0)
	var gold_hit: float = float(_rng.randi_range(4, 10)) * scale
	var food_hit: float = float(_rng.randi_range(2, 6)) * scale
	if g.resources.has("gold"):
		g.resources["gold"]["stock"] = maxf(0.0, float(g.resources["gold"]["stock"]) - gold_hit)
	if g.resources.has("food"):
		g.resources["food"]["stock"] = maxf(0.0, float(g.resources["food"]["stock"]) - food_hit)

func _normalize_treaty(t: String) -> String:
	match t:
		"nap": return "non_aggression_pact"
		"marriage": return "royal_marriage"
		_: return t

func _treaty_bonus(treaty_id: String) -> Dictionary:
	var cat: Variant = get_node_or_null("/root/Catalog")
	if cat != null and "treaties" in cat and cat.treaties is Dictionary and cat.treaties.has(treaty_id):
		var entry: Dictionary = cat.treaties[treaty_id]
		return entry.get("effects", {})
	match treaty_id:
		"non_aggression_pact": return {"score_bonus": 8, "trust_bonus": 0.08}
		"trade_agreement": return {"score_bonus": 10, "trust_bonus": 0.06}
		"royal_marriage": return {"score_bonus": 28, "trust_bonus": 0.22}
		"alliance": return {"score_bonus": 22, "trust_bonus": 0.15}
		"vassalage": return {"score_bonus": 12, "trust_bonus": -0.05}
		"confederation": return {"score_bonus": 18, "trust_bonus": 0.18}
		_: return {}

func _treaty_break_penalty(treaty_id: String) -> Dictionary:
	var cat: Variant = get_node_or_null("/root/Catalog")
	if cat != null and "treaties" in cat and cat.treaties is Dictionary and cat.treaties.has(treaty_id):
		var entry: Dictionary = cat.treaties[treaty_id]
		return entry.get("break_penalty", {"score_delta": -25, "trust_delta": -0.3, "memory_tag": "betrayal"})
	match treaty_id:
		"non_aggression_pact": return {"score_delta": -25, "trust_delta": -0.35, "memory_tag": "betrayal"}
		"trade_agreement": return {"score_delta": -15, "trust_delta": -0.2, "memory_tag": "trade_break"}
		"royal_marriage": return {"score_delta": -45, "trust_delta": -0.5, "memory_tag": "betrayal"}
		"alliance": return {"score_delta": -30, "trust_delta": -0.4, "memory_tag": "betrayal"}
		"vassalage": return {"score_delta": -35, "trust_delta": -0.45, "memory_tag": "rebellion"}
		"confederation": return {"score_delta": -40, "trust_delta": -0.5, "memory_tag": "betrayal"}
		_: return {"score_delta": -10, "trust_delta": -0.2, "memory_tag": "betrayal"}

func _push_memory(r: Dictionary, evt: Dictionary) -> void:
	var mem: Variant = r.get("memory", null)
	if mem is RingBuffer:
		(mem as RingBuffer).push(evt)
	elif mem is Array:
		var rb := RingBuffer.new(MEMORY_SIZE)
		rb.from_array(mem)
		rb.push(evt)
		r["memory"] = rb
	else:
		var rb2 := RingBuffer.new(MEMORY_SIZE)
		rb2.push(evt)
		r["memory"] = rb2

func _memory_weight(r: Dictionary, tag: String) -> int:
	var mem: Variant = r.get("memory", null)
	var arr: Array = []
	if mem is RingBuffer:
		arr = (mem as RingBuffer).to_array()
	elif mem is Array:
		arr = mem
	var cnt := 0
	var recency := 0
	for i in range(arr.size() - 1, -1, -1):
		var e: Variant = arr[i]
		if e is Dictionary and String((e as Dictionary).get("tag", "")) == tag:
			cnt += 1
			recency = max(recency, arr.size() - i)
	return cnt * (1 + recency)

func _current_turn() -> int:
	var g: Node = get_node_or_null("/root/Game")
	if g != null and "turn" in g:
		return int(g.get("turn")) if g.has_method("get") else _turn_cache
	return _turn_cache

func ai_utility(kingdom_id: String) -> Dictionary:
	var r: Dictionary = _relation_for(kingdom_id)
	var k: Dictionary = get_kingdom(kingdom_id)
	var score: int = int(r.get("score", 0))
	var trust: float = float(r.get("trust", 0.0))
	var treaty: String = String(r.get("treaty", "none"))
	var power: float = float(k.get("power", 70.0))
	var ambition: float = float(k.get("ambition", 0.5))
	var player_pwr: float = _player_power()
	var ratio: float = power / maxf(player_pwr, 1.0)
	var betray_mem: int = _memory_weight(r, "betrayal")
	var gift_mem: int = _memory_weight(r, "gift")
	var war: float = 0.0
	war += clampf((-float(score)) * 0.42, 0.0, 42.0)
	war += (1.0 - trust) * 18.0
	war += clampf((ratio - 0.9) * 28.0, -12.0, 26.0)
	war += ambition * 22.0
	war -= betray_mem * 2.5
	if treaty != "none" and treaty != "trade_agreement":
		war -= 16.0
	if treaty == "non_aggression_pact" or treaty == "alliance" or treaty == "confederation" or treaty == "royal_marriage":
		war -= 14.0
	war += _rng.randf_range(-5.0, 5.0)
	var trade: float = 0.0
	trade += clampf(float(score) * 0.32, -12.0, 32.0)
	trade += trust * 16.0
	trade += (1.0 - absf(ratio - 1.0)) * 14.0
	trade += (1.0 - ambition) * 6.0
	if treaty == "trade_agreement":
		trade -= 10.0
	else:
		trade += 9.0
	trade += gift_mem * 1.2
	trade += _rng.randf_range(-4.0, 4.0)
	var marry: float = 0.0
	marry += float(score) * 0.42
	marry += trust * 22.0
	marry -= absf(ratio - 1.0) * 8.0
	marry += (0.55 - ambition) * 8.0
	if treaty == "royal_marriage" or treaty == "confederation":
		marry = -50.0
	elif score < 30 or trust < 0.28:
		marry -= 18.0
	else:
		marry += 14.0
	marry += _rng.randf_range(-5.0, 5.0)
	var betray: float = 0.0
	if treaty == "none":
		betray = -28.0
	else:
		betray += 14.0
		betray += ambition * 24.0
		betray += (0.3 - trust) * 14.0
		betray += clampf((ratio - 1.0) * 12.0, -6.0, 14.0)
		betray += _rng.randf_range(-6.0, 6.0)
		if treaty == "royal_marriage" or treaty == "alliance":
			betray -= 6.0
	var gift: float = 0.0
	if score < 12:
		gift += (12.0 - float(score)) * 0.38
	else:
		gift += 4.0
	gift += trust * 6.0
	gift += (1.0 - ambition) * 7.0
	if treaty != "none":
		gift += 3.0
	gift -= betray_mem * 1.0
	if score > 55 and trust > 0.5:
		gift -= 10.0
	gift += _rng.randf_range(-4.0, 4.0)
	return {"war": war, "trade": trade, "marry": marry, "betray": betray, "gift": gift}

func decide(kingdom_id: String) -> String:
	var u: Dictionary = ai_utility(kingdom_id)
	var best: String = "gift"
	var best_v: float = -1e9
	for k in u:
		var v: float = float(u[k])
		if v > best_v:
			best_v = v
			best = String(k)
	return best if best_v > -6.0 else "none"

func _deferred_bind_game() -> void:
	var g: Node = get_node_or_null("/root/Game")
	if g != null and g.has_signal("turned"):
		if not g.turned.is_connected(tick):
			g.turned.connect(tick)

func tick() -> void:
	_turn_cache = _current_turn()
	if _last_tick_turn == _turn_cache:
		return
	_last_tick_turn = _turn_cache
	if kingdoms.is_empty():
		return
	for kid in kingdoms.keys():
		var r: Dictionary = relations.get(kid, {})
		if r.is_empty():
			continue
		var trust: float = float(r.get("trust", 0.0))
		trust = lerpf(trust, 0.0, 0.045)
		r["trust"] = clampf(trust + _rng.randf_range(-0.012, 0.012), -1.0, 1.0)
		var score: int = int(r.get("score", 0))
		if score > 0:
			score = maxi(0, score - _rng.randi_range(0, 1))
		elif score < 0:
			score = mini(0, score + _rng.randi_range(0, 1))
		r["score"] = clampi(score, -100, 100)
		var treaty: String = String(r.get("treaty", "none"))
		if treaty != "none" and treaty != "royal_marriage" and treaty != "confederation":
			var months_held: int = _turn_cache - int(r.get("last_event", 0))
			var dur: int = _treaty_duration(treaty)
			if dur > 0 and months_held >= dur:
				if _rng.randf() < 0.32:
					r["treaty"] = "none"
					_push_memory(r, {"turn": _turn_cache, "tag": "treaty_expired:%s" % treaty, "score_delta": -2})
					treaty_changed.emit(kid, "none")
		if _rng.randf() < 0.38:
			var choice: String = decide(kid)
			_apply_ai_action(kid, choice)
	diplomacy_changed.emit()

func _treaty_duration(treaty_id: String) -> int:
	var cat: Variant = get_node_or_null("/root/Catalog")
	if cat != null and "treaties" in cat and cat.treaties is Dictionary and cat.treaties.has(treaty_id):
		return int(cat.treaties[treaty_id].get("duration_months", -1))
	match treaty_id:
		"non_aggression_pact": return 12
		"trade_agreement": return 18
		"alliance": return 24
		"vassalage": return 36
		_: return -1

func _apply_ai_action(kingdom_id: String, action: String) -> void:
	var r: Dictionary = _relation_for(kingdom_id)
	var k: Dictionary = get_kingdom(kingdom_id)
	match action:
		"war":
			if String(r["treaty"]) == "non_aggression_pact" or String(r["treaty"]) == "alliance" or String(r["treaty"]) == "royal_marriage" or String(r["treaty"]) == "confederation":
				if _rng.randf() < 0.72:
					return
			r["score"] = clampi(int(r["score"]) - _rng.randi_range(10, 18), -100, 100)
			r["trust"] = clampf(float(r["trust"]) - _rng.randf_range(0.08, 0.15), -1.0, 1.0)
			_push_memory(r, {"turn": _turn_cache, "tag": "war_threat", "score_delta": -12})
			_emit_diplo_event(kingdom_id, "war", "%s rattles sabres at our borders!" % String(k.get("name", kingdom_id)))
			_apply_raid_damage(kingdom_id)
		"trade":
			if String(r["treaty"]) == "trade_agreement":
				return
			if int(r["score"]) < -8 or float(r["trust"]) < -0.22:
				return
			r["score"] = clampi(int(r["score"]) + _rng.randi_range(4, 9), -100, 100)
			r["trust"] = clampf(float(r["trust"]) + _rng.randf_range(0.02, 0.06), -1.0, 1.0)
			_push_memory(r, {"turn": _turn_cache, "tag": "trade", "score_delta": 6})
			_emit_diplo_event(kingdom_id, "trade", "%s proposes a trade agreement." % String(k.get("name", kingdom_id)))
		"marry":
			if String(r["treaty"]) != "none":
				return
			if int(r["score"]) < 30 or float(r["trust"]) < 0.28:
				return
			r["score"] = clampi(int(r["score"]) + 10, -100, 100)
			_push_memory(r, {"turn": _turn_cache, "tag": "marriage_offer", "score_delta": 10})
			_emit_diplo_event(kingdom_id, "marry", "%s offers a royal marriage to bind our houses." % String(k.get("name", kingdom_id)))
		"betray":
			if String(r["treaty"]) == "none":
				return
			r["score"] = clampi(int(r["score"]) - _rng.randi_range(18, 32), -100, 100)
			r["trust"] = clampf(float(r["trust"]) - _rng.randf_range(0.18, 0.32), -1.0, 1.0)
			var old: String = String(r["treaty"])
			r["treaty"] = "none"
			_push_memory(r, {"turn": _turn_cache, "tag": "betrayal", "score_delta": -28})
			treaty_changed.emit(kingdom_id, "none")
			_emit_diplo_event(kingdom_id, "betray", "%s has broken the %s!" % [String(k.get("name", kingdom_id)), old])
		"gift":
			if int(r.get("gift_cd", 0)) > _turn_cache:
				return
			r["gift_cd"] = _turn_cache + 6
			var amt: int = _rng.randi_range(6, 14)
			r["score"] = clampi(int(r["score"]) + _rng.randi_range(3, 7), -100, 100)
			r["trust"] = clampf(float(r["trust"]) + _rng.randf_range(0.02, 0.05), -1.0, 1.0)
			_push_memory(r, {"turn": _turn_cache, "tag": "gift", "score_delta": 4, "gold": amt})
			if has_node("/root/Game"):
				var g: Variant = get_node("/root/Game")
				if "resources" in g and g.resources is Dictionary and g.resources.has("gold"):
					g.resources["gold"]["stock"] = float(g.resources["gold"]["stock"]) + float(amt)
					if g.has_signal("resources_changed"):
						g.resources_changed.emit()
			_emit_diplo_event(kingdom_id, "gift", "%s sends a gift of %d gold." % [String(k.get("name", kingdom_id)), amt])
	r["last_event"] = _turn_cache
	relation_changed.emit(kingdom_id)

func _emit_diplo_event(kingdom_id: String, kind: String, text: String) -> void:
	if has_node("/root/Game"):
		var g: Variant = get_node("/root/Game")
		var evt: Dictionary = {"id": 0, "turn": _turn_cache, "type": "diplomacy_%s" % kind, "severity": 1, "text": text, "kingdom_id": kingdom_id}
		if "events" in g and g.events is Array:
			evt["id"] = g.events.size()
			g.events.push_front(evt)
		if g.has_signal("event_occurred"):
			g.event_occurred.emit(evt)

func serialize() -> Dictionary:
	var rel_out: Dictionary = {}
	for kid in relations:
		var r: Dictionary = relations[kid]
		var mem: Variant = r.get("memory", null)
		var arr: Array = []
		if mem is RingBuffer:
			arr = (mem as RingBuffer).to_array()
		elif mem is Array:
			arr = mem
		rel_out[kid] = {
			"score": int(r.get("score", 0)),
			"trust": float(r.get("trust", 0.0)),
			"treaty": String(r.get("treaty", "none")),
			"memory": arr,
			"last_event": int(r.get("last_event", 0)),
		}
	return {"kingdoms": kingdoms.duplicate(true), "relations": rel_out, "rng_state": _rng.state}

func restore(data: Dictionary) -> void:
	var kd: Variant = data.get("kingdoms", {})
	if kd is Dictionary:
		kingdoms = (kd as Dictionary).duplicate(true)
	var rd: Variant = data.get("relations", {})
	if rd is Dictionary:
		relations.clear()
		for kid in (rd as Dictionary).keys():
			var src: Dictionary = (rd as Dictionary)[kid]
			var rb := RingBuffer.new(MEMORY_SIZE)
			var mem: Variant = src.get("memory", [])
			if mem is Array:
				rb.from_array(mem)
			relations[kid] = {
				"score": int(src.get("score", 0)),
				"trust": float(src.get("trust", 0.0)),
				"treaty": String(src.get("treaty", "none")),
				"memory": rb,
				"last_event": int(src.get("last_event", 0)),
			}
	var rs: Variant = data.get("rng_state", null)
	if rs != null:
		_rng.state = int(rs)
	diplomacy_changed.emit()
