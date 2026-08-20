extends Node
signal completed(result: Dictionary)
signal failed(error: String)
const TIMEOUT_SEC := 8.0
const MAX_RETRIES := 3
const TOKEN_BUDGET := 70000
const CACHE_MAX := 64
var model: String = "gpt-4o-mini"
var temperature: float = 0.8
var base_url: String = "https://api.openai.com/v1"
var _tokens_used := 0
var _cache: Dictionary = {}
var _cache_order: PackedStringArray = []
var _queue: Array[Dictionary] = []
var _busy := false
var _http: HTTPRequest
var _retry_count := 0
var _current: Dictionary = {}
func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_http_done)
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault != null and vault.has_method("load_config"):
		var cfg: Dictionary = vault.call("load_config", "openai") as Dictionary
		if cfg.has("model"):
			model = str(cfg["model"])
		if cfg.has("temperature"):
			temperature = float(cfg["temperature"])
		if cfg.has("base_url") and str(cfg["base_url"]) != "":
			base_url = str(cfg["base_url"])
func _device_key() -> String:
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault != null and vault.has_method("load_key"):
		return str(vault.call("load_key", "openai"))
	return ""
func _endpoint() -> String:
	return "%s/chat/completions" % base_url.rstrip("/")
func _build_body(prompt: Dictionary) -> String:
	var ctx: Dictionary = prompt.get("system_context", {}) as Dictionary if prompt.has("system_context") else {}
	var event: Dictionary = prompt.get("event", {}) as Dictionary if prompt.has("event") else prompt
	var system_text := "You are the chronicler of %s (%s era). Turn %s. Pop %s happiness %s. Respond with ONLY valid JSON matching schema {text, choices[{id,label,hint,effects}], hooks[]}." % [
		str(ctx.get("kingdom_name", "Eterna")), str(ctx.get("era", "medieval")), str(ctx.get("turn", 0)), str(ctx.get("pop_count", 50)), str(ctx.get("happiness", 0.6))
	]
	var user_text: String = str(prompt.get("task", event.get("text", "Narrate this event.")))
	var schema := '{"type":"object","required":["text","choices","hooks"],"properties":{"text":{"type":"string"},"choices":{"type":"array","minItems":2,"maxItems":3,"items":{"type":"object","required":["id","label"],"properties":{"id":{"type":"string"},"label":{"type":"string"},"hint":{"type":"string"},"effects":{"type":"object"}}}},"hooks":{"type":"array","items":{"type":"string"}}}}'
	return JSON.stringify({
		"model": model,
		"temperature": temperature,
		"max_tokens": 900,
		"response_format": {"type": "json_object"},
		"messages": [
			{"role": "system", "content": system_text + " JSON schema: " + schema},
			{"role": "user", "content": user_text},
		],
	})
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
	var cur_full: String = str(prompt.get("task", JSON.stringify(prompt)))
	for k in _cache.keys():
		var e: Dictionary = _cache[k] as Dictionary
		var prev: String = str(e.get("_prompt_full", ""))
		if prev != "" and _similarity(cur_full, prev) >= 0.85:
			var cp: Dictionary = e.duplicate(true)
			cp["cached"] = true
			return cp
	return {}
func _cache_store(prompt: Dictionary, result: Dictionary) -> void:
	var ck := _cache_key(prompt)
	if _cache.has(ck):
		_cache_order.erase(ck)
	_cache[ck] = result.duplicate(true)
	_cache[ck]["_prompt_full"] = str(prompt.get("task", ""))
	_cache_order.append(ck)
	while _cache_order.size() > CACHE_MAX:
		var old: String = _cache_order[0]
		_cache_order.remove_at(0)
		_cache.erase(old)
func _validate(result: Dictionary) -> bool:
	if not result.has("text") or typeof(result["text"]) != TYPE_STRING or (result["text"] as String).length() < 8:
		return false
	if not result.has("choices") or typeof(result["choices"]) != TYPE_ARRAY:
		return false
	return true
func _local_fallback(prompt: Dictionary) -> Dictionary:
	var eng: RefCounted = load("res://scripts/net/local_engine.gd").new()
	return eng.call("generate", prompt) as Dictionary
func generate(prompt: Dictionary) -> Dictionary:
	if _tokens_used >= TOKEN_BUDGET:
		var fb: Dictionary = _local_fallback(prompt)
		fb["provider"] = "local-budget"
		return fb
	var cached: Dictionary = _check_cache(prompt)
	if not cached.is_empty():
		return cached
	if _device_key() == "":
		return _local_fallback(prompt)
	_queue.append(prompt)
	if not _busy:
		_process_next()
		await completed
		return _current.get("_last_result", _local_fallback(prompt)) as Dictionary
	var fb2: Dictionary = _local_fallback(prompt)
	fb2["queued"] = true
	return fb2
func generate_async(prompt: Dictionary) -> void:
	_queue.append(prompt)
	if not _busy:
		_process_next()
func _process_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	_retry_count = 0
	_current = _queue.pop_front()
	_send(_current)
func _send(prompt: Dictionary) -> void:
	var body := _build_body(prompt)
	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer %s" % _device_key()]
	var err: int = _http.request(_endpoint(), headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_on_failure("request_error %d" % err, prompt)
func _on_http_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var prompt: Dictionary = _current
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_handle_retry("http %d code %d" % [result, code], prompt)
		return
	var txt: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		_handle_retry("parse_fail", prompt)
		return
	var dict: Dictionary = parsed as Dictionary
	var content_text := ""
	var choices: Variant = dict.get("choices", [])
	if typeof(choices) == TYPE_ARRAY and not (choices as Array).is_empty():
		var first: Variant = (choices as Array)[0]
		if typeof(first) == TYPE_DICTIONARY:
			var msg: Variant = (first as Dictionary).get("message", {})
			if typeof(msg) == TYPE_DICTIONARY:
				content_text = str((msg as Dictionary).get("content", ""))
	if content_text == "":
		content_text = txt
	var inner: Variant = JSON.parse_string(content_text)
	var out: Dictionary = {}
	if typeof(inner) == TYPE_DICTIONARY:
		out = inner as Dictionary
	else:
		out = {"text": content_text, "choices": prompt.get("event", {}).get("choices", []), "hooks": []}
	if not _validate(out):
		_handle_retry("schema_fail", prompt)
		return
	out["provider"] = "openai"
	out["model"] = model
	out["cached"] = false
	_tokens_used += int(str(out.get("text", "")).length() / 4) + 120
	_cache_store(prompt, out)
	_current["_last_result"] = out
	completed.emit(out)
	_process_next()
func _handle_retry(err: String, prompt: Dictionary) -> void:
	if _retry_count < MAX_RETRIES:
		_retry_count += 1
		var backoff: float = pow(2.0, _retry_count) * 0.5
		await get_tree().create_timer(backoff).timeout
		_send(prompt)
		return
	_on_failure(err, prompt)
func _on_failure(err: String, prompt: Dictionary) -> void:
	var fb: Dictionary = _local_fallback(prompt)
	fb["provider"] = "local-fallback"
	fb["error"] = err
	_current["_last_result"] = fb
	failed.emit(err)
	completed.emit(fb)
	_process_next()
