extends "res://tools/review_r32_18_storm.gd"
## Shared fixed-camera consumer of the unchanged R32-18 campaign review.
## Freezing physics alone leaves the native SpringArm and other player
## processes active. Freeze the complete observer subtree at the first image
## of each loaded scene; the weather source, clock, particles and all original
## assertions continue through the inherited probe.
var _frozen_camera: Camera3D
var _reload_watch: bool = false
var _last_trace: int = 0
var _capture_costs: Array[Dictionary] = []
var _png_tasks: Array[Dictionary] = []
var _native_frames: int = 0

func _initialize() -> void:
	RenderingServer.frame_post_draw.connect(func() -> void: _native_frames += 1)
	super._initialize()

func _draw_capture() -> void:
	# One full native viewport frame, with an observed draw signal and joined
	# render work. The screenshot requires no additional X11 presentation copy.
	RenderingServer.render_loop_enabled = false
	var before: int = _native_frames
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	_expect(_native_frames > before, "Native viewport capture did not produce frame_post_draw.")

func _settle_capture() -> void:
	# Preserve the same two gameplay/view updates. The full native world draw
	# follows immediately; these unrecorded updates need no 3D presentation.
	var previous: bool = root.disable_3d
	root.disable_3d = true
	await super._settle_capture()
	root.disable_3d = previous

func _warm_capture() -> void:
	# Keep all four native canvas/layout updates. The complete player/camera
	# pose is declared by _capture; unrecorded 3D warmup draws add no evidence.
	var previous: bool = root.disable_3d
	root.disable_3d = true
	await super._warm_capture()
	root.disable_3d = previous

func _store_capture(capture_image: Image, name: String) -> void:
	# Encode an immutable native readback while the next native frame runs.
	# At most two images are outstanding; every original write assertion is
	# evaluated on the main thread after its actual worker result is joined.
	_drain_png(false)
	var result := {"code": ERR_CANT_CREATE}
	var destination: String = folder.path_join(name)
	var task: int = WorkerThreadPool.add_task(func() -> void:
		result.code = capture_image.save_png(destination), false, "R32 native PNG")
	_png_tasks.append({"id":task, "name":name, "result":result})

func _drain_png(all_tasks: bool) -> void:
	while not _png_tasks.is_empty():
		var first: Dictionary = _png_tasks[0]
		if not all_tasks and _png_tasks.size() < 2 and not WorkerThreadPool.is_task_completed(first.id): break
		WorkerThreadPool.wait_for_task_completion(first.id)
		_expect(first.result.code == OK, "Capture failed: " + str(first.name))
		_png_tasks.pop_front()

func _finish() -> void:
	_drain_png(true)
	await super._finish()

func _capture(name: String, clock: float, label: String, locale: String = "") -> void:
	var started: int = Time.get_ticks_usec()
	if not is_instance_valid(_frozen_camera) or camera != _frozen_camera:
		current_scene.player.process_mode = Node.PROCESS_MODE_DISABLED
		# One declared comparison pose per loaded scene, derived from the same
		# saved body/spawn, heading and pitch in both renderers. Native startup
		# timing must not choose a different spring-arm distance for the fixture.
		var spawn: Dictionary = body.surface_context.spawn
		var up: Vector3 = Cube.vector(Cube.direction(spawn.face, spawn.u, spawn.v))
		var frame: Basis = Cube.frame(up)
		var pivot := Transform3D(Basis(Vector3.RIGHT, -0.10), Vector3(0, 1.7, 0))
		var arm := Transform3D(Basis.IDENTITY, Vector3(0, 0, 7.2))
		var point: Vector3 = Cube.local_position(Cube.cartesian(spawn,
			current_scene.terrain.surface.body.radius), current_scene.terrain.origin)
		camera.top_level = true
		camera.global_transform = Transform3D(frame, point) * pivot * arm
		initial_pose = camera.global_transform
		_frozen_camera = camera
	await super._capture(name, clock, label, locale)
	_capture_costs.append({"file": name, "clock": clock,
		"capture_wall_usec": Time.get_ticks_usec() - started})
	FileAccess.open(folder.path_join("partial-rows.json"), FileAccess.WRITE).store_string(JSON.stringify(rows))
	FileAccess.open(folder.path_join("capture-costs.json"), FileAccess.WRITE).store_string(JSON.stringify(_capture_costs))
	if name == "storm-before-reload.png" and not _reload_watch:
		_reload_watch = true
		process_frame.connect(_watch_reload)
		_watch_reload()

func _watch_reload() -> void:
	if Time.get_ticks_msec() - _last_trace < 1000: return
	_last_trace = Time.get_ticks_msec()
	var saves: Node = root.get_node("SaveGameService")
	var trace := {"ticks_msec": _last_trace, "scene": current_scene.scene_file_path if is_instance_valid(current_scene) else "",
		"loading": flow.loading, "paused": paused, "save_error": saves.last_error,
		"session_active": saves.session_active, "clock": state.campaign.data.elapsed_seconds,
		"startup": flow.startup_diagnostics()}
	FileAccess.open(folder.path_join("reload-lifecycle.json"), FileAccess.WRITE).store_string(JSON.stringify(trace))
