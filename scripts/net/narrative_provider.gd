extends Node
signal narrative_ready(event: Dictionary, result: Dictionary)
signal narrative_failed(event: Dictionary, error: String)
const TIMEOUT_SEC := 8.0
const MAX_RETRIES := 3
const CACHE_MAX := 64
const TOKEN_BUDGET := 80000
var provider: String = "local"
var temperature: float = 0.8
var model_overrides: Dictionary = {}
var _tokens_used := 0
var _queue: Array[Dictionary] = []
var _busy := false
var _cache: Dictionary = {}
var _cache_order: PackedStringArray = []
var _local_engine: RefCounted
var _adapters: Dictionary = {}
var _retry_map: Dictionary = {}
func _ready() -> void:
	_local_engine = load("res://scripts/net/local_engine.gd").new()
	_ensure_adapters()
	_load_settings()
	Game.event_occurred.connect(_on_event)
	Game.turned.connect(_on_turned)
func _ensure_adapters() -> void:
	if has_node("Gemini"):
		_adapters["gemini"] = get_node("Gemini")
	else:
		var g: Node = load("res://scripts/net/gemini_adapter.gd").new()
		g.name = "Gemini"
		add_child(g)
		_adapters["gemini"] = g
	if has_node("OpenAI"):
		_adapters["openai"] = get_node("OpenAI")
	else:
		var o: Node = load("res://scripts/net/openai_adapter.gd").new()
		o.name = "OpenAI"
		add_child(o)
		_adapters["openai"] = o
	if has_node("Ollama"):
		_adapters["ollama"] = get_node("Ollama")
	else:
		var l: Node = load("res://scripts/net/ollama_adapter.gd").new()
		l.name = "Ollama"
		add_child(l)
		_adapters["ollama"] = l
	for k in _adapters.keys():
		var ad: Node = _adapters[k] as Node
		if not ad.completed.is_connected(_on_adapter_completed):
			ad.completed.connect(_on_adapter_completed.bind(k))
		if not ad.failed.is_connected(_on_adapter_failed):
			ad.failed.connect(_on_adapter_failed.bind(k))
func _load_settings() -> void:
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault == null:
		return
	var p: String = ""
	if FileAccess.file_exists("user://settings/narrative.json"):
		var f := FileAccess.open("user://settings/narrative.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed as Dictionary
				provider = str(d.get("provider", "local")).to_lower()
				temperature = float(d.get("temperature", 0.8))
				model_overrides = d.get("models", {}) as Dictionary if d.has("models") else {}
				_tokens_used = int(d.get("tokens_used", 0))
				return
	if vault.has_method("load_config"):
		var cfg: Dictionary = vault.call("load_config", "narrative") as Dictionary
		if cfg.has("provider"):
			provider = str(cfg["provider"])
func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")
	var f := FileAccess.open("user://settings/narrative.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"provider": provider, "temperature": temperature, "models": model_overrides, "tokens_used": _tokens_used}))
	f.close()
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault != null and vault.has_method("store_config"):
		vault.call("store_config", "narrative", provider, temperature, "")
func set_provider(p: String) -> void:
	provider = p.to_lower()
	save_settings()
func set_temperature(t: float) -> void:
	temperature = clampf(t, 0.0, 1.6)
	save_settings()
func _build_prompt(event: Dictionary) -> Dictionary:
	var recent: Array = Game.events.slice(0, 5) if Game.events.size() > 0 else []
	var hooks: Array = []
	var chron: Node = get_node_or_null("/root/Chronicle")
	if chron != null and chron.has_method("recent_hooks"):
		hooks = chron.call("recent_hooks", 3) as Array
	var ctx: Dictionary = {
		"kingdom_name": str(Game.settings.get("kingdom_name", "Eterna")),
		"kingdom": str(Game.settings.get("kingdom_name", "Eterna")),
		"era": str(Game.settings.get("era", "medieval")),
		"turn": Game.turn,
		"year": Game.year,
		"month": Game.month,
		"season": Game.season(),
		"pop_count": int(Game.pop_count),
		"pop_happiness": Game.pop_happiness,
		"happiness": Game.pop_happiness,
		"gold": Game.get_stock("gold"),
		"food": Game.get_stock("food"),
		"military_power": Game.military_power(),
		"recent_events": recent,
		"traits": Game.settings.get("traits", []),
		"hooks": hooks,
		"difficulty": str(Game.settings.get("difficulty", "peaceful")),
	}
	var task: String = "Narrate event '%s' (%s, severity %s): %s. Provide 2-3 choices fitting lore and 1-2 hooks." % [
		str(event.get("name", event.get("type", "event"))),
		str(event.get("category", event.get("type", "random"))),
		str(event.get("severity", 1)),
		str(event.get("text", "")),
	]
	return {"system_context": ctx, "task": task, "event": event, "full": task}
func _cache_key(prompt: Dictionary) -> String:
	return str(JSON.stringify(prompt).hash())
func _similarity(a: String, b: String) -> float:
	if a == b:
		return 1.0
	var wa: PackedStringArray = a.to_lower().split(" ")
	var wb: PackedStringArray = b.to_lower().split(" ")
	var sa: Dictionary = {}
	for w in wa:
		sa[w] = true
	var inter := 0
	for w in wb:
		if sa.has(w):
			inter += 1
	var uni: int = wa.size() + wb.size() - inter
	if uni == 0:
		return 0.0
	return float(inter) / float(uni)
func _check_cache(prompt: Dictionary) -> Dictionary:
	var ck := _cache_key(prompt)
	if _cache.has(ck):
		var v: Dictionary = _cache[ck] as Dictionary
		v["cached"] = true
		return v
	var cur: String = str(prompt.get("task", JSON.stringify(prompt)))
	for k in _cache.keys():
		var e: Dictionary = _cache[k] as Dictionary
		var prev: String = str(e.get("_prompt_full", ""))
		if prev != "" and _similarity(cur, prev) >= 0.85:
			var cp: Dictionary = e.duplicate(true)
			cp["cached"] = true
			return cp
	return {}
func _cache_store(prompt: Dictionary, result: Dictionary) -> void:
	var ck := _cache_key(prompt)
	if _cache.has(ck):
		var idx: int = _cache_order.find(ck)
		if idx != -1:
			_cache_order.remove_at(idx)
	_cache[ck] = result.duplicate(true)
	_cache[ck]["_prompt_full"] = str(prompt.get("task", ""))
	_cache_order.append(ck)
	while _cache_order.size() > CACHE_MAX:
		var old: String = _cache_order[0]
		_cache_order.remove_at(0)
		_cache.erase(old)
	_tokens_used += int(str(result.get("text", "")).length() / 4) + 80
	if _tokens_used > TOKEN_BUDGET:
		_cache.clear()
		_cache_order.clear()
	save_settings()
func _validate(result: Dictionary) -> bool:
	if not result.has("text") or typeof(result["text"]) != TYPE_STRING or (result["text"] as String).strip_edges() == "":
		return false
	if not result.has("choices") or typeof(result["choices"]) != TYPE_ARRAY:
		return false
	return true
func generate(prompt: Dictionary) -> Dictionary:
	var p2: Dictionary = prompt
	if prompt.has("type") and not prompt.has("event"):
		p2 = _build_prompt(prompt)
	elif prompt.has("system_context") or prompt.has("task"):
		p2 = prompt
	else:
		p2 = _build_prompt(prompt)
	if _tokens_used >= TOKEN_BUDGET:
		var fb: Dictionary = _local_engine.call("generate", p2) as Dictionary
		fb["provider"] = "local-budget"
		return fb
	var cached: Dictionary = _check_cache(p2)
	if not cached.is_empty():
		return cached
	if provider == "local":
		var res: Dictionary = _local_engine.call("generate", p2) as Dictionary
		res["provider"] = "local"
		_cache_store(p2, res)
		return res
	var adapter: Node = _adapters.get(provider, null) as Node
	if adapter != null and adapter.has_method("generate"):
		var key_ok := true
		if provider in ["gemini", "openai"]:
			var vault: Node = get_node_or_null("/root/KeyVault")
			if vault != null and vault.has_method("has_key"):
				key_ok = bool(vault.call("has_key", provider))
				if not key_ok:
					var fb2: Dictionary = _local_engine.call("generate", p2) as Dictionary
					fb2["provider"] = "local-no-key"
					fb2["error"] = "missing_key"
					return fb2
		var res2: Variant = await adapter.call("generate", p2)
		if typeof(res2) == TYPE_DICTIONARY:
			var d: Dictionary = res2 as Dictionary
			if _validate(d):
				_cache_store(p2, d)
				return d
		var fb3: Dictionary = _local_engine.call("generate", p2) as Dictionary
		fb3["provider"] = "local-fallback"
		_cache_store(p2, fb3)
		return fb3
	var fb4: Dictionary = _local_engine.call("generate", p2) as Dictionary
	_cache_store(p2, fb4)
	return fb4
func generate_async(event: Dictionary) -> void:
	var prompt: Dictionary = _build_prompt(event)
	var cached: Dictionary = _check_cache(prompt)
	if not cached.is_empty():
		narrative_ready.emit(event, cached)
		_push_chronicle(event, cached)
		return
	_queue.append({"event": event, "prompt": prompt, "retries": 0})
	if not _busy:
		_dequeue()
func _dequeue() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()
	var event: Dictionary = item["event"] as Dictionary
	var prompt: Dictionary = item["prompt"] as Dictionary
	if provider == "local":
		var res: Dictionary = _local_engine.call("generate", prompt) as Dictionary
		res["provider"] = "local"
		_cache_store(prompt, res)
		narrative_ready.emit(event, res)
		_push_chronicle(event, res)
		_dequeue()
		return
	var adapter: Node = _adapters.get(provider, null) as Node
	if adapter == null:
		var fb: Dictionary = _local_engine.call("generate", prompt) as Dictionary
		_cache_store(prompt, fb)
		narrative_ready.emit(event, fb)
		_push_chronicle(event, fb)
		_dequeue()
		return
	if provider in ["gemini", "openai"]:
		var vault: Node = get_node_or_null("/root/KeyVault")
		if vault != null and vault.has_method("has_key") and not bool(vault.call("has_key", provider)):
			var fb2: Dictionary = _local_engine.call("generate", prompt) as Dictionary
			fb2["provider"] = "local-no-key"
			_cache_store(prompt, fb2)
			narrative_ready.emit(event, fb2)
			_push_chronicle(event, fb2)
			_dequeue()
			return
	var t := get_tree().create_timer(TIMEOUT_SEC)
	t.timeout.connect(func() -> void: _on_timeout(item))
	adapter.call("generate_async", prompt)
func _on_timeout(item: Dictionary) -> void:
	if not _busy:
		return
	var event: Dictionary = item["event"] as Dictionary
	var prompt: Dictionary = item["prompt"] as Dictionary
	var retries: int = int(item.get("retries", 0))
	if retries < MAX_RETRIES:
		item["retries"] = retries + 1
		var backoff: float = pow(2.0, float(retries)) * 0.5
		await get_tree().create_timer(backoff).timeout
		var fb: Dictionary = _local_engine.call("generate", prompt) as Dictionary
		if retries >= 1:
			_cache_store(prompt, fb)
			narrative_ready.emit(event, fb)
			_push_chronicle(event, fb)
			_busy = false
			_dequeue()
		else:
			_queue.push_front(item)
			_busy = false
			_dequeue()
	else:
		var fb2: Dictionary = _local_engine.call("generate", prompt) as Dictionary
		fb2["provider"] = "local-timeout"
		_cache_store(prompt, fb2)
		narrative_ready.emit(event, fb2)
		_push_chronicle(event, fb2)
		_busy = false
		_dequeue()
func _on_adapter_completed(result: Dictionary, provider_key: String) -> void:
	if not _busy:
		return
	var item_event: Dictionary = {}
	if not _queue.is_empty():
		item_event = _queue[0].get("event", {}) as Dictionary
	_busy = false
	if _queue.is_empty():
		return
func _on_adapter_failed(_error: String, _provider_key: String) -> void:
	pass
func _push_chronicle(event: Dictionary, result: Dictionary) -> void:
	var chron: Node = get_node_or_null("/root/Chronicle")
	if chron != null and chron.has_method("append"):
		chron.call("append", event, result)
func _on_event(event: Dictionary) -> void:
	generate_async(event)
func _on_turned() -> void:
	var chron: Node = get_node_or_null("/root/Chronicle")
	if chron != null and chron.has_method("on_turn"):
		chron.call("on_turn")
