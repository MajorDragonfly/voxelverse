extends RefCounted
const Simulation = preload("res://world/tribe/village_simulation.gd")
const MAX_JOBS: int = 32
const BUDGET_USECS: int = 2000
const Settlements = preload("res://world/tribe/settlement_collection.gd")
var queue: Array[Dictionary] = []
var cursor: int = 0
var last_jobs: int = 0
var last_usecs: int = 0

func rebuild(campaign: Dictionary) -> void:
	queue.clear()
	cursor = 0
	for body: Dictionary in campaign.get("bodies", {}).values():
		for id: String in Settlements.ids(body):
			if Settlements.view(body, id).get("village_simulation", {}).get("owner") == "far": queue.append({"body_id": body.id, "settlement_id": id})

func process(campaign: Dictionary, active_id: String, cooperation: float, observer: Callable = Callable()) -> void:
	last_jobs = 0
	var started: int = Time.get_ticks_usec()
	var clock: float = campaign.elapsed_seconds
	var visited: int = 0
	while not queue.is_empty() and last_jobs < MAX_JOBS and visited < queue.size():
		cursor %= queue.size()
		var job: Dictionary = queue[cursor]
		cursor += 1
		visited += 1
		var raw: Dictionary = campaign.bodies.get(job.body_id, {})
		if job.body_id == active_id and not raw.has("settlements"): continue
		var body: Dictionary = Settlements.view(raw, job.settlement_id)
		if body.is_empty(): continue
		if Simulation.advance(body, clock, cooperation, observer, job.body_id == active_id): last_jobs += 1
		if Time.get_ticks_usec() - started >= BUDGET_USECS: break
	last_usecs = Time.get_ticks_usec() - started
