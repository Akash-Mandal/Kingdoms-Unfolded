extends RefCounted
class_name Needs

const ACTIONS: PackedStringArray = ["eat", "sleep", "work", "pray", "socialize"]

const WEIGHTS: Dictionary = {
	"eat": {"hunger": 1.0, "rest": 0.05, "safety": 0.05, "social": 0.0, "faith": 0.0, "wealth": 0.1},
	"sleep": {"hunger": 0.05, "rest": 1.0, "safety": 0.2, "social": 0.0, "faith": 0.0, "wealth": 0.0},
	"work": {"hunger": -0.15, "rest": -0.1, "safety": 0.05, "social": 0.0, "faith": 0.0, "wealth": 1.0},
	"pray": {"hunger": 0.0, "rest": 0.05, "safety": 0.15, "social": 0.05, "faith": 1.0, "wealth": 0.0},
	"socialize": {"hunger": 0.0, "rest": 0.05, "safety": 0.1, "social": 1.0, "faith": 0.05, "wealth": 0.0},
}

const JOB_AFFINITY: Dictionary = {
	"farmer": {"work": 1.25, "eat": 1.0, "sleep": 1.0, "pray": 0.9, "socialize": 0.9},
	"miller": {"work": 1.25, "eat": 1.0, "sleep": 1.0, "pray": 0.9, "socialize": 0.9},
	"baker": {"work": 1.25, "eat": 1.1, "sleep": 1.0, "pray": 0.9, "socialize": 1.0},
	"builder": {"work": 1.3, "eat": 1.0, "sleep": 1.0, "pray": 0.85, "socialize": 0.85},
	"idle": {"work": 0.7, "eat": 1.0, "sleep": 1.0, "pray": 1.0, "socialize": 1.15},
}

const NEED_KEYS: PackedStringArray = ["hunger", "rest", "safety", "social", "faith", "wealth"]

const DRIFT_RATES: Dictionary = {
	"hunger": 0.012,
	"rest": 0.009,
	"safety": 0.002,
	"social": 0.006,
	"faith": 0.004,
	"wealth": 0.007,
}

const RECOVERY: Dictionary = {
	"eat": {"hunger": 0.55},
	"sleep": {"rest": 0.65, "safety": 0.1},
	"work": {"wealth": 0.35, "social": -0.05, "rest": -0.06, "hunger": -0.04},
	"pray": {"faith": 0.5, "safety": 0.15},
	"socialize": {"social": 0.5, "faith": 0.05},
}

static func new_needs(rng: RandomNumberGenerator = null) -> Dictionary:
	var d: Dictionary = {}
	for k in NEED_KEYS:
		var v := 0.25 + randf() * 0.25
		if rng != null:
			v = 0.25 + rng.randf() * 0.25
		d[k] = clampf(v, 0.0, 1.0)
	return d

static func drift(needs: Dictionary, delta: float) -> void:
	var step: float = clampf(delta, 0.0, 1.0)
	for k in NEED_KEYS:
		needs[k] = clampf(float(needs.get(k, 0.0)) + float(DRIFT_RATES.get(k, 0.0)) * step, 0.0, 1.0)

static func apply_action(needs: Dictionary, action: String, delta: float) -> void:
	var rec: Dictionary = RECOVERY.get(action, {})
	for k in rec:
		var cur: float = float(needs.get(k, 0.0))
		var rate: float = float(rec[k])
		if rate > 0.0:
			needs[k] = clampf(cur - rate * delta, 0.0, 1.0)
		else:
			needs[k] = clampf(cur - rate * delta, 0.0, 1.0)

static func time_mult(action: String, hour: float) -> float:
	var h: int = int(hour) % 24
	match action:
		"sleep":
			if h >= 22 or h <= 5:
				return 1.6
			if h <= 6:
				return 1.35
			return 0.55
		"eat":
			if h == 7 or h == 8 or h == 12 or h == 18 or h == 19:
				return 1.7
			if h == 6 or h == 13 or h == 20:
				return 1.2
			return 0.75
		"work":
			if h >= 6 and h <= 18:
				if h == 12 or h == 7 or h == 18:
					return 0.65
				return 1.35
			return 0.35
		"pray":
			if h == 6 or h == 12 or h == 18:
				return 1.5
			if h == 5 or h == 21:
				return 1.25
			return 0.9
		"socialize":
			if h >= 17 and h <= 21:
				return 1.5
			if h >= 12 and h <= 13:
				return 1.15
			return 0.85
	return 1.0

static func job_mult(action: String, job: String) -> float:
	var m: Dictionary = JOB_AFFINITY.get(job, {})
	return float(m.get(action, 1.0))

static func score(action: String, needs: Dictionary, hour: float, job: String) -> float:
	var w: Dictionary = WEIGHTS.get(action, {})
	var s: float = 0.0
	for k in w:
		s += float(w[k]) * clampf(float(needs.get(k, 0.0)), 0.0, 1.0)
	s *= time_mult(action, hour)
	s *= job_mult(action, job)
	s *= 0.92 + randf() * 0.16
	return s

static func pick_best(needs: Dictionary, hour: float, job: String) -> String:
	var best: String = "idle"
	var best_s: float = -INF
	for a in ACTIONS:
		var sc: float = score(a, needs, hour, job)
		if sc > best_s:
			best_s = sc
			best = a
	if best_s < 0.08:
		return "idle"
	return best

static func pick_best_deterministic(needs: Dictionary, hour: float, job: String) -> String:
	var best: String = "idle"
	var best_s: float = -INF
	for a in ACTIONS:
		var w: Dictionary = WEIGHTS.get(a, {})
		var s: float = 0.0
		for k in w:
			s += float(w[k]) * clampf(float(needs.get(k, 0.0)), 0.0, 1.0)
		s *= time_mult(a, hour)
		s *= job_mult(a, job)
		if s > best_s:
			best_s = s
			best = a
	if best_s < 0.08:
		return "idle"
	return best
