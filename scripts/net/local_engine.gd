extends RefCounted
const TEMPLATES: Dictionary = {
	"disaster": [
		"In the {season} of year {year}, {kingdom} reels as {event_name}. {flavor} The court whispers of {hook}.",
		"Ashen skies over {kingdom}: {event_name} grips the realm. {flavor} Old oaths are tested as {hook} looms.",
	],
	"plague": [
		"Fever walks the lanes of {kingdom}. {event_name} has come in {season}, and {flavor} Prayers rise while {hook} spreads in shadow.",
		"The bells toll without cease — {event_name} haunts {kingdom}. {flavor} Even the nobles fear {hook}.",
	],
	"harvest": [
		"Golden fields sway beyond {kingdom}'s walls. {event_name} blesses the {season} harvest; {flavor} Yet {hook} waits beyond the granaries.",
		"Plenty graces {kingdom} this {season}. {event_name} fills storehouses, {flavor} and the people speak hopefully of {hook}.",
	],
	"diplomacy": [
		"Ravens fly between {kingdom} and its rivals. {event_name} reshapes the map; {flavor} Envoys murmur of {hook}.",
		"At court in {kingdom}, {event_name} stirs intrigue. {flavor} A letter sealed in wax hints at {hook}.",
	],
	"battle": [
		"Steel sang near {kingdom}. {event_name} left its mark; {flavor} Scouts report {hook} on the horizon.",
		"War drums fade over {kingdom}. After {event_name}, {flavor} The realm holds its breath for {hook}.",
	],
	"random": [
		"Turn {turn} in {kingdom} — {event_name}. {flavor} The chronicles note {hook}.",
		"In {kingdom} during {season}, {event_name} unfolds. {flavor} Whispers of {hook} follow.",
	],
}
const FLAVORS: PackedStringArray = [
	"dust settles slowly on empty roads",
	"children sing half-remembered hymns",
	"the treasury counts coin by candlelight",
	"elders recall a like omen from decades past",
	"market stalls shutter early",
	"a cold wind carries rumors from the border",
	"the ruler's banner snaps stubbornly above the keep",
	"ravens circle patiently",
]
const HOOKS: PackedStringArray = [
	"a coming famine",
	"a restless northern baron",
	"a forgotten claim to the southern valley",
	"a heresy in the mountain chapels",
	"a merchant league seeking charter",
	"a lost heir's return",
	"a drought that may yet deepen",
	"a plague that may yet spread",
]
func _pick(rng: RandomNumberGenerator, arr) -> String:
	if arr is Array and not arr.is_empty():
		return str(arr[rng.randi_range(0, arr.size() - 1)])
	if arr is PackedStringArray and not arr.is_empty():
		return str(arr[rng.randi_range(0, arr.size() - 1)])
	return ""
func _hash_seed(s: String) -> int:
	var h := hash(s)
	return int(h & 0x7fffffff)
func generate(prompt: Dictionary) -> Dictionary:
	var ctx: Dictionary = prompt.get("system_context", {}) as Dictionary if prompt.has("system_context") else prompt
	var event: Dictionary = prompt.get("event", {}) as Dictionary if prompt.has("event") else {}
	if event.is_empty() and prompt.has("type"):
		event = prompt
	var kingdom: String = str(ctx.get("kingdom_name", ctx.get("kingdom", "Eterna")))
	if kingdom == "":
		kingdom = str(Game.settings.get("kingdom_name", "Eterna")) if Game != null else "Eterna"
	var season: String = str(ctx.get("season", Game.season() if Game != null else "spring"))
	var year: int = int(ctx.get("year", Game.year if Game != null else 0))
	var turn: int = int(ctx.get("turn", Game.turn if Game != null else 0))
	var event_name: String = str(event.get("name", event.get("text", event.get("type", "a quiet season"))))
	if event_name.length() > 120:
		event_name = event_name.substr(0, 117) + "…"
	var category: String = str(event.get("category", event.get("type", "random"))).to_lower()
	var seed_src := "%s|%s|%d|%s" % [kingdom, category, turn, event_name]
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_seed(seed_src)
	var tpl_arr: Variant = TEMPLATES.get(category, TEMPLATES["random"])
	var tpl: String = _pick(rng, tpl_arr)
	var flavor: String = _pick(rng, FLAVORS)
	var hook: String = _pick(rng, HOOKS)
	var hooks: Array = [hook]
	if rng.randf() < 0.35:
		hooks.append(_pick(rng, HOOKS))
	var text := tpl.replace("{kingdom}", kingdom).replace("{season}", season).replace("{year}", str(year)).replace("{turn}", str(turn)).replace("{event_name}", event_name).replace("{flavor}", flavor).replace("{hook}", hook)
	if not text.ends_with("."):
		text += "."
	var base_choices: Variant = event.get("choices", [])
	var choices: Array[Dictionary] = []
	if typeof(base_choices) == TYPE_ARRAY and not (base_choices as Array).is_empty():
		for ch in base_choices as Array:
			if typeof(ch) == TYPE_DICTIONARY:
				var d: Dictionary = ch as Dictionary
				choices.append({
					"id": str(d.get("id", "")),
					"label": str(d.get("label", d.get("id", ""))),
					"hint": str(d.get("hint", "")),
					"effects": d.get("effects", {}),
				})
	else:
		choices = _fallback_choices(category, rng)
	var result: Dictionary = {
		"text": text,
		"choices": choices,
		"hooks": hooks,
		"provider": "local",
		"cached": false,
	}
	return _validate_schema(result, prompt)
func _fallback_choices(category: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	match category:
		"disaster", "plague":
			return [
				{"id": "aid", "label": "Send aid", "hint": "Costs gold, saves happiness", "effects": {"gold": -15, "happiness": 0.05}},
				{"id": "endure", "label": "Endure", "hint": "No cost, morale suffers", "effects": {"happiness": -0.06}},
				{"id": "pray", "label": "Pray and conserve", "hint": "Small food save", "effects": {"food": 8, "happiness": 0.02}},
			]
		"battle":
			return [
				{"id": "press", "label": "Press advantage", "hint": "Morale risk", "effects": {"happiness": 0.04}},
				{"id": "fortify", "label": "Fortify", "hint": "Spend stone", "effects": {"stone": -10, "happiness": 0.02}},
				{"id": "parley", "label": "Offer parley", "hint": "Diplomacy chance", "effects": {}},
			]
		_:
			return [
				{"id": "embrace", "label": "Embrace the moment", "hint": "Steady course", "effects": {}},
				{"id": "invest", "label": "Invest further", "hint": "Spend gold for gain", "effects": {"gold": -10, "happiness": 0.03}},
				{"id": "defer", "label": "Defer decision", "hint": "Save resources", "effects": {}},
			]
func _validate_schema(result: Dictionary, _prompt: Dictionary) -> Dictionary:
	if not result.has("text") or typeof(result["text"]) != TYPE_STRING or (result["text"] as String).strip_edges() == "":
		result["text"] = "The chronicle turns quietly in %s." % str(Game.settings.get("kingdom_name", "the realm"))
	if not result.has("choices") or typeof(result["choices"]) != TYPE_ARRAY:
		result["choices"] = []
	var clean: Array[Dictionary] = []
	for ch in result["choices"] as Array:
		if typeof(ch) == TYPE_DICTIONARY:
			var d: Dictionary = ch as Dictionary
			if str(d.get("id", "")) != "" and str(d.get("label", "")) != "":
				clean.append(d)
	if clean.is_empty():
		clean = [{"id": "continue", "label": "Continue", "hint": "", "effects": {}}]
	result["choices"] = clean.slice(0, 3)
	if not result.has("hooks") or typeof(result["hooks"]) != TYPE_ARRAY:
		result["hooks"] = []
	var hclean: PackedStringArray = []
	for h in result["hooks"] as Array:
		if typeof(h) == TYPE_STRING and (h as String).strip_edges() != "":
			hclean.append(h as String)
	result["hooks"] = Array(hclean).slice(0, 3)
	return result
