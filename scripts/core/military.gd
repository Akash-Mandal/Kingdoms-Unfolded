extends Node

signal military_changed
signal battle_resolved(result: Dictionary)

const TERRAIN_MODS := {
	"plains": 1.0,
	"forest": 0.85,
	"hills": 1.15,
	"mountain": 1.25,
	"desert": 0.9,
	"water": 0.7,
	"swamp": 0.75,
	"snow": 0.8,
}

const COMMANDER_BONUS := {
	"none": 1.0,
	"novice": 1.05,
	"veteran": 1.15,
	"legendary": 1.30,
}

var units: Dictionary = {}
var _catalog: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_load_catalog()
	_ensure_defaults()

func _load_catalog() -> void:
	var path := "res://data/catalog/units.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return
	for e in parsed:
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = e.get("id", "")
			if id != "":
				_catalog[id] = e

func _ensure_defaults() -> void:
	for id in _catalog.keys():
		if not units.has(id):
			units[id] = {"count": 0, "morale": 0.7, "supply": 1.0, "experience": 0.0, "commander": "none"}

func get_catalog(id: String) -> Dictionary:
	return _catalog.get(id, {})

func catalog_ids() -> Array:
	return _catalog.keys()

func ensure_unit(id: String) -> void:
	if not units.has(id):
		units[id] = {"count": 0, "morale": 0.7, "supply": 1.0, "experience": 0.0, "commander": "none"}
	if not _catalog.has(id) and Catalog != null and Catalog.has_method("get_unit"):
		var c: Dictionary = Catalog.get_unit(id)
		if not c.is_empty():
			_catalog[id] = c

func train(type: String, n: int) -> bool:
	if n <= 0:
		return false
	ensure_unit(type)
	var def: Dictionary = _catalog.get(type, {})
	if def.is_empty():
		if Catalog != null and Catalog.has_method("get_unit"):
			def = Catalog.get_unit(type)
		if def.is_empty():
			return false
	var cost: Dictionary = def.get("cost", {})
	for k in cost:
		if typeof(Game.resources.get(k, {})) == TYPE_DICTIONARY:
			if float(Game.resources[k]["stock"]) < float(cost[k]) * float(n):
				return false
		else:
			if Game.get_stock(k) < float(cost[k]) * float(n):
				return false
	for k in cost:
		var r: Dictionary = Game.resources.get(k, {})
		if not r.is_empty():
			r["stock"] = maxf(0.0, float(r["stock"]) - float(cost[k]) * float(n))
	units[type]["count"] = int(units[type]["count"]) + n
	units[type]["morale"] = clampf(float(units[type]["morale"]) + 0.02, 0.1, 1.0)
	Game.resources_changed.emit()
	military_changed.emit()
	_sync_to_game()
	return true

func disband(type: String, n: int) -> bool:
	if not units.has(type):
		return false
	var c: int = int(units[type]["count"])
	var rem: int = mini(n, c)
	units[type]["count"] = c - rem
	military_changed.emit()
	_sync_to_game()
	return rem > 0

func set_commander(type: String, level: String) -> void:
	ensure_unit(type)
	units[type]["commander"] = level
	military_changed.emit()
	_sync_to_game()

func calc_power(side: Dictionary, terrain: String = "plains") -> float:
	var tmult: float = float(TERRAIN_MODS.get(terrain, 1.0))
	var total: float = 0.0
	for id in side.keys():
		var entry: Variant = side[id]
		var count: int = 0
		var morale: float = 0.7
		var supply: float = 1.0
		var exp: float = 0.0
		var commander: String = "none"
		if typeof(entry) == TYPE_DICTIONARY:
			count = int(entry.get("count", 0))
			morale = float(entry.get("morale", 0.7))
			supply = float(entry.get("supply", 1.0))
			exp = float(entry.get("experience", 0.0))
			commander = str(entry.get("commander", "none"))
		elif typeof(entry) == TYPE_INT or typeof(entry) == TYPE_FLOAT:
			count = int(entry)
			var u: Dictionary = units.get(id, {})
			if not u.is_empty():
				morale = float(u.get("morale", 0.7))
				supply = float(u.get("supply", 1.0))
				exp = float(u.get("experience", 0.0))
				commander = str(u.get("commander", "none"))
		else:
			continue
		if count <= 0:
			continue
		var def: Dictionary = _catalog.get(id, {})
		var strength: float = float(def.get("strength", 5.0))
		var speed: float = float(def.get("speed", 1.0))
		var cmult: float = float(COMMANDER_BONUS.get(commander, 1.0))
		var exp_mult: float = 1.0 + exp * 0.5
		total += float(count) * strength * clampf(morale, 0.1, 1.5) * clampf(supply, 0.2, 1.0) * exp_mult * cmult * tmult * (0.9 + speed * 0.1)
	return total

func calc_power_simple(attacker_power: float, defender_power: float) -> Dictionary:
	return resolve_battle(attacker_power, defender_power, "plains")

func resolve_battle(attacker_power: float, defender_power: float, terrain: String = "plains") -> Dictionary:
	var ap: float = maxf(attacker_power, 0.1)
	var dp: float = maxf(defender_power, 0.1)
	var tmult: float = float(TERRAIN_MODS.get(terrain, 1.0))
	dp *= tmult
	var total: float = ap + dp
	var roll: float = _rng.randf() * total
	var attacker_wins: bool = roll < ap
	var ratio: float = ap / maxf(dp, 0.1) if attacker_wins else dp / maxf(ap, 0.1)
	var casualty_rate: float = clampf(0.15 + 0.1 * (1.0 / maxf(ratio, 0.5)), 0.05, 0.45)
	var winner_power: float = ap if attacker_wins else dp
	var loser_power: float = dp if attacker_wins else ap
	var result := {
		"winner": "attacker" if attacker_wins else "defender",
		"attacker_power": ap,
		"defender_power": dp,
		"terrain": terrain,
		"terrain_mult": tmult,
		"casualty_rate_winner": casualty_rate * 0.5,
		"casualty_rate_loser": casualty_rate,
		"ratio": ratio,
		"roll": roll,
		"winner_power": winner_power,
		"loser_power": loser_power,
	}
	battle_resolved.emit(result)
	return result

func auto_resolve(attackers: Dictionary, defenders: Dictionary, terrain: String = "plains") -> Dictionary:
	var ap: float = calc_power(attackers, terrain)
	var dp: float = calc_power(defenders, terrain)
	var res: Dictionary = resolve_battle(ap, dp, terrain)
	var win_side: String = str(res["winner"])
	var loss_side: String = "defender" if win_side == "attacker" else "attacker"
	var cr_win: float = float(res["casualty_rate_winner"])
	var cr_loss: float = float(res["casualty_rate_loser"])
	var winner_dict: Dictionary = attackers if win_side == "attacker" else defenders
	var loser_dict: Dictionary = defenders if win_side == "attacker" else attackers
	_apply_casualties(winner_dict, cr_win)
	_apply_casualties(loser_dict, cr_loss)
	_apply_morale(winner_dict, 0.06, 0.04)
	_apply_morale(loser_dict, -0.12, -0.08)
	_gain_experience(winner_dict, 0.08)
	_gain_experience(loser_dict, 0.03)
	res["attackers"] = attackers.duplicate(true)
	res["defenders"] = defenders.duplicate(true)
	military_changed.emit()
	_sync_to_game()
	return res

func _apply_casualties(side: Dictionary, rate: float) -> void:
	for id in side.keys():
		var entry: Variant = side[id]
		var count: int = 0
		if typeof(entry) == TYPE_DICTIONARY:
			count = int(entry.get("count", 0))
		elif typeof(entry) == TYPE_INT or typeof(entry) == TYPE_FLOAT:
			count = int(entry)
		if count <= 0:
			continue
		var losses: int = int(round(float(count) * rate * _rng.randf_range(0.8, 1.2)))
		losses = clampi(losses, 0, count)
		if typeof(entry) == TYPE_DICTIONARY:
			side[id]["count"] = count - losses
			if units.has(id):
				units[id]["count"] = maxi(0, int(units[id]["count"]) - losses)
		else:
			side[id] = count - losses
			if units.has(id):
				units[id]["count"] = maxi(0, int(units[id]["count"]) - losses)

func _apply_morale(side: Dictionary, morale_delta: float, supply_delta: float) -> void:
	for id in side.keys():
		var entry: Variant = side[id]
		var base: Dictionary = {}
		if typeof(entry) == TYPE_DICTIONARY:
			base = entry
		elif units.has(id):
			base = units[id]
		else:
			continue
		base["morale"] = clampf(float(base.get("morale", 0.7)) + morale_delta, 0.1, 1.0)
		base["supply"] = clampf(float(base.get("supply", 1.0)) + supply_delta, 0.2, 1.0)
		if units.has(id):
			units[id]["morale"] = base["morale"]
			units[id]["supply"] = base["supply"]

func _gain_experience(side: Dictionary, amt: float) -> void:
	for id in side.keys():
		if units.has(id):
			units[id]["experience"] = clampf(float(units[id]["experience"]) + amt * _rng.randf_range(0.7, 1.3), 0.0, 1.0)

func total_upkeep_gold() -> float:
	var s: float = 0.0
	for id in units.keys():
		var def: Dictionary = _catalog.get(id, {})
		var upkeep: Dictionary = def.get("upkeep", {})
		var g: float = float(upkeep.get("gold", 0.0))
		s += g * float(units[id].get("count", 0))
	return s

func total_upkeep_dict() -> Dictionary:
	var out: Dictionary = {}
	for id in units.keys():
		var def: Dictionary = _catalog.get(id, {})
		var upkeep: Dictionary = def.get("upkeep", {})
		var cnt: int = int(units[id].get("count", 0))
		if cnt <= 0:
			continue
		for k in upkeep:
			out[k] = float(out.get(k, 0.0)) + float(upkeep[k]) * float(cnt)
	return out

func apply_seasonal_upkeep(season: String) -> Dictionary:
	var mult: float = 1.0
	match season:
		"winter": mult = 1.35
		"summer": mult = 1.0
		"spring": mult = 1.0
		"autumn": mult = 1.05
	var upkeep: Dictionary = total_upkeep_dict()
	var consumed: Dictionary = {}
	var shortage: bool = false
	for k in upkeep:
		var need: float = float(upkeep[k]) * mult
		var r: Dictionary = Game.resources.get(k, {})
		var stock: float = 0.0
		if not r.is_empty():
			stock = float(r.get("stock", 0.0))
		else:
			stock = Game.get_stock(k)
		var pay: float = minf(stock, need)
		if not r.is_empty():
			r["stock"] = maxf(0.0, stock - pay)
		consumed[k] = pay
		if pay < need - 0.01:
			shortage = true
	if shortage:
		for id in units.keys():
			if int(units[id].get("count", 0)) > 0:
				units[id]["morale"] = maxf(0.1, float(units[id].get("morale", 0.7)) - 0.07)
				units[id]["supply"] = maxf(0.2, float(units[id].get("supply", 1.0)) - 0.12)
		var ev := {"id": Game.events.size(), "turn": Game.turn, "type": "upkeep_shortage", "severity": 1, "text": "Coin runs short — troops grumble, supplies thin."}
		Game.events.push_front(ev)
		Game.event_occurred.emit(ev)
	else:
		for id in units.keys():
			if int(units[id].get("count", 0)) > 0:
				units[id]["supply"] = clampf(float(units[id].get("supply", 1.0)) + 0.03, 0.2, 1.0)
	Game.resources_changed.emit()
	military_changed.emit()
	_sync_to_game()
	return consumed

func total_strength() -> float:
	return calc_power(units, "plains")

func serialize() -> Dictionary:
	return units.duplicate(true)

func restore(data: Dictionary) -> void:
	units.clear()
	for k in data.keys():
		var v: Variant = data[k]
		if typeof(v) == TYPE_DICTIONARY:
			units[k] = {
				"count": int(v.get("count", 0)),
				"morale": float(v.get("morale", 0.7)),
				"supply": float(v.get("supply", 1.0)),
				"experience": float(v.get("experience", 0.0)),
				"commander": str(v.get("commander", "none")),
			}
	_ensure_defaults()
	military_changed.emit()

func _sync_to_game() -> void:
	if Engine.has_singleton("Game"):
		pass
	var g: Node = get_node_or_null("/root/Game")
	if g != null and "military" in g:
		g.military = units.duplicate(true)
