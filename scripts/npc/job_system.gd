extends RefCounted
class_name JobSystem

const JOBS: PackedStringArray = ["farmer", "miller", "baker", "builder", "idle"]

const BUILDING_JOB: Dictionary = {
	"farm": {"job": "farmer", "slots": 2},
	"house": {"job": "idle", "slots": 0},
	"mill": {"job": "miller", "slots": 1},
	"bakery": {"job": "baker", "slots": 1},
}

const BUILDER_DEMAND_PER_BUILDING: float = 0.15
const MAX_BUILDER_SLOTS: int = 4

static func compute_demand(placed: Array) -> Dictionary:
	var demand: Dictionary = {}
	for j in JOBS:
		demand[j] = 0
	var total_buildings: int = placed.size()
	for entry in placed:
		var id: String = ""
		if typeof(entry) == TYPE_DICTIONARY:
			id = str(entry.get("id", ""))
		elif entry is Node3D and "building_id" in entry:
			id = str(entry.building_id)
		else:
			continue
		var cfg: Dictionary = BUILDING_JOB.get(id, {})
		var job: String = str(cfg.get("job", "idle"))
		var slots: int = int(cfg.get("slots", 0))
		if job != "idle" and slots > 0:
			demand[job] = int(demand.get(job, 0)) + slots
	var builder_need: int = clampi(int(ceil(total_buildings * BUILDER_DEMAND_PER_BUILDING)), 0, MAX_BUILDER_SLOTS)
	if total_buildings > 0 and builder_need == 0:
		builder_need = 1
	demand["builder"] = builder_need
	return demand

static func compute_demand_from_counts(counts: Dictionary) -> Dictionary:
	var demand: Dictionary = {}
	for j in JOBS:
		demand[j] = 0
	var total: int = 0
	for id in counts:
		var n: int = int(counts[id])
		total += n
		var cfg: Dictionary = BUILDING_JOB.get(str(id), {})
		var job: String = str(cfg.get("job", "idle"))
		var slots: int = int(cfg.get("slots", 0))
		if job != "idle" and slots > 0:
			demand[job] = int(demand.get(job, 0)) + slots * n
	var builder_need: int = clampi(int(ceil(total * BUILDER_DEMAND_PER_BUILDING)), 0, MAX_BUILDER_SLOTS)
	if total > 0 and builder_need == 0:
		builder_need = 1
	demand["builder"] = builder_need
	return demand

static func assign(agents: Array, demand: Dictionary) -> void:
	if agents.is_empty():
		return
	var remaining: Dictionary = demand.duplicate(true)
	var unassigned: Array = []
	for a in agents:
		var j: String = ""
		if typeof(a) == TYPE_DICTIONARY:
			j = str(a.get("job", "idle"))
		elif a is Node and "job" in a:
			j = str(a.job)
		if j == "idle" or j == "":
			unassigned.append(a)
		else:
			var need: int = int(remaining.get(j, 0))
			if need > 0:
				remaining[j] = need - 1
			else:
				unassigned.append(a)
				if typeof(a) == TYPE_DICTIONARY:
					a["job"] = "idle"
				elif a is Node and "job" in a:
					a.job = "idle"
	for job in JOBS:
		if job == "idle":
			continue
		var need: int = int(remaining.get(job, 0))
		while need > 0 and not unassigned.is_empty():
			var ag: Variant = unassigned.pop_front()
			if typeof(ag) == TYPE_DICTIONARY:
				ag["job"] = job
			elif ag is Node and "job" in ag:
				ag.job = job
			need -= 1
		remaining[job] = need
	for ag in unassigned:
		if typeof(ag) == TYPE_DICTIONARY:
			ag["job"] = "idle"
		elif ag is Node and "job" in ag:
			ag.job = "idle"

static func demand_summary(demand: Dictionary) -> String:
	var parts: PackedStringArray = []
	for j in JOBS:
		parts.append("%s:%d" % [j, int(demand.get(j, 0))])
	return ", ".join(parts)

static func ideal_pop_for_demand(demand: Dictionary) -> int:
	var s: int = 0
	for j in demand:
		s += int(demand[j])
	return s
