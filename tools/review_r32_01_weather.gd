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
