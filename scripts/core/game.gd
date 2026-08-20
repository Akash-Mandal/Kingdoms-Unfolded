extends Node
## Game autoload — Coordination Engine (CE) core.
## The monthly macro turn. The offline referee of every game rule.
## Phase 1: added economy chain (grain→flour→food), building contributions,
## population capacity, and season helper.

signal turned
signal event_occurred(event: Dictionary)
signal resources_changed
signal population_changed

const TURNS_PER_YEAR := 12
const SAVE_VERSION := 2

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

var events: Array[Dictionary] = []
var placed_buildings: Array[Dictionary] = []   # {id, x, z} — serialised

var settings := {
	"world_seed": 0,
	"era": "medieval",
	"difficulty": "peaceful",
	"kingdom_name": "Eterna",
	"ruler_name": "Aurelia",
}

var _rng := RandomNumberGenerator.new()

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

func _base_production(key: String) -> float:
	match key:
		"food": return 42.0
		"gold": return 12.0
		"wood": return 18.0
		"stone": return 8.0
		"iron": return 4.0
		"cloth": return 6.0
		"horses": return 2.0
		"knowledge": return 3.0
	return 0.0   # grain/flour have no base production

func _base_consumption(key: String) -> float:
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
	_apply_population()
	_roll_events()
	turned.emit()
	resources_changed.emit()
	population_changed.emit()

func _apply_flows() -> void:
	for key in ALL_KEYS:
		var r: Dictionary = resources[key]
		var prod: float = r["prod"] + building_prod.get(key, 0.0)
		var cons: float = r["cons"] + building_cons.get(key, 0.0)
		r["stock"] = maxf(0.0, r["stock"] + prod - cons)

func _apply_population() -> void:
	var food_stock := get_stock("food")
	var food_cons: float = resources["food"]["cons"] + building_cons.get("food", 0.0)
	var ratio: float = food_cons / 100.0
	var surplus: float = food_stock - food_cons
	pop_happiness = clampf(0.4 + 0.4 * (surplus / 50.0 + 0.5), 0.0, 1.0)
	var cap := pop_capacity_base + building_cap.get("housing", 0.0)
	if surplus < 0.0:
		pop_count = maxf(0.0, pop_count + surplus * 0.2)   # famine deaths
	elif pop_count < cap:
		pop_count += pop_count * 0.02 * pop_happiness * (1.0 - pop_count / maxf(cap, 1.0))
	pop_count = minf(pop_count, cap) if surplus >= 0.0 else pop_count

func _roll_events() -> void:
	if _rng.randf() > 0.7:
		var ev := {
			"id": events.size(),
			"turn": turn,
			"type": "harvest",
			"severity": 1,
			"text": "A mild harvest season fills the granaries.",
		}
		events.push_front(ev)
		resources["food"]["stock"] += 25.0
		event_occurred.emit(ev)

## Building contributions (called by BuildingManager after placement / recompute).
func set_building_contributions(prod: Dictionary, cons: Dictionary, cap: Dictionary) -> void:
	building_prod = prod
	building_cons = cons
	building_cap = cap

func record_building(id: String, x: float, z: float) -> void:
	placed_buildings.append({"id": id, "x": x, "z": z})

func season() -> String:
	# Northern-hemisphere: spring 3-5, summer 6-8, autumn 9-11, winter 12/1/2
	match month:
		3, 4, 5: return "spring"
		6, 7, 8: return "summer"
		9, 10, 11: return "autumn"
		_: return "winter"

func get_stock(key: String) -> float:
	return resources.get(key, {}).get("stock", 0.0)

## --- Save system ---------------------------------------------------------

func serialize() -> Dictionary:
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
			"military": {},
			"diplomacy": {},
			"tech": {},
		},
		"eventHistory": events,
		"missionLog": [],
		"storyProgress": {},
		"chronicle": [],
		"settings": settings,
		"ceState": {
			"nextEventId": events.size(),
			"rngState": _rng.state,
			"buildingProd": building_prod,
			"buildingCons": building_cons,
			"buildingCap": building_cap,
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
	var state: Dictionary = data.get("gameState", {})
	resources = state.get("resources", resources)
	placed_buildings = state.get("buildings", placed_buildings)
	events.assign(data.get("eventHistory", []))
	settings = data.get("settings", settings)
	turn = int(data.get("meta", {}).get("turnCount", 0))
	year = turn / TURNS_PER_YEAR
	month = (turn % TURNS_PER_YEAR) + 1
	var pop: Dictionary = state.get("population", {})
	pop_count = float(pop.get("count", pop_count))
	pop_happiness = float(pop.get("happiness", pop_happiness))
	var ce: Dictionary = data.get("ceState", {})
	building_prod = ce.get("buildingProd", {})
	building_cons = ce.get("buildingCons", {})
	building_cap = ce.get("buildingCap", {})
	_rng.state = int(ce.get("rngState", 0))