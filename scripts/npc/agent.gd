extends RefCounted
class_name Agent

const NEED_KEYS: PackedStringArray = ["hunger", "rest", "safety", "social", "faith", "wealth"]
const LIFECYCLES: PackedStringArray = ["child", "youth", "adult", "elder"]
const CLASSES: PackedStringArray = ["peasants", "merchants", "clergy", "nobles", "soldiers", "scholars"]
const JOBS: PackedStringArray = ["idle", "farmer", "miller", "baker", "woodcutter", "miner", "builder", "merchant", "priest", "guard", "scholar"]
const TRAIT_POOL: PackedStringArray = ["hardy", "pious", "gregarious", "frugal", "ambitious", "honest", "brave", "diligent", "curious", "stoic", "kind", "cunning"]

var id: int = -1
var agent_name: String = ""
var agent_class: String = "peasants"
var pos: Vector3 = Vector3.ZERO
var needs: Dictionary = {}
var traits: Array[String] = []
var skills: Dictionary = {}
var job: String = "idle"
var household: int = -1
var age: float = 22.0
var lifecycle: String = "adult"
var relations: Dictionary = {}
var memory: Array[Dictionary] = []
var goals: Array[String] = []

static func create(p_id: int, p_pos: Vector3, p_culture: String, p_class: String, p_job: String, p_household: int, rng: RandomNumberGenerator) -> Agent:
	var a := Agent.new()
	a.id = p_id
	a.pos = p_pos
	a.agent_class = _sanitize_class(p_class)
	a.job = _sanitize_job(p_job)
	a.household = p_household
	var gender: String = NPCNames.random_gender(rng)
	a.agent_name = NPCNames.generate(p_culture, gender, rng)
	a.age = _random_age(rng)
	a.lifecycle = _lifecycle_for_age(a.age)
	a.needs = _random_needs(rng)
	a.traits = _random_traits(rng)
	a.skills = _skills_for_class(a.agent_class, rng)
	a.relations = {}
	a.memory = []
	a.goals = []
	return a

static func _sanitize_class(raw: String) -> String:
	var c := raw.to_lower().strip_edges()
	if CLASSES.has(c):
		return c
	return "peasants"

static func _sanitize_job(raw: String) -> String:
	var j := raw.to_lower().strip_edges()
	if JOBS.has(j):
		return j
	return "idle"

static func _lifecycle_for_age(a: float) -> String:
	if a < 12.0:
		return "child"
	if a < 18.0:
		return "youth"
	if a < 55.0:
		return "adult"
	return "elder"

static func _random_age(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if roll < 0.15:
		return rng.randf_range(5.0, 12.0)
	if roll < 0.30:
		return rng.randf_range(12.0, 18.0)
	if roll < 0.85:
		return rng.randf_range(18.0, 50.0)
	return rng.randf_range(50.0, 72.0)

static func _random_needs(rng: RandomNumberGenerator) -> Dictionary:
	var d := {}
	for k in NEED_KEYS:
		d[k] = clampf(rng.randf_range(0.35, 0.75), 0.0, 1.0)
	return d

static func _random_traits(rng: RandomNumberGenerator) -> Array[String]:
	var count := rng.randi_range(1, 3)
	var pool: Array[String] = []
	for t in TRAIT_POOL:
		pool.append(t)
	pool.shuffle()
	var out: Array[String] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	return out

static func _skills_for_class(klass: String, rng: RandomNumberGenerator) -> Dictionary:
	var base := {"farming": 0.2, "craft": 0.2, "faith": 0.2, "trade": 0.2, "combat": 0.15, "knowledge": 0.2}
	match klass:
		"peasants":
			base["farming"] = rng.randf_range(0.5, 0.9)
			base["craft"] = rng.randf_range(0.3, 0.6)
		"merchants":
			base["trade"] = rng.randf_range(0.6, 0.95)
		"clergy":
			base["faith"] = rng.randf_range(0.6, 0.95)
		"nobles":
			base["trade"] = rng.randf_range(0.4, 0.7)
			base["combat"] = rng.randf_range(0.3, 0.6)
		"soldiers":
			base["combat"] = rng.randf_range(0.6, 0.95)
		"scholars":
			base["knowledge"] = rng.randf_range(0.6, 0.95)
	return base

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": agent_name,
		"class": agent_class,
		"pos": {"x": pos.x, "y": pos.y, "z": pos.z},
		"needs": needs.duplicate(),
		"traits": traits.duplicate(),
		"skills": skills.duplicate(),
		"job": job,
		"household": household,
		"age": age,
		"lifecycle": lifecycle,
	}

func need(key: String) -> float:
	return float(needs.get(key, 0.5))

func set_need(key: String, v: float) -> void:
	needs[key] = clampf(v, 0.0, 1.0)

func tick_needs(delta: float) -> void:
	set_need("hunger", need("hunger") - 0.002 * delta)
	set_need("rest", need("rest") - 0.0015 * delta)
	set_need("social", need("social") - 0.001 * delta)

func is_depleted() -> bool:
	return need("hunger") <= 0.01 or need("rest") <= 0.01
