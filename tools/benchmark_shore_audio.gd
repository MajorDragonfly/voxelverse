extends SceneTree
## CPU-only comparison of the real water sampler and audio shore search.
const System = preload("res://world/space/celestial_system.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Water = preload("res://world/surface/campaign_water.gd")
class TerrainFixture:
	extends Node3D
	signal origin_changed(previous: Array, current: Array)
	var surface: RefCounted
	var origin: Array
	func ground_ready(_point: Array) -> bool: return true
var count: int = 0
var water: Node
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var audio: Node = root.get_node("AudioManager")
	var director: Node = audio.director
	director.set_physics_process(false)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var descriptor: Dictionary = System.new(false,true).bodies["m1b:terra"].duplicate(true)
	descriptor.surface_generation = "living_planet_v2"
	var terrain := TerrainFixture.new()
	terrain.surface = Factory.create(descriptor)
	var point: Dictionary = Cube.address(descriptor.id, 0, 0.25, 0.25)
	point.height = maxf(terrain.surface.sample(point).water_level, terrain.surface.sample(point).height) + 3.0
	terrain.origin = Cube.cartesian(point, descriptor.radius)
	scene.add_child(terrain)
	var adapter := Adapter.new(terrain)
	scene.set_meta("campaign_surface", adapter)
	var player := CharacterBody3D.new()
	scene.add_child(player)
	adapter.bind("observer", player, point)
	water = Water.new()
	water.name = "Water"
	scene.add_child(water)
	director.sample_provider = _sample
	director._player = player
	var costs: Array[float] = []
	var queries: Array[int] = []
	var totals: Array[float] = []
	for iteration in range(10):
		var total: float = 0.0
		count = 0
		var started: int = Time.get_ticks_usec()
		director._update_environment()
		var elapsed: float = (Time.get_ticks_usec()-started)/1000.0
		costs.append(elapsed);queries.append(count);total += elapsed
		if director.has_method("_step_shore_search"):
			while director._shore_job != null:
				count = 0
				started = Time.get_ticks_usec()
				director._step_shore_search()
				elapsed = (Time.get_ticks_usec()-started)/1000.0
				costs.append(elapsed);queries.append(count);total += elapsed
				await process_frame
		totals.append(total)
		await process_frame
	costs.sort();totals.sort()
	print("SHORE_AUDIO_METRICS ", JSON.stringify({"scope":"Headless CPU, real living_planet_v2 water sampler, Terra seed 15838, synthetic collision-readiness port, 10 stationary searches, no renderer/FPS claim",
		"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().string,"steps":costs.size(),"max_queries_per_step":queries.max(),
		"total_queries":queries.reduce(func(a: int,b: int): return a+b,0),"step_p50_ms":costs[costs.size()/2],"step_p95_ms":costs[ceili(costs.size()*0.95)-1],
		"step_max_ms":costs[-1],"search_p50_ms":totals[5],"search_max_ms":totals[-1]}))
	director.reset_tracking()
	director.sample_provider = Callable()
	adapter.close()
	scene.free()
	current_scene = null
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self)
func _sample(point: Vector3) -> Dictionary:
	count += 1
	return water.audio_sample(point)
