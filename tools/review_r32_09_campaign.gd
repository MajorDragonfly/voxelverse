extends SceneTree
## Public spherical campaign, canonical placements, paired shader substitution.
const Cube = preload("res://world/space/cube_sphere.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Stats = preload("res://tools/performance_stats.gd")
var scene: Node3D
var camera: Camera3D
var output: String
var shaders: Dictionary = {}
var bindings: Array[Dictionary] = []
var report: Dictionary = {"schema": 1, "seed": 15838, "samples": [], "motion": [], "failures": []}
var frozen_weather: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		push_error("Native renderer, output and baseline shader folder required")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 540)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	report.merge({"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(), "resolution": [960, 540],
		"scope": "Actual public campaign and generated assets; player/streaming follows settled distance viewpoints. Paired camera-only motion keeps geometry fixed to isolate grain. Wind disabled. Not physical walking or target-PC acceptance.", "shader_sha256": {}})
	for version: String in ["before", "after"]:
		var detail: String = FileAccess.get_file_as_string(args[1].path_join("planet_surface_detail.gdshaderinc") if version == "before" else "res://assets/catalog/planet_surface_detail.gdshaderinc")
		for kind: String in ["planet_foliage", "surface_scenery"]:
			var path: String = args[1].path_join(kind + ".gdshader") if version == "before" else ("res://assets/catalog/" if kind == "planet_foliage" else "res://world/surface/visuals/") + kind + ".gdshader"
			var code: String = FileAccess.get_file_as_string(path)
			if code.is_empty() or detail.is_empty():
				push_error("Missing shader source")
				quit(1)
				return
			report.shader_sha256[version + "/" + kind] = code.sha256_text()
			report.shader_sha256[version + "/include"] = detail.sha256_text()
			var shader := Shader.new()
			shader.code = code.replace('#include "res://assets/catalog/planet_surface_detail.gdshaderinc"', detail)
			shaders[version + "/" + kind] = shader
	var saves: Node = root.get_node("SaveGameService")
	var flow: Node = root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("R32-09 material review", 15838, Cube.MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	var deadline: int = Time.get_ticks_msec() + 180000
	while flow.loading and Time.get_ticks_msec() < deadline: await process_frame
	if flow.loading or current_scene.scene_file_path != Context.SCENE:
		push_error("Actual campaign load failed")
		quit(1)
		return
	scene = current_scene
	scene.player.set_physics_process(false)
	camera = Camera3D.new()
	camera.fov = 64
	camera.far = 30000
	scene.add_child(camera)
	camera.make_current()
	await _settle()
	paused = true
	# Derive the normal weather once at the canonical spawn/time, independent
	# of startup duration and subsequent camera moves. No diagnostic storm.
	root.get_node("GameState").campaign.data.elapsed_seconds = 120.0
	var weather: Node = scene.get_tree().get_first_node_in_group(&"campaign_weather")
	weather._process(0.0)
	frozen_weather = weather.snapshot()
	report.frozen_weather = frozen_weather
	scene._atmosphere.source = _atmosphere_sample
	_collect(scene)
	report.campaign_scene = scene.scene_file_path
	report.body = scene.terrain.surface.body
	report.preset = scene._atmosphere.graphics_values
	var targets: Dictionary = _targets()
	if targets.size() != 2: report.failures.append("Canonical oak/rock targets missing")
	for family: String in targets:
		var target: Dictionary = targets[family]
		var address: Dictionary = target.address
		var frame: Basis = target.frame
		for phase: String in ["day", "night"]:
			root.get_node("GameState").campaign.data.elapsed_seconds = 120.0 if phase == "day" else 720.0
			for distance_m: float in [6.0, 30.0, 110.0]:
				RenderingServer.render_loop_enabled = false
				paused = false
				var observer: Dictionary = scene.adapter.offset(address, frame.z * distance_m, 1.1)
				scene.adapter.place(scene.player, observer)
				if scene.player.position.length() > 64:
					scene.terrain.rebase(Cube.cartesian(observer, scene.terrain.surface.body.radius))
				scene.terrain.stream_at(scene.adapter.up_at(observer))
				scene.flora._refresh()
				await _settle()
				paused = true
				root.get_node("GameState").campaign.data.elapsed_seconds = 120.0 if phase == "day" else 720.0
				bindings.clear()
				_collect(scene)
				var point: Vector3 = scene.adapter.to_local(address)
				camera.look_at_from_position(point + frame.z * distance_m + frame.y * 2.5, point + frame.y * 2.0, frame.y)
				scene._atmosphere.update_view(0.0, true)
				RenderingServer.render_loop_enabled = true
				var sample := {"family": family, "phase": phase, "distance_m": distance_m,
					"camera": var_to_str(camera.global_transform), "fov": camera.fov, "origin": scene.terrain.origin.duplicate(),
					"target": address, "light": _light(), "geometry_sha256": _geometry_digest(),
					"near_patches": scene.flora.patches.size(), "far_scenery": scene.scenery.diagnostics()}
				for version: String in ["before", "after"]:
					_apply(version)
					sample[version] = await _capture("%s-%s-%dm-%s" % [family, phase, int(distance_m), version])
				if sample.geometry_sha256 != _geometry_digest(): report.failures.append("Shader substitution changed source geometry")
				if sample.before.draw_calls != sample.after.draw_calls or sample.before.primitives != sample.after.primitives:
					report.failures.append("Shader substitution changed visible geometry")
				report.samples.append(sample)
				if phase == "day" and distance_m == 6.0:
					# Presentation-only isolation; restore every setting before the
					# next comparable view. R32-06 still owns lighting corrections.
					var environment: Environment = scene._atmosphere.environment
					var ao: bool = environment.ssao_enabled
					var shadows: bool = scene._atmosphere.sun.shadow_enabled
					environment.ssao_enabled = false
					await _image_capture(family + "-day-ao-off")
					scene._atmosphere.sun.shadow_enabled = false
					await _image_capture(family + "-day-ao-and-shadow-off")
					environment.ssao_enabled = ao
					scene._atmosphere.sun.shadow_enabled = shadows
				_checkpoint()
		# Repeat exactly the same 32 moving camera poses, without moving actors.
		root.get_node("GameState").campaign.data.elapsed_seconds = 120.0
		for version: String in ["before", "after"]:
			_apply(version)
			for index in range(32):
				var point: Vector3 = scene.adapter.to_local(address)
				var progress: float = float(index) / 31.0
				var distance_m: float = 6.0 + sin(progress * PI) * 104.0
				camera.look_at_from_position(point + frame.z * distance_m + frame.x * (sin(progress * TAU * 4.0) * 0.02) + frame.y * 2.5, point + frame.y * 2.0, frame.y)
				scene._atmosphere.update_view(0.0, true)
				await process_frame
				await RenderingServer.frame_post_draw
				var filename: String = "%s-motion-%s-%02d.png" % [family, version, index]
				if root.get_texture().get_image().save_png(output.path_join(filename)) != OK: report.failures.append("Motion capture failed")
				report.motion.append({"family": family, "version": version, "index": index, "camera": var_to_str(camera.global_transform), "light": _light(), "file": filename})
		# Actual terrain/adapter origin event; leave generated placements intact.
		_apply("after")
		var geometry: String = _geometry_digest()
		var original: Array = scene.terrain.origin.duplicate()
		await _capture(family + "-rebase-original")
		var before: Image = root.get_texture().get_image()
		scene.terrain.rebase([original[0] + 64, original[1] - 32, original[2] + 128])
		camera.position -= Vector3(64, -32, 128)
		await _capture(family + "-rebase-shifted")
		var shifted: Image = root.get_texture().get_image()
		report.samples.append({"family": family, "rebase_mean_rgb": _difference(before, shifted), "original_origin": original, "shifted_origin": scene.terrain.origin.duplicate(), "geometry_sha256": _geometry_digest()})
		scene.terrain.rebase(original)
		camera.position += Vector3(64, -32, 128)
		if geometry != _geometry_digest(): report.failures.append("Rebase changed mesh/instance/collider payload")
	report.complete = true
	report.passed = report.failures.is_empty()
	_checkpoint()
	print("R32_09_CAMPAIGN ", JSON.stringify({"passed": report.passed, "failures": report.failures, "samples": report.samples.size(), "motion": report.motion.size()}))
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.queue_free()
	scene = null
	paused = false
	for cleanup in range(4): await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)

func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var flora: Node = scene.flora
		if flora.patches.size() == flora.wanted.size() and flora._task < 0 and flora._publication.is_empty() and scene.scenery._task < 0 and scene.scenery._staging.is_empty():
			return
	report.failures.append("Normal scenery publication exceeded 90 s")

func _collect(node: Node) -> void:
	if node is CanvasLayer: node.visible = false
	if node is GeometryInstance3D:
		var material: Material = node.material_override
		if material is ShaderMaterial and material.shader != null:
			var kind: String = ""
			if material.shader.resource_path.ends_with("planet_foliage.gdshader"): kind = "planet_foliage"
			if material.shader.resource_path.ends_with("surface_scenery.gdshader"): kind = "surface_scenery"
			for shader_kind: String in ["planet_foliage", "surface_scenery"]:
				for version: String in ["before", "after"]:
					if material.shader == shaders[version + "/" + shader_kind]: kind = shader_kind
			if not kind.is_empty() and not bindings.any(func(b: Dictionary) -> bool: return b.material == material):
				bindings.append({"material": material, "kind": kind})
	for child in node.get_children(): _collect(child)

func _apply(version: String) -> void:
	for binding: Dictionary in bindings:
		binding.material.shader = shaders[version + "/" + binding.kind]
		binding.material.set_shader_parameter("wind_strength", 0.0)

func _targets() -> Dictionary:
	var result: Dictionary = {}
	for data: Dictionary in scene.flora.patches.values():
		for visual: MultiMeshInstance3D in data.node.get_children():
			var family: String = visual.get_meta("asset")
			if family not in ["ancient_oak_v2", "layered_rock_v2"]: continue
			if result.has(family): continue
			var transform: Transform3D = visual.multimesh.get_instance_transform(0)
			var point: Array = Cube.global_position(data.node.position + transform.origin, scene.terrain.origin)
			result[family] = {"address": Cube.from_cartesian(scene.terrain.surface.body.id, point, scene.terrain.surface.body.radius), "frame": transform.basis.orthonormalized()}
	return result

func _capture(label: String) -> Dictionary:
	for warm in range(3): await RenderingServer.frame_post_draw
	var wall: Array = []
	var cpu: Array = []
	var gpu: Array = []
	var rid: RID = root.get_viewport_rid()
	for i in range(8):
		var started: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		wall.append((Time.get_ticks_usec() - started) / 1000.0)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	if root.get_texture().get_image().save_png(output.path_join(label + ".png")) != OK: report.failures.append("Capture failed: " + label)
	return {"file": label + ".png", "wall_ms": Stats.distribution(wall), "cpu_ms": Stats.distribution(cpu), "gpu_ms": Stats.distribution(gpu), "raw_wall_ms": wall, "raw_cpu_ms": cpu, "raw_gpu_ms": gpu,
		"draw_calls": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}

func _light() -> Dictionary:
	return {"clock": root.get_node("GameState").campaign.data.elapsed_seconds, "sun_direction": var_to_str(scene._atmosphere._sun_direction), "energy": scene._atmosphere.sun.light_energy, "ambient": scene._atmosphere.environment.ambient_light_energy, "weather": frozen_weather}

func _atmosphere_sample() -> Dictionary:
	var sample: Dictionary = scene._atmosphere.campaign_sample()
	sample.weather = frozen_weather
	return sample

func _image_capture(label: String) -> void:
	for warm in range(3): await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(label + ".png")) != OK: report.failures.append("Capture failed: " + label)

func _geometry_digest() -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for data: Dictionary in scene.flora.patches.values():
		digest.update(var_to_bytes(data.node.get_shape_owners()))
		for visual: MultiMeshInstance3D in data.node.get_children():
			digest.update(var_to_bytes(visual.multimesh.buffer))
			digest.update(var_to_bytes(visual.multimesh.mesh.surface_get_arrays(0)))
	return digest.finish().hex_encode()

func _checkpoint() -> void:
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")

func _difference(a: Image, b: Image) -> float:
	var sum: float = 0.0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			sum += absf(ca.r-cb.r) + absf(ca.g-cb.g) + absf(ca.b-cb.b)
	return sum / float(a.get_width() * a.get_height() * 3)
