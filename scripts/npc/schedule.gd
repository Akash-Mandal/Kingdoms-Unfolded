extends RefCounted
class_name Schedule

static func build(job: String) -> Array:
	var s: Array = []
	s.resize(24)
	for i in 24:
		s[i] = "idle"
	for h in range(0, 6):
		s[h] = "sleep"
	for h in range(22, 24):
		s[h] = "sleep"
	match job:
		"farmer", "miller", "baker", "builder":
			s[6] = "pray"
			s[7] = "eat"
			s[8] = "work"
			s[9] = "work"
			s[10] = "work"
			s[11] = "work"
			s[12] = "eat"
			s[13] = "work"
			s[14] = "work"
			s[15] = "work"
			s[16] = "work"
			s[17] = "work"
			s[18] = "pray"
			s[19] = "eat"
			s[20] = "socialize"
			s[21] = "socialize"
		"idle":
			s[6] = "pray"
			s[7] = "eat"
			s[8] = "socialize"
			s[9] = "socialize"
			s[10] = "work"
			s[11] = "work"
			s[12] = "eat"
			s[13] = "socialize"
			s[14] = "socialize"
			s[15] = "socialize"
			s[16] = "socialize"
			s[17] = "socialize"
			s[18] = "pray"
			s[19] = "eat"
			s[20] = "socialize"
			s[21] = "socialize"
		_:
			s[6] = "pray"
			s[7] = "eat"
			s[12] = "eat"
			s[18] = "pray"
			s[19] = "eat"
			s[20] = "socialize"
	return s

static func action_at(hour: float, sched: Array) -> String:
	if sched.is_empty():
		return "idle"
	var h: int = int(hour) % 24
	if h < 0 or h >= sched.size():
		return "idle"
	return str(sched[h])

static func schedule_mult(action: String, scheduled: String) -> float:
	if action == scheduled:
		return 1.35
	return 1.0
