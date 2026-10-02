extends "res://core/diagnostics/spherical_campaign_probe.gd"
## Regular campaign, public village handoff/orders, one saved comparison start.
const Space = preload("res://world/surface/gameplay_space.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
var config: Dictionary
var report: Dictionary = {"checks": [], "frames": [], "limits": [], "target_pc_acceptance": false}
var camera: Camera3D
var tribe: Node
var output: String
var capture_index: int = 0
var saw_work: bool = false
var saw_delivery: bool = false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	config = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--motion-config") + 1]))
	output = config.output
	DirAccess.make_dir_recursive_absolute(output)
	saves = tree.root.get_node("SaveGameService")
	state = tree.root.get_node("GameState")
	flow = tree.root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	tree.root.size = Vector2i(960, 540)
	RenderingServer.render_loop_enabled = false
	if config.mode == "prepare":
		await _prepare()
	else:
		await _compare()
	await _finish_motion()

func _prepare() -> void:
	var path: String = saves.create_slot("R32-17 combined motion", 15838, Cube.MODE)
	await _open(path)
	if not _expect_world(): return
	var home: Node = tree.current_scene.get_node("Nest/HomeGroup")
	var established: Dictionary = home.establish_home()
	_check(established.get("ok", false), "home established", established)
	await _until(func() -> bool: return home.actors.size() == 2, 10000)
	tribe = tree.current_scene.get_node("Nest/Tribe")
	var reason: String = tribe.prepare_confirmation()
	_check(reason.is_empty(), "village handoff prepared", reason)
	if not reason.is_empty(): return
	_check(tribe.panel.open_confirmation(), "explicit epoch confirmation opened")
	tribe.panel.confirm.pressed.emit()
	await _until(func() -> bool: return tribe.is_active(), 12000)
	_check(tribe.is_active(), "regular village handoff active")
	if not tribe.is_active(): return
	tribe.select_all()
	_check(tribe.issue_order("wait"), "comparison residents waiting")
	state.set_simulation_speed(0.0)
	for frame in range(12): await tree.process_frame
	_check(saves.save_now(), "comparison start saved", saves.last_error)
	var marker := {"path": path, "clock": state.campaign.data.elapsed_seconds,
		"village": Migration.fingerprint(tribe.village()), "body": state.active_body_id}
	Atomic.write("user://r32_17_motion_start.json", marker, false)
	report.initial = marker
	report.population = {"animals": tree.current_scene.population.animals.size(), "flora": tree.current_scene.flora.instance_count()}

func _compare() -> void:
	_check(DisplayServer.get_name() != "headless", "native display required")
	if DisplayServer.get_name() == "headless": return
	var marker: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://r32_17_motion_start.json"))
	if marker.is_empty(): _check(false, "missing exact saved comparison start"); return
	await _open(marker.path)
	if not _expect_world(): return
	tribe = tree.current_scene.get_node("Nest/Tribe")
	await _until(func() -> bool: return tribe.is_active() and tribe.navigation.is_ready(), 45000)
	_check(tribe.is_active(), "replay village active")
	if not tribe.is_active(): return
	_check(is_equal_approx(state.campaign.data.elapsed_seconds, marker.clock), "replay uses saved clock")
	_check(Migration.fingerprint(tribe.village()) == marker.village, "replay uses saved orders and stock")
	_camera()
	if not tribe.panel._collapsed: tribe.panel._collapse.pressed.emit()
	# Only setup rendering is skipped. The measured/captured campaign keeps
	# normal terrain/population/weather processing and all genuine actors.
	RenderingServer.render_loop_enabled = true
	await tree.process_frame
	await RenderingServer.frame_post_draw
	report.initial = marker
	report.recipe = {"seed": 15838, "size": [960, 540], "capture_hz": 30, "fov": camera.fov,
		"camera_offset": [0, 10, 18], "target_offset": [0, 1, 0], "renderer": RenderingServer.get_current_rendering_method(),
		"graphics": tree.root.get_node("DisplaySettings").graphics_values.duplicate(true)}
	report.environment = {"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_video_adapter_api_version(), "engine": Engine.get_version_info()}
	report.water_candidates = _water_candidates()
	var before_stock: int = int(tribe.village().stock.wood)
	tribe.select_all()
	_check(tribe.issue_order("wood"), "real wood order accepted")
	state.set_simulation_speed(1.0)
	await _clip("gather", 240)
	_check(saw_work, "actual arrived work and visible tools observed")
	var paused_data: String = Migration.fingerprint(tribe.village())
	var paused_clock: float = state.campaign.data.elapsed_seconds
	var tools: Dictionary = _tools()
	state.set_simulation_speed(0.0)
	await _clip("tempo_pause", 30)
	_check(_tools() == tools, "tempo pause freezes tool pose/lifetime")
	_check(Migration.fingerprint(tribe.village()) == paused_data and state.campaign.data.elapsed_seconds == paused_clock,
		"tempo pause freezes real village and campaign")
	tree.paused = true
	tools = _tools()
	await _clip("tree_pause", 30)
	_check(_tools() == tools and Migration.fingerprint(tribe.village()) == paused_data,
		"tree pause freezes real village and tools")
	tree.paused = false
	state.set_simulation_speed(1.0)
	await _clip("resume", 90)
	await _clip("distance_out", 60)
	await _clip("distance_return", 60)
	for kind: String in ["ocean", "lake"]:
		if report.water_candidates.has(kind) and report.water_candidates[kind].ground_ready:
			await _clip("water_" + kind, 60)
		else:
			report.limits.append("No loaded " + kind + " view in this saved village scene; this case remains open.")
	_check(int(tribe.village().stock.wood) > before_stock, "wood physically delivered to stock")
	# The shared save/load path owns all progression and delivery counters.
	flow.toggle_pause()
	var saved_clock: float = state.campaign.data.elapsed_seconds
	_check(saves.save_now(), "real pause save succeeds", saves.last_error)
	var saved_village: String = Migration.fingerprint(tribe.village())
	report.save_checkpoint = {"clock": saved_clock, "village": saved_village, "stock": tribe.village().stock.duplicate(true)}
	RenderingServer.render_loop_enabled = false
	flow.return_to_title()
	await tree.scene_changed
	await _open(marker.path, true)
	if not _expect_world(): return
	tribe = tree.current_scene.get_node("Nest/Tribe")
	_check(Migration.fingerprint(state.get_current_body_record().tribe) == saved_village, "load retains exact village/counters")
	_check(is_equal_approx(state.campaign.data.elapsed_seconds, saved_clock), "load retains campaign clock")
	flow.resume()
	await _until(func() -> bool: return tribe.is_active(), 45000)
	_check(tribe.is_active(), "loaded village resumes")
	if not tribe.is_active(): return
	_camera()
	if not tribe.panel._collapsed: tribe.panel._collapse.pressed.emit()
	RenderingServer.render_loop_enabled = true
	await _clip("after_load", 90)
	_check(state.campaign.data.elapsed_seconds > saved_clock, "same campaign clock continues after load")
	_check(tree.current_scene.terrain.presentation.clock_source.is_valid(), "active water reads campaign clock")
	report.final_stock = tribe.village().stock.duplicate(true)
	var all_tools: Dictionary = _tools()
	_check(all_tools.size() <= tribe.actors.size(), "one bounded reusable tool per resident")
	if not report.water_candidates.has("ocean") or not report.water_candidates.has("lake"):
		report.limits.append("The combined village view has no proven visible ocean AND lake; sampled candidates alone are not a water-view acceptance.")
	report.limits.append("Fixed 30-Hz software-rendered capture; PNG readback time and simulation replay are not target-PC FPS or the #167 walking route.")
	report.limits.append("R32-09 owns wind shader/rebase corrections; this branch preserves the assigned basis shaders.")

func _camera() -> void:
	camera = Camera3D.new()
	camera.name = "R32MotionObserver"
	camera.fov = 65.0
	camera.near = 0.2
	camera.far = 30000.0
	tree.current_scene.add_child(camera)
	_pose(0.0)
	camera.make_current()

func _pose(distance_mix: float) -> void:
	var anchor: Vector3 = tribe.anchor()
	var frame: Basis = Space.frame(self, anchor)
	var offset: Vector3 = Vector3(0, 10, 18).lerp(Vector3(0, 22, 80), distance_mix)
	camera.global_position = anchor + frame * offset
	camera.look_at(anchor + frame.y, frame.y)

func _clip(stage: String, count: int) -> void:
	print("R32_MOTION_STAGE ", stage)
	for frame in range(count):
		var mix_value: float = float(frame) / float(maxi(count - 1, 1))
		if stage.begins_with("water_"):
			var candidate: Dictionary = report.water_candidates[stage.trim_prefix("water_")]
			var place: Dictionary = candidate.position.duplicate()
			place.height = candidate.sample.water_level
			var point: Vector3 = Space.resolve(self, place)
			var basis: Basis = Space.frame(self, point)
			camera.global_position = point + basis * Vector3(0, 4, 12)
			camera.look_at(point, basis.y)
		else:
			_pose(mix_value if stage == "distance_out" else 1.0 - mix_value if stage == "distance_return" else 0.0)
		var started: int = Time.get_ticks_usec()
		await tree.process_frame
		await RenderingServer.frame_post_draw
		var drawn: int = Time.get_ticks_usec()
		var image: Image = tree.root.get_texture().get_image()
		image.save_png(output.path_join("frame_%04d.png" % capture_index))
		var now: int = Time.get_ticks_usec()
		var residents: Array = []
		for member: Dictionary in tribe.village().members:
			var tool: Node3D = tribe.actors[member.id].get_node_or_null("TribeWorkTool")
			var working: bool = float(member.work) > 0.0 and tool != null and tool.visible
			saw_work = saw_work or working
			residents.append({"id": member.id, "order": member.order, "stage": member.stage, "work": member.work,
				"cargo": member.cargo, "visible_tool": tool != null and tool.visible,
				"tool_angle": tool.rotation.z if tool != null else 0.0,
				"tool_remaining": tool._remaining if tool != null else 0.0})
		report.frames.append({"index": capture_index, "stage": stage, "clock": state.campaign.data.elapsed_seconds,
			"draw_wait_us": drawn - started, "readback_png_us": now - drawn, "residents": residents,
			"wood_stock": tribe.village().stock.wood, "water_time": tree.current_scene.terrain.presentation.time,
			"wind_time": Assets._motion_clock, "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
			"weather": tree.get_first_node_in_group("campaign_weather").snapshot(),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		capture_index += 1

func _tools() -> Dictionary:
	var result: Dictionary = {}
	for identity: String in tribe.actors:
		var tool: Node3D = tribe.actors[identity].get_node_or_null("TribeWorkTool")
		if tool != null: result[identity] = [tool._remaining, tool._clock, tool.rotation.z, tool.visible]
	return result

func _water_candidates() -> Dictionary:
	var result: Dictionary = {}
	var origin: Vector3 = tribe.anchor()
	for distance_value: float in [20.0, 40.0, 80.0, 160.0, 320.0]:
		for angle in range(24):
			var bearing: float = float(angle) * TAU / 24.0
			var point: Vector3 = Space.offset(self, origin, Vector3(cos(bearing), 0, sin(bearing)) * distance_value)
			var sampled: Dictionary = Space.sample(self, point)
			if sampled.water and not result.has(sampled.get("water_kind", "ocean")):
				result[sampled.get("water_kind", "ocean")] = {"position": Space.encode(self, point), "sample": sampled,
					"distance_m": distance_value, "ground_ready": Space.ground_ready(self, point)}
	return result

func _until(predicate: Callable, milliseconds: int) -> void:
	var started: int = Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - started < milliseconds: await tree.process_frame

func _check(ok: bool, label: String, details: Variant = null) -> void:
	report.checks.append({"passed": ok, "label": label, "details": details})
	_expect(ok, label + ": " + str(details) if not ok else label)

func _finish_motion() -> void:
	tree.paused = false
	RenderingServer.render_loop_enabled = true
	report.passed = failures.is_empty()
	report.failures = failures
	report.mode = config.mode
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("R32_MOTION_RESULT ", JSON.stringify({"passed": report.passed, "frames": report.frames.size(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if failures.is_empty() else 1)
