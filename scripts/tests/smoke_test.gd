extends SceneTree
## Headless smoke test for the Coordination Engine.
## Run in CI: godot --headless --path . --script res://scripts/tests/smoke_test.gd

func _init() -> void:
	var ce = load("res://scripts/core/game.gd").new()
	ce.reset()
	ce._rng.seed = 42

	var took := 20
	for i in took:
		ce.advance()

	if ce.turn != took:
		printerr("FAIL: turn count = %d" % ce.turn)
		quit(1)
		return

	if ce.month != (took % 12) + 1:
		printerr("FAIL: month = %d" % ce.month)
		quit(1)
		return

	var food: float = ce.get_stock("food")
	if food < 100.0:
		printerr("FAIL: food stock = %f (should grow under harvest)" % food)
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

	if ce2.turn != took:
		printerr("FAIL: restored turn = %d" % ce2.turn)
		quit(1)
		return

	print("OK: %d turns, month %d, food %.0f, %d events, save/load round-trip passed"
		% [ce.turn, ce.month, food, ce.events.size()])
	quit(0)