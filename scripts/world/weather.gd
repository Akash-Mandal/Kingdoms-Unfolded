extends Node
## Weather — lightweight state machine. Changes each in-game day, weighted by season.
## Visual effects are simple colour/particle toggles; no heavy physics.

signal weather_changed(state: String)

var state := "clear"

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = Game.settings.world_seed + 9001
	if TimeClock.has_signal("day_changed"):
		TimeClock.day_changed.connect(_on_day)
	_roll()

func _on_day(_d: int) -> void:
	_roll()

func _roll() -> void:
	var s: String = Game.season()
	var roll := _rng.randf()
	var next := "clear"
	match s:
		"winter":
			if roll < 0.22:
				next = "snow"
			elif roll < 0.35:
				next = "fog"
			elif roll < 0.50:
				next = "cloudy"
		"spring":
			if roll < 0.20:
				next = "rain"
			elif roll < 0.35:
				next = "fog"
		"summer":
			if roll < 0.12:
				next = "rain"
			elif roll < 0.22:
				next = "cloudy"
		"autumn":
			if roll < 0.18:
				next = "rain"
			elif roll < 0.30:
				next = "fog"
	if next != state:
		state = next
		weather_changed.emit(state)

func is_rainy() -> bool:
	return state == "rain"

func is_snowy() -> bool:
	return state == "snow"

func is_foggy() -> bool:
	return state == "fog"
