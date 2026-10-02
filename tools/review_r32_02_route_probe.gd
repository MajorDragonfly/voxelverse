extends "res://tools/performance_route_probe.gd"
## Opt-in observations on the unchanged route, clock and survival guards.
const Readiness = preload("res://tools/review_r32_02_readiness.gd")
var readiness: RefCounted
var readiness_cycle: int = -2

func _tick() -> void:
	await super._tick()
	if cycle != readiness_cycle:
		readiness_cycle = cycle
		readiness = Readiness.new()
		if not report.has("readiness"): report.readiness = {}
		report.readiness[str(cycle)] = readiness.data
	if _is_world():
		current_scene.population.work_probe = readiness.record_work
		readiness.sample(current_scene.population, Time.get_ticks_usec(), stage)
		readiness.data.player = {"is_dead": current_scene.player.is_dead,
			"health": current_scene.player.current_health,
			"terrain_wait": current_scene.player.waiting_for_terrain}
