extends SceneTree
## Real audio director, camera atmosphere, campaign water port and radial adapter.
## An analytic lake isolates geometry/ownership from procedural world generation.
const Water = preload("res://world/surface/campaign_water.gd")
const View = preload("res://world/visuals/underwater_view.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Search = preload("res://audio/runtime/shore_search.gd")
class SurfaceFixture:
	extends RefCounted
	var body: Dictionary = {"id":"audio-body-a", "radius":6371000.0}
	var water_present: bool = true
	func sample(_point: Dictionary) -> Dictionary:
		return {"height":2.0,"water_level":12.0,"water":water_present,"water_kind":"lake","biome":"forest"}
class TerrainFixture:
	extends Node3D
	signal origin_changed(previous: Array, current: Array)
	var surface := SurfaceFixture.new()
	var origin: Array
	func ground_ready(_point: Array) -> bool: return true
	func rebase(value: Array) -> void:
		var old: Array = origin
		origin = value
		origin_changed.emit(old,value)
var failures: Array[String] = []
var audio: Node
var director: Node
var scene: Node3D
var terrain: TerrainFixture
var adapter: RefCounted
var player: CharacterBody3D
var camera: Camera3D
var water: Node
var view: Node
var spawn: Dictionary

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	audio = root.get_node("AudioManager")
	director = audio.director
	director.set_physics_process(false)
	director.set_process(false)
	_setup()
	_immersion()
	_budget_and_completion()
	_rebase_and_scope()
	await _pause_and_teardown()
	_partial_search_parity()
	adapter.close()
	scene.free()
	current_scene = null
	director.sample_provider = Callable()
	director.reset_tracking()
	await process_frame
	for message in failures: push_error(message)
	print("SPHERICAL_WATER_AUDIO ", JSON.stringify({"passed":failures.is_empty(),"failures":failures,"diagnostics":director.sampling_diagnostics()}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _setup() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	terrain = TerrainFixture.new()
	spawn = Cube.address(terrain.surface.body.id,0,0.0,0.0,14.0)
	terrain.origin = Cube.cartesian(spawn,terrain.surface.body.radius)
	scene.add_child(terrain)
	adapter = Adapter.new(terrain)
	adapter.origin_shifted.connect(director.surface_origin_shifted)
	scene.set_meta("campaign_surface",adapter)
	player = CharacterBody3D.new()
	player.set_meta("surface_mode",Cube.MODE)
	scene.add_child(player)
	player.add_to_group(&"player")
	adapter.bind("player",player,spawn)
	camera = Camera3D.new()
	scene.add_child(camera)
	adapter.bind("camera",camera,spawn)
	camera.make_current()
	water = Water.new()
	water.name = "Water"
	scene.add_child(water)
	view = View.new()
	view.sample_water = water.view_sample
	scene.add_child(view)
	view.set_process(false)
	director.sample_provider = Callable()
	director.reset_tracking()
	director._physics_process(1.0/60.0)
	_expect(director._player == player, "Radial listener was not bound")

func _immersion() -> void:
	var cases: Array = [[-1.0,false],[0.05,true],[0.02,true],[0.006,true],[0.004,false],[0.02,false],[0.05,true],[-0.001,false]]
	for entry in cases:
		var eye: Dictionary = spawn.duplicate(true)
		eye.height = 12.0 - entry[0]
		adapter.place(camera,eye)
		view.update_view()
		director._update_environment()
		_expect(view.submerged == entry[1] and director._underwater == entry[1], "Picture/audio waterline disagreed at radial depth " + str(entry[0]))
		_expect(camera.global_position.y == 0.0, "Fixture no longer isolates a non-Y water surface")
	# A replacement camera starts with dry hysteresis, even at the same body.
	var deep: Dictionary = spawn.duplicate(true)
	deep.height = 11.95
	adapter.place(camera,deep)
	view.update_view();director._update_environment()
	var replacement := Camera3D.new()
	scene.add_child(replacement)
	var edge: Dictionary = spawn.duplicate(true)
	edge.height = 11.98
	adapter.place(replacement,edge)
	replacement.make_current()
	view.update_view();director._physics_process(1.0/60.0)
	_expect(not view.submerged and not director._underwater, "New camera inherited previous eye's immersion hysteresis")
	camera.make_current()
	view.update_view();director._physics_process(1.0/60.0)
	replacement.free()
	terrain.surface.water_present = false
	var below: Dictionary = spawn.duplicate(true)
	below.height = 10.0
	adapter.place(camera,below)
	view.update_view();director._update_environment()
	_expect(not view.submerged and not director._underwater, "Dry terrain below water level became submerged")
	terrain.surface.water_present = true
	adapter.place(camera,spawn)
	view.update_view()

func _budget_and_completion() -> void:
	director.reset_tracking()
	var completed: int = director.completed_shore_searches
	for tick in range(20):
		director._physics_process(0.1) # Deliberately slower than the sample cadence.
		_expect(director.last_sample_queries <= 4 and director.last_shore_queries <= Search.PROBES_PER_TICK, "Per-tick query limit exceeded")
		_expect(director.sampling_diagnostics().pending_searches <= 1, "Unbounded pending shore queue")
	_expect(director.completed_shore_searches > completed and director._shore_target == 0.75, "Low-frequency updates starved a complete shore search")
	var probe: Dictionary = water.audio_sample(camera.global_position)
	_expect(director._shore.global_position.distance_to(probe.water_point) < 0.01, "Water sound was not positioned on the radial lake surface")

func _rebase_and_scope() -> void:
	director.reset_tracking();director._physics_process(1.0/60.0)
	_expect(director._shore_job != null and director._shore_job.cursor == 2, "Missing partial search before rebase")
	var epoch: int = director._source_generation
	var old: Array = terrain.origin.duplicate()
	terrain.rebase([old[0]+90.0,old[1]-53.0,old[2]+27.0])
	_expect(director._shore_job.generation == epoch and director._shore_job.listener.distance_to(camera.global_position) < 0.001, "Origin shift invalidated or displaced pending audio")
	for tick in range(12): director._physics_process(1.0/60.0)
	_expect(director._shore_target > 0.0 and director._shore.global_position.distance_to(water.audio_sample(camera.global_position).water_point) < 0.01, "Rebased search published a stale local position")
	# A new body through the same live surface object must invalidate old results.
	director._update_environment()
	terrain.surface.body.id = "audio-body-b"
	terrain.surface.water_present = false
	director._physics_process(1.0/60.0)
	_expect(director._source_generation > epoch and not director._sample.water_present and director._shore_target == 0.0, "Body switch retained former water/shore audio")
	# Removing Water or the adapter is a missing capability, never a plane lookup.
	scene.remove_child(water)
	director._physics_process(1.0/60.0)
	_expect(director.sample_at(player.global_position).is_empty(), "Missing radial Water port used unrelated planar water")
	scene.add_child(water)
	scene.remove_meta("campaign_surface")
	_expect(director.sample_at(player.global_position).is_empty(), "Missing radial surface fell through to plane sampler")
	director._physics_process(1.0/60.0)
	_expect(director._player == null and director._shore_job == null, "Unsupported radial source retained its listener/job")
	scene.set_meta("campaign_surface",adapter)
	director._bind_clock = 0.0
	director._physics_process(1.0/60.0)
	# Explicit provider replacement must also cancel a partially sampled source.
	var provider_a: Callable = func(point: Vector3): return {"water_present":true,"water_point":point-Vector3.RIGHT,"up":Vector3.RIGHT}
	var provider_b: Callable = func(_point: Vector3): return {"water_present":false}
	director.sample_provider = provider_a
	director._physics_process(1.0/60.0)
	var before: int = director._source_generation
	director.sample_provider = provider_b
	director._physics_process(1.0/60.0)
	_expect(director._source_generation > before and director._shore_target == 0.0, "Provider replacement revived a former result")
	director.sample_provider = Callable()
	terrain.surface.water_present = true
	director._physics_process(1.0/60.0)

func _pause_and_teardown() -> void:
	var previous: Dictionary = director.sampling_diagnostics()
	director.set_physics_process(true)
	paused = true
	for tick in range(4): await process_frame
	_expect(director.sampling_diagnostics() == previous, "Pause advanced water sampling")
	paused = false
	director.set_physics_process(false)
	# Teleport the listener while the observer stays still; discard stale ring.
	camera.global_position += Vector3.UP * 80.0
	director._step_shore_search()
	_expect(director._shore_job == null and director._shore_target == 0.0, "Camera jump accepted an obsolete shore ring")
	camera.global_position -= Vector3.UP * 80.0
	director._update_environment()
	# Old player remains valid and attached, but belongs to an outgoing scene.
	var next := Node3D.new()
	root.add_child(next)
	current_scene = next
	director.sample_provider = water.audio_sample
	_expect(not director._has_sample_provider(), "Outgoing scene's provider remained usable in the next scene")
	director._physics_process(1.0/60.0)
	_expect(director._player == null and director._shore_job == null and not director._shore.playing, "Live outgoing scene retained world audio")
	next.free()
	current_scene = scene
	director.sample_provider = Callable()
	director._bind_clock = 0.0
	director._physics_process(1.0/60.0)
	director.reset_tracking()
	_expect(director._shore_job == null and director._underwater == false, "Reset retained a query or underwater state")

func _partial_search_parity() -> void:
	# Asymmetric shoreline: nearest result must be selected only after all probes.
	var query: Callable = func(point: Vector3): return {"water_present": point.x > 6.0,"water_point":Vector3(point.x,1.0,point.z),"up":Vector3.UP}
	var job := Search.new(Vector3(0,3,0),Basis.IDENTITY,7)
	var calls: int = 0
	while not job.complete():
		job.step(query)
		_expect(job.queries_last_step <= 2, "Search's own hard probe bound was exceeded")
		calls += job.queries_last_step
	_expect(calls == 25 and job.nearest_position.is_equal_approx(Vector3(7,1,0)), "Sliced search changed the nearest-shore result")

func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)
