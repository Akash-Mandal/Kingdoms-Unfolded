extends Node
## TimeClock — drives the dual-clock: real-time sim hours + auto month-end.
## At ×1, SECONDS_PER_DAY real seconds = one sim day. 30 days = 1 month = 1 CE turn.

signal hour_changed(hour: float)
signal day_changed(day: int)
signal month_ended
signal speed_changed(speed: int)

const SECONDS_PER_DAY_AT_1X := 90.0
const DAYS_PER_MONTH := 30
const HOURS_PER_DAY := 24.0

const SPEEDS: Array[int] = [0, 1, 4, 12]

var sim_hour := 6.0    # dawn
var sim_day := 1
var speed := 1         # 0 paused, 1×, 4×, 12×

func _process(delta: float) -> void:
	if speed == 0:
		return
	var hours_per_sec := (HOURS_PER_DAY / SECONDS_PER_DAY_AT_1X) * float(speed)
	var prev := int(sim_hour)
	sim_hour += hours_per_sec * delta
	if int(sim_hour) != prev:
		hour_changed.emit(sim_hour)
	if sim_hour >= HOURS_PER_DAY:
		sim_hour -= HOURS_PER_DAY
		sim_day += 1
		day_changed.emit(sim_day)
		if sim_day > DAYS_PER_MONTH:
			sim_day = 1
			month_ended.emit()
			Game.call_deferred("advance")

func set_speed(s: int) -> void:
	speed = s
	speed_changed.emit(s)

func cycle_speed() -> void:
	var idx := SPEEDS.find(speed)
	set_speed(SPEEDS[(idx + 1) % SPEEDS.size()])

## "End Turn" — force month boundary now.
func end_turn_now() -> void:
	month_ended.emit()
	Game.advance()
	sim_day = 1
	sim_hour = 6.0

func time_of_day() -> String:
	var h := int(sim_hour) % 24
	return "%02d:00" % h

func is_night() -> bool:
	return sim_hour < 5.5 or sim_hour > 19.0