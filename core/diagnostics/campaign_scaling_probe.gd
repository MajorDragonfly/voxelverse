extends SceneTree
const Home = preload("res://world/home_group/home_group_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
const Simulation = preload("res://world/tribe/village_simulation.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	state.set_process(false)
	var measurements: Array = []
	for count in [1, 10, 100]:
		state.start_world_with_seed(15838)
		state.current_phase = 1
		for index in range(count):
			var created: Dictionary = state.get_current_body() if index == 0 else state.campaign.ensure_body(15838, 20000 + index)
			var body: Dictionary = state.campaign.body_record(created.id)
			body.home_group = Home.create(body.id, state.campaign.data.player_species_id, Vector3.ZERO)
			body.tribe = Tribe.create(body.home_group, state.campaign.data, {"position": [0, 0, 0]}, {"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
			var roads: Dictionary = {}
			for point in [body.tribe.anchor, body.tribe.deposits.wood.position, body.tribe.members[1].position, body.tribe.members[2].position]:
				var path: Array = []
				var steps: int = maxi(1, ceili(Home.distance(body.tribe.anchor, point)))
				for step in range(steps + 1): path.append(Simulation._interpolate(body.tribe.anchor, point, float(step) / steps))
				roads[Simulation.key(point)] = path
			body.village_simulation = Simulation.create(body.id, 0, roads, [], state.campaign.data.player_object_id)
			if index == 0: body.village_simulation.owner = "near"
			for member: Dictionary in body.tribe.members: member.order = "wood"
		state.far_scheduler.rebuild(state.campaign.data)
		var costs: Array[int] = []
		var jobs: int = 0
		for frame in range(1200):
			state.campaign.data.elapsed_seconds += 1.0 / 60.0
			state.far_scheduler.process(state.campaign.data, state.active_body_id, 1.0, root.get_node("ProgressionService").record_far_work.bind(state))
			costs.append(state.far_scheduler.last_usecs)
			jobs = maxi(jobs, state.far_scheduler.last_jobs)
		costs.sort()
		var started: int = Time.get_ticks_usec()
		for index in range(10000): state.get_current_body_record()
		var reads_usec: int = Time.get_ticks_usec() - started
		var path: String = "user://campaign_scaling_%d.json" % count
		started = Time.get_ticks_usec()
		var saved: bool = saves.save_now(path)
		var save_usec: int = Time.get_ticks_usec() - started
		if not saved: failures.append(saves.last_error)
		var bytes: int = FileAccess.get_file_as_bytes(path).size() if saved else 0
		started = Time.get_ticks_usec()
		var loaded: bool = saves.load_now(path)
		var load_usec: int = Time.get_ticks_usec() - started
		if not loaded: failures.append(saves.last_error)
		if jobs > state.far_scheduler.MAX_JOBS or state.campaign.data.bodies.size() != count: failures.append("Budget/identity count changed.")
		measurements.append({"bodies": count, "save_bytes": bytes, "save_ms": save_usec / 1000.0, "load_ms": load_usec / 1000.0,
			"body_reads_10000_ms": reads_usec / 1000.0, "far_slice_p95_ms": costs[1139] / 1000.0, "far_slice_max_ms": costs.back() / 1000.0,
			"far_jobs_max": jobs, "static_allocator_bytes": OS.get_static_memory_usage()})
	var report: Dictionary = {"godot": Engine.get_version_info().string, "os": OS.get_name(), "cpu": OS.get_processor_name(),
		"fixture": "1/10/100 visited bodies with three-resident minimal villages, 1200 frames with production progression observer; no terrain, GPU or target-PC FPS measurement", "measurements": measurements}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--report" in args:
		var destination: String = args[args.find("--report") + 1]
		if preload("res://core/persistence/atomic_json.gd").write(destination, report, false) != OK: failures.append("Could not write benchmark report.")
	print("CAMPAIGN_SCALING_MEASUREMENTS ", JSON.stringify(report))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("CAMPAIGN_SCALING_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
