extends Node
## Game autoload — Coordination Engine (CE) core, Phase 0.
## Runs the monthly macro turn. The micro world (resources visible in 3D)
## is Phase 2+; this module is the offline referee of every game rule.

signal turned
signal event_occurred(event: Dictionary)
signal resources_changed

const TURNS_PER_YEAR := 12
const SAVE_VERSION := 1

const RESOURCE_KEYS: PackedStringArray = [
	"food", "gold", "wood", "stone", "iron", "cloth", "horses", "knowledge"
]

var turn := 0
var month := 1
var year := 0

var resources := {}
var events: Array[Dictionary] = []          # most recent first
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
	resources.clear()
	for key in RESOURCE_KEYS:
		resources[key] = {
			"stock": 100.0,
			"prod": _base_production(key),
			"cons": _base_consumption(key),
		}

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
	return 0.0

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
	_roll_events()
	turned.emit()
	resources_changed.emit()

func _apply_flows() -> void:
	for key in RESOURCE_KEYS:
		var r: Dictionary = resources[key]
		r["stock"] = maxf(0.0, r["stock"] + r["prod"] - r["cons"])

func _roll_events() -> void:
	var roll := _rng.randf()
	if roll > 0.7:
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
			"population": {},   # Phase 2
			"military": {},     # Phase 3
			"diplomacy": {},    # Phase 3
			"tech": {},         # Phase 3
		},
		"eventHistory": events,
		"missionLog": [],       # Phase 4
		"storyProgress": {},    # Phase 4
		"chronicle": [],        # Phase 4
		"settings": settings,
		"ceState": {
			"nextEventId": events.size(),
			"rngState": _rng.state,
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
	events.assign(data.get("eventHistory", []))
	settings = data.get("settings", settings)
	turn = int(data.get("meta", {}).get("turnCount", 0))
	year = turn / TURNS_PER_YEAR
	month = (turn % TURNS_PER_YEAR) + 1
	var ce: Dictionary = data.get("ceState", {})
	_rng.state = int(ce.get("rngState", 0))