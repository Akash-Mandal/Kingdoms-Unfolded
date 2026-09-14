extends SceneTree
## Headless smoke test for the Coordination Engine.
## Run in CI: godot --headless --path . --script res://scripts/tests/smoke_test.gd

func _init() -> void:
	var ce = load("res://scripts/core/game.gd").new()
	ce.reset()
	ce._rng.seed = 42
	var cfg: Dictionary = {
		# iron = neutral baseline (all difficulty mults 1.0) so custom stocks assert exact.
		"world_seed": 12345, "era": "medieval", "difficulty": "iron",
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

	var cat = load("res://scripts/core/catalog.gd").new()
	cat._load_all()
	print("CAT: units %d tech %d events %d buildings %d missions %d traits %d" % [cat.units.size(), cat.tech.size(), cat.events.size(), cat.buildings.size(), cat.missions.size(), cat.traits.size()])
	if cat.units.size() < 18:
		printerr("FAIL: units %d < 18" % cat.units.size())
		quit(1)
		return
	if cat.tech.size() < 60:
		printerr("FAIL: tech %d < 60" % cat.tech.size())
		quit(1)
		return
	if cat.events.size() < 100:
		printerr("FAIL: events %d < 100" % cat.events.size())
		quit(1)
		return
	if cat.buildings.size() < 40:
		printerr("FAIL: buildings %d < 40" % cat.buildings.size())
		quit(1)
		return
	if cat.missions.size() < 48:
		printerr("FAIL: missions %d < 48" % cat.missions.size())
		quit(1)
		return
	if cat.traits.size() < 24:
		printerr("FAIL: traits %d < 24" % cat.traits.size())
		quit(1)
		return
	var bal_path := "res://data/catalog/balance.json"
	if not FileAccess.file_exists(bal_path):
		printerr("WARN: balance.json missing")
	else:
		var bf := FileAccess.open(bal_path, FileAccess.READ)
		if bf == null:
			printerr("WARN: balance.json unreadable")
		else:
			var bparsed: Variant = JSON.parse_string(bf.get_as_text())
			bf.close()
			if typeof(bparsed) != TYPE_DICTIONARY or (bparsed as Dictionary).is_empty():
				printerr("WARN: balance.json malformed")

	print("OK: %d turns, month %d, food %.0f, %d events, save/load round-trip passed"
		% [ce.turn, ce.month, food, ce.events.size()])
	quit(0)