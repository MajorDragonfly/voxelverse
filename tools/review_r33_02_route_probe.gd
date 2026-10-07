extends "res://tools/performance_route_probe.gd"
## Same route/survival contract, with the separately supplied opt-in owner patch.
const Readiness = preload("res://tools/review_r32_02_readiness.gd")
var preview_script: Script
var readiness: RefCounted
var readiness_cycle: int = -2

func _initialize() -> void:
	preview_script = load("res://creatures/runtime/creature_runtime_preview.gd")
	super._initialize()

func _tick() -> void:
	if cycle != readiness_cycle:
		readiness_cycle = cycle
		readiness = Readiness.new()
		if not report.has("readiness"): report.readiness = {}
		report.readiness[str(cycle)] = readiness.data
	if _is_world():
		current_scene.population.work_probe = readiness.record_work
		preview_script.call("set_build_probe", readiness.record_work)
	else:
		if preview_script.has_method("set_build_probe"): preview_script.call("set_build_probe", Callable())
	await super._tick()
	if _is_world():
		readiness.sample(current_scene.population, Time.get_ticks_usec(), stage)
		readiness.data.player = {"is_dead": current_scene.player.is_dead,
			"health": current_scene.player.current_health,
			"terrain_wait": current_scene.player.waiting_for_terrain}
	else:
		if preview_script.has_method("set_build_probe"): preview_script.call("set_build_probe", Callable())
