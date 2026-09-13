extends Node
const AUDIO_DIR := "res://assets/audio/"
var _base: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _mourning: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _danger := 0.0
var _mourn_target := -80.0
var _weather: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base = _make_loop(AUDIO_DIR + "base.ogg", -6.0)
	_tension = _make_loop(AUDIO_DIR + "tension.ogg", -80.0)
	_mourning = _make_loop(AUDIO_DIR + "mourning.ogg", -80.0)
	_rain = _make_loop(AUDIO_DIR + "ambience/rain_loop.ogg", -80.0)
	_stinger = AudioStreamPlayer.new()
	_stinger.bus = "Master"
	if ResourceLoader.exists(AUDIO_DIR + "triumph.ogg"):
		_stinger.stream = load(AUDIO_DIR + "triumph.ogg") as AudioStream
	add_child(_stinger)
	apply_volumes()
	call_deferred("_late_connect")
	if _base.stream != null:
		_base.play()
	if _rain.stream != null:
		_rain.play()

func _make_loop(path: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	if ResourceLoader.exists(path):
		p.stream = load(path) as AudioStream
	p.volume_db = vol
	add_child(p)
	return p

func apply_volumes() -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	var mdb := -6.0
	var mute := false
	if s != null:
		mdb = float(s.get("music_db")) if "music_db" in s else -6.0
		mute = bool(s.get("muted")) if "muted" in s else false
	var base_vol := -80.0 if mute else mdb
	if _base != null and _base.volume_db < -70.0:
		_base.volume_db = base_vol
	elif _base != null and not mute:
		_base.volume_db = mdb
	if mute:
		if _tension != null:
			_tension.volume_db = -80.0
		if _mourning != null:
			_mourning.volume_db = -80.0
		if _rain != null and _rain.volume_db > -70.0:
			_rain.volume_db = -80.0

func _late_connect() -> void:
	var g: Node = get_node_or_null("/root/Game")
	if g != null:
		if g.has_signal("event_occurred"):
			g.connect("event_occurred", _on_event)
		if g.has_signal("turned"):
			g.connect("turned", _on_turned)
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_signal("battle_resolved"):
		mil.connect("battle_resolved", _on_battle)
	var sc: Node = get_node_or_null("/root/Succession")
	if sc != null:
		if sc.has_signal("ruler_died"):
			sc.connect("ruler_died", _on_ruler_died)
		if sc.has_signal("heir_ascended"):
			sc.connect("heir_ascended", _on_heir_ascended)
	var dp: Node = get_node_or_null("/root/Diplomacy")
	if dp != null and dp.has_signal("treaty_changed"):
		dp.connect("treaty_changed", _on_treaty)

func _process(delta: float) -> void:
	if _weather == null:
		_weather = get_node_or_null("/root/Main/Weather")
		if _weather != null and _weather.has_signal("weather_changed"):
			_weather.connect("weather_changed", _on_weather)
	_update_mood(delta)
	_update_fades(delta)

func _update_mood(_delta: float) -> void:
	var target := 0.0
	var g: Node = get_node_or_null("/root/Game")
	if g != null:
		var hap := 0.6
		if "pop_happiness" in g:
			hap = float(g.get("pop_happiness"))
		target += (0.6 - hap) * 0.8
		if "events" in g and g.get("events") is Array:
			var evs: Array = g.get("events")
			var n: int = mini(5, evs.size())
			for i in n:
				var e: Variant = evs[i]
				if e is Dictionary:
					var cat := str((e as Dictionary).get("category", ""))
					var sev := int((e as Dictionary).get("severity", 1))
					if cat in ["revolt", "disaster", "plague"]:
						target += 0.15 * float(sev)
					elif cat == "war":
						target += 0.2 * float(sev)
	var sc: Node = get_node_or_null("/root/Succession")
	if sc != null and "is_regency" in sc and bool(sc.get("is_regency")):
		_mourn_target = -10.0
	else:
		_mourn_target = -80.0
	_danger = lerpf(_danger, clampf(target, 0.0, 1.0), 0.02)

func _update_fades(delta: float) -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	var mute := false
	var mdb := -6.0
	if s != null:
		mute = bool(s.get("muted")) if "muted" in s else false
		mdb = float(s.get("music_db")) if "music_db" in s else -6.0
	var t_target := -80.0
	if not mute and _danger > 0.35:
		t_target = lerpf(-28.0, mdb, clampf((_danger - 0.35) / 0.45, 0.0, 1.0))
	_tension.volume_db = move_toward(_tension.volume_db, t_target, delta * 12.0)
	var m_target := _mourn_target if not mute else -80.0
	_mourning.volume_db = move_toward(_mourning.volume_db, m_target, delta * 10.0)
	if _tension.stream != null and not _tension.playing and t_target > -70.0:
		_tension.play()
	if _mourning.stream != null and not _mourning.playing and m_target > -70.0:
		_mourning.play()

func _on_event(event: Dictionary) -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	if s == null or not s.has_method("play"):
		return
	var cat := str(event.get("category", ""))
	match cat:
		"disaster", "plague":
			s.call("play", "door", 0.7)
		"revolt":
			s.call("play", "sword_draw", 0.9)
		"war", "military":
			s.call("play", "sword_swing", 0.9)
		"economic":
			s.call("play", "coin", 1.0)
		"political", "diplomacy":
			s.call("play", "book", 1.0)
		_:
			s.call("play", "book", 1.1)
	_danger = clampf(_danger + 0.15, 0.0, 1.0)

func _on_turned() -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	if s != null and s.has_method("play"):
		s.call("play", "fanfare_open", 1.1, -6.0)
	_danger = clampf(_danger - 0.1, 0.0, 1.0)

func _on_battle(result: Dictionary) -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	var won := str(result.get("winner", "attacker")) == "attacker"
	if s != null and s.has_method("play"):
		s.call("play", "battle_clang", 1.0)
		s.call("play", "sword_swing", 1.2)
	if won:
		_stinger.volume_db = 0.0
		if _stinger.stream != null:
			_stinger.play()
		_danger = clampf(_danger - 0.2, 0.0, 1.0)
	else:
		_danger = clampf(_danger + 0.3, 0.0, 1.0)

func _on_ruler_died(_old: Dictionary, _cause: String) -> void:
	_mourn_target = -10.0
	if _mourning.stream != null and not _mourning.playing:
		_mourning.play()

func _on_heir_ascended(_new_ruler: Dictionary) -> void:
	_mourn_target = -80.0
	_stinger.volume_db = -4.0
	if _stinger.stream != null:
		_stinger.play()

func _on_treaty(_kingdom_id: String, _treaty_id: String) -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	if s != null and s.has_method("play"):
		s.call("play", "book", 0.9)

func _on_weather(state: String) -> void:
	var s: Node = get_node_or_null("/root/Sfx")
	var mute := false
	var mdb := -6.0
	if s != null:
		mute = bool(s.get("muted")) if "muted" in s else false
		mdb = float(s.get("music_db")) if "music_db" in s else -6.0
	if state == "rain" and not mute:
		_rain.volume_db = mdb - 8.0
		if _rain.stream != null and not _rain.playing:
			_rain.play()
	else:
		_rain.volume_db = -80.0
