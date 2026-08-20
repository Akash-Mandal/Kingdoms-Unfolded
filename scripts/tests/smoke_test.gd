extends SceneTree
## Headless smoke test for the Coordination Engine.
## Run in CI: godot --headless --path . --script res://scripts/tests/smoke_test.gd

func _init() -> void:
	var ce = load("res://scripts/core/game.gd").new()
	ce.reset()
	ce._rng.seed = 42
	var cfg: Dictionary = {
		"world_seed": 12345, "era": "medieval", "difficulty": "peaceful",
		"kingdom_name": "Testia", "banner_color": "#ff0000", "sigil": "lion",
		"gov": "feudal", "religion": "old_gods", "culture": "highland",
		"ruler_name": "Test", "ruler_age": 30, "ruler_gender": "male",
		"traits": ["Brave"], "legacy_path": "builder", "territory_size": "medium",
		"rivals": 3, "scenario": "default", "starting_season": "spring",
		"resources": {"food": 120, "gold": 80, "wood": 90, "stone": 90, "iron": 50, "cloth": 50, "horses": 20, "knowledge": 20},
	}
	ce.apply_start_config(cfg)
	if ce.month != 3:
		printerr("FAIL: start season spring should be month 3 got %d" % ce.month)
		quit(1)
		return
	if ce.get_stock("food") != 120:
		printerr("FAIL: custom food stock")
		quit(1)
		return
	ce._rng.seed = 42

	var start_turn: int = ce.turn
	var start_month: int = ce.month
	var took := 20
	for i in took:
		ce.advance()

	var exp_turn: int = start_turn + took
	if ce.turn != exp_turn:
		printerr("FAIL: turn count = %d exp %d" % [ce.turn, exp_turn])
		quit(1)
		return

	var exp_month: int = ((start_month - 1 + took) % 12) + 1
	if ce.month != exp_month:
		printerr("FAIL: month = %d exp %d" % [ce.month, exp_month])
		quit(1)
		return

	var food: float = ce.get_stock("food")
	if food < 10.0:
		printerr("FAIL: food stock = %f (should not collapse)" % food)
		quit(1)
		return

	var data: Dictionary = ce.serialize()
	for key in ["meta", "gameState", "eventHistory", "settings", "ceState"]:
		if not data.has(key):
			printerr("FAIL: missing serialized key '%s'" % key)
			quit(1)
			return

	var save_path := "user://saves/slot_test.json"
	if not ce.save_to_file(save_path):
		printerr("FAIL: save failed")
		quit(1)
		return

	var ce2 = load("res://scripts/core/game.gd").new()
	if not ce2.load_from_file(save_path):
		printerr("FAIL: load failed")
		quit(1)
		return

	if ce2.turn != exp_turn:
		printerr("FAIL: restored turn = %d exp %d" % [ce2.turn, exp_turn])
		quit(1)
		return

	var cat := load("res://scripts/core/catalog.gd").new()
	cat._load_all()
	if cat.units.is_empty():
		printerr("FAIL: units catalog empty")
		quit(1)
		return
	if cat.units.size() < 18:
		printerr("FAIL: units %d < 18" % cat.units.size())
		quit(1)
		return
	if cat.tech.is_empty() or cat.tech.size() < 36:
		printerr("FAIL: tech %d < 36" % cat.tech.size())
		quit(1)
		return
	if cat.events.is_empty() or cat.events.size() < 20:
		printerr("FAIL: events %d < 20" % cat.events.size())
		quit(1)
		return
	var bal_path := "res://data/catalog/balance.json"
	if not FileAccess.file_exists(bal_path):
		printerr("FAIL: balance.json missing")
		quit(1)
		return
	var bf := FileAccess.open(bal_path, FileAccess.READ)
	if bf == null:
		printerr("FAIL: balance.json unreadable")
		quit(1)
		return
	var bparsed: Variant = JSON.parse_string(bf.get_as_text())
	bf.close()
	if typeof(bparsed) != TYPE_DICTIONARY or (bparsed as Dictionary).is_empty():
		printerr("FAIL: balance.json malformed")
		quit(1)
		return

	print("OK: %d turns, month %d, food %.0f, %d events, save/load round-trip passed — catalogs: units %d tech %d events %d balance ok"
		% [ce.turn, ce.month, food, ce.events.size(), cat.units.size(), cat.tech.size(), cat.events.size()])
	quit(0)