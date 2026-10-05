extends SceneTree
## Actual campaign ground first; shader-isolation fixtures explicitly separate.
const Cube = preload("res://world/space/cube_sphere.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Ground = preload("res://world/surface/visuals/living_ground.gdshader")
const Preferences = preload("res://core/graphics_preferences.gd")
const CATEGORIES: Array[String] = ["grassland", "desert", "rocky_highlands", "snow", "coast"]
# Measured native Compatibility value for this fixed Seed-15838/clock-0 save.
# CampaignAtmosphere uses different renderer caps (0.72/1.1); freeze this
# comparison input only, without changing the shared production light owner.
const COMPARISON_SUN_ENERGY: float = 0.875736713409424
var output: String
var shaders: Dictionary = {}
var report: Dictionary = {"seed": 15838, "samples": [], "motion": [], "probes": [], "failures": []}
var scene: Node3D
var camera: Camera3D
var ground_materials: Array[ShaderMaterial] = []
var camera_reference: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() not in [3, 4, 5] or DisplayServer.get_name() == "headless":
		push_error("Requires native renderer, output, baseline shader and campaign/probe mode")
		quit(1)
		return
	output = args[0]
	shaders.before = Shader.new()
	shaders.before.code = FileAccess.get_file_as_string(args[1])
	shaders.after = Ground
	root.size = Vector2i(960, 540)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.godot = Engine.get_version_info().string
	report.resolution = [960, 540]
	report.mode = args[2]
	report.category = args[3] if args.size() >= 4 else "all"
	if args.size() == 5:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[4]))
		if not parsed is Dictionary or parsed.get("renderer", "") != "gl_compatibility":
			push_error("Camera reference must be an original Compatibility capture")
			quit(1)
			return
		camera_reference = parsed
		report.camera_reference = args[4]
	if args[2] == "campaign":
		await _campaign(report.category)
	else:
		await _probe()
	report.passed = report.failures.is_empty()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("R32_08_GROUND_REVIEW ", JSON.stringify(report))
	if is_instance_valid(scene):
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		if args[2] == "campaign":
			scene.player.set_process(false)
			scene.player.set_physics_process(false)
	paused = false
	RenderingServer.render_loop_enabled = true
	current_scene = null
	if is_instance_valid(scene): scene.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)


func _campaign(category_filter: String) -> void:
	var saves: Node = root.get_node("SaveGameService")
	var flow: Node = root.get_node("SessionFlow")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("R32-08 fixed ground review", 15838, Cube.MODE)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	RenderingServer.render_loop_enabled = false
	flow.load_game(path)
	var deadline: int = Time.get_ticks_msec() + 180000
	while flow.loading and Time.get_ticks_msec() < deadline: await process_frame
	if flow.loading or current_scene.scene_file_path != Context.SCENE:
		report.failures.append("Regular spherical campaign failed to load")
		return
	scene = current_scene
	scene.player.set_process(false)
	scene.player.set_physics_process(false)
	paused = true
	ground_materials.assign(scene.terrain.presentation.ground)
	for material: ShaderMaterial in ground_materials:
		if material.shader != Ground: report.failures.append("Campaign ground did not bind the active shader")
	report.body = scene.terrain.surface.body.duplicate(true)
	report.surface_generation = scene.terrain.surface.body.get("surface_generation")
	report.preset = scene._atmosphere.graphics_values.duplicate(true)
	report.scope = "Regular Seed-15838 campaign loaded via SessionFlow. Ground-only native views isolate shader on live streamed terrain. Other scenery/actors/UI hidden; simulation paused. Forced initial relocation setup is unmeasured. Supplementary biome views align the existing campaign solar frame locally at clock 0; they are not travel/time acceptance. 16 measured paused force_draw calls per version/view, with render-loop disabled; no gameplay-frame/FPS or target-PC claim."
	report.measurement_mode = "paused_force_draw"
	report.sun_contract = "Fixed Seed-15838 clock-0 Compatibility energy in both renderers; native campaign energy also recorded. Review-only control, not shared-light acceptance."
	# Isolate actual terrain and its existing atmosphere, preserving all meshes,
	# collider objects, material palette bindings and normal LOD budgets.
	for child: Node in scene.get_children():
		if child != scene.terrain and child != scene._atmosphere:
			_hide(child)
	camera = Camera3D.new()
	camera.fov = 64.0
	camera.near = 0.2
	camera.far = 30000.0
	scene.add_child(camera)
	camera.make_current()
	var state: Node = root.get_node("GameState")
	state.campaign.data.elapsed_seconds = 0.0
	var spawn: Dictionary = state.get_current_body_record().surface_context.spawn.duplicate(true)
	var locations: Dictionary = _locations(scene.terrain.surface)
	report.locations = locations.duplicate(true)
	locations["campaign_spawn"] = spawn
	if locations.size() != 6: report.failures.append("Not all five actual campaign biomes found")
	for category: String in ["campaign_spawn"] + CATEGORIES:
		if category_filter != "all" and category != category_filter: continue
		if not locations.has(category): continue
		var place: Dictionary = locations[category].duplicate(true)
		place.height = scene.terrain.surface.sample(place).height + 1.1
		RenderingServer.render_loop_enabled = false
		print("R32_08_STAGE relocate ", category)
		scene.player.place(place)
		camera.position = Vector3.ZERO
		var frame: Basis = scene.adapter.frame_at(place)
		var sample: Dictionary = scene._atmosphere.campaign_sample()
		sample.seconds = 0.0
		if category != "campaign_spawn":
			scene._atmosphere.configure(scene.terrain.surface.terrain, 15838, frame.y, func() -> Dictionary: return sample)
		else:
			scene._atmosphere.source = func() -> Dictionary: return sample
		scene._atmosphere.update_view(0.0, true)
		var native_sun_energy: float = scene._atmosphere.sun.light_energy
		scene._atmosphere.sun.light_energy = COMPARISON_SUN_ENERGY
		scene.terrain.presentation.advance(0.0)
		var geometry: String = _geometry_digest()
		RenderingServer.render_loop_enabled = true
		for distance_m: float in [12.0, 45.0, 110.0]:
			print("R32_08_STAGE view ", category, " ", distance_m)
			camera.look_at_from_position(frame.y * (distance_m * 0.42) + frame.z * distance_m, frame.y * -0.6, frame.y)
			if not camera_reference.is_empty():
				var found: bool = false
				for reference: Dictionary in camera_reference.samples:
					if reference.category == category and reference.distance_m == distance_m:
						var exact: Variant = str_to_var(reference.camera_transform)
						if exact is Transform3D:
							camera.transform = exact
							found = true
				if not found:
					report.failures.append("Missing exact reference camera: " + category)
					return
			var result: Dictionary = {"category": category, "distance_m": distance_m, "place": place,
				"camera_transform": var_to_str(camera.transform), "origin": scene.terrain.origin.duplicate(),
				"clock_seconds": sample.seconds, "weather": sample.get("weather", {}),
				"sun_direction": var_to_str(scene._atmosphere._sun_direction),
				"sun_energy": scene._atmosphere.sun.light_energy, "native_campaign_sun_energy": native_sun_energy,
				"sun_color": var_to_str(scene._atmosphere.sun.light_color), "tonemap_white": scene._atmosphere.environment.tonemap_white,
				"ambient_energy": scene._atmosphere.environment.ambient_light_energy, "geometry_sha256": geometry}
			for version: String in ["before", "after"]:
				_apply(version)
				result[version] = await _capture("%s-%dm-%s" % [category, int(distance_m), version])
			if result.before.draw_calls != result.after.draw_calls or result.before.primitives != result.after.primitives:
				report.failures.append("Shader changed visible geometry/counts: " + category)
			if _geometry_digest() != geometry: report.failures.append("Terrain/collision changed during comparison")
			report.samples.append(result)
			_checkpoint()
			if category == "coast" and distance_m == 12.0:
				# Same-code shader clone isolates draw-order/coplanar sensitivity
				# from this material correction at the actual shoreline.
				var original_image: Image = root.get_texture().get_image()
				var clone := Shader.new()
				clone.code = Ground.code
				for material: ShaderMaterial in ground_materials: material.shader = clone
				await _capture("coast-identical-code-control", 0)
				report.probes.append({"kind": "coast_identical_code_control", "mean_rgb_change": _difference(original_image, root.get_texture().get_image())})
		if category in ["campaign_spawn", "rocky_highlands", "snow"]:
			var original: Transform3D = camera.transform
			camera.look_at_from_position(frame.y * 1.7 + frame.z * 12.0, frame.y * -0.6, frame.y)
			var motion_start: Transform3D = camera.transform
			for version: String in ["before", "after"]:
				_apply(version)
				for index in range(24):
					camera.transform = motion_start.translated(frame.x * float(index) * 0.035)
					report.motion.append({"category": category, "version": version, "index": index,
						"camera_transform": var_to_str(camera.transform),
						"sample": await _capture("motion-%s-%s-%02d" % [category, version, index], 0)})
			camera.transform = original
			_checkpoint()
		# Same canonical terrain and camera after a non-periodic origin change.
		if category == "campaign_spawn":
			camera.look_at_from_position(frame.y * 5.04 + frame.z * 12.0, frame.y * -0.6, frame.y)
			for version: String in ["before", "after"]:
				_apply(version)
				var old_origin: Array = scene.terrain.origin.duplicate()
				var old_camera: Transform3D = camera.transform
				await _capture("rebase-" + version + "-original", 0)
				var original_image: Image = root.get_texture().get_image()
				var shift := Vector3(83.25, -77.5, 129.125)
				scene.terrain.rebase([old_origin[0] + shift.x, old_origin[1] + shift.y, old_origin[2] + shift.z])
				camera.position -= shift
				await _capture("rebase-" + version + "-shifted", 0)
				report.probes.append({"version": version, "kind": "campaign_origin_shift",
					"mean_rgb_change": _difference(original_image, root.get_texture().get_image())})
				scene.terrain.rebase(old_origin)
				camera.transform = old_camera
			_checkpoint()


func _checkpoint() -> void:
	# Preserve partial observations on a timed-out software renderer. They
	# remain explicitly negative until the complete selected case has exited.
	report.passed = false
	FileAccess.open(output.path_join("partial-capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")


func _locations(surface: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for face in range(6):
		for y in range(-9, 10):
			for x in range(-9, 10):
				var u: float = x * 0.1
				var v: float = y * 0.1
				var direction: Array = Cube.direction(face, u, v)
				var height: float = surface.height_precise(direction)
				var biome: String = surface.fields(direction, height).biome
				if biome in CATEGORIES and not result.has(biome):
					var address: Dictionary = Cube.address(str(surface.body.id), face, u, v)
					address.height = height
					result[biome] = address
				if result.size() == CATEGORIES.size(): return result
	return result


func _probe() -> void:
	report.scope = "Separate vertical rock shader fixture: actual strata expression isolated from lighting, grain and geometry. Fixed camera; phase swept by 0.0005m per frame to expose subpixel stripe-edge coverage. Not a campaign or target-PC acceptance."
	scene = Node3D.new()
	root.add_child(scene)
	camera = Camera3D.new()
	camera.fov = 35.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(0, 0, 2.0), Vector3.ZERO)
	camera.make_current()
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 1.4)
	mesh.mesh = quad
	var material := ShaderMaterial.new()
	material.set_shader_parameter("body_radius", 6371000.0)
	material.set_shader_parameter("rock_color", Color("646b69"))
	material.set_shader_parameter("origin_up", Vector3.UP)
	mesh.material_override = material
	scene.add_child(mesh)
	ground_materials.assign([material])
	var debug: Dictionary = {}
	for version: String in ["before", "after"]:
		var code: String = shaders[version].code
		code = code.replace("render_mode cull_back, diffuse_lambert;", "render_mode unshaded;")
		var lines: PackedStringArray = code.split("\n")
		for index in range(lines.size()):
			if lines[index].strip_edges().begins_with("ALBEDO ="):
				lines[index] = "\tALBEDO = vec3(0.5 + strata * 7.0);"
		var shader := Shader.new()
		shader.code = "\n".join(lines)
		debug[version] = shader
	for version: String in ["before", "after"]:
		material.shader = debug[version]
		for index in range(24):
			material.set_shader_parameter("origin_height", 96.0 + float(index) * 0.0005)
			report.probes.append({"version": version, "kind": "isolated_strata", "index": index,
				"height": 96.0 + float(index) * 0.0005,
				"sample": await _capture("strata-%s-%02d" % [version, index], 0)})


func _hide(node: Node) -> void:
	if node is CanvasLayer: node.visible = false
	if node is GeometryInstance3D: node.hide()
	for child: Node in node.get_children(): _hide(child)


func _apply(version: String) -> void:
	for material: ShaderMaterial in ground_materials: material.shader = shaders[version]


func _capture(label: String, frames: int = 16) -> Dictionary:
	RenderingServer.render_loop_enabled = false
	await process_frame
	for index in range(6 if frames > 0 else 1): RenderingServer.force_draw(false)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var elapsed: Array[float] = []
	var rid: RID = root.get_viewport_rid()
	for index in range(frames):
		var started: int = Time.get_ticks_usec()
		RenderingServer.force_draw(false)
		elapsed.append((Time.get_ticks_usec() - started) / 1000.0)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(label + ".png")) != OK:
		report.failures.append("Missing native image: " + label)
	return {"frame_ms": _distribution(elapsed), "render_cpu_ms": _distribution(cpu), "render_gpu_ms": _distribution(gpu),
		"draw_calls": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}


func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	return {"count": values.size(), "p50": values[values.size() / 2], "p95": values[mini(values.size() - 1, int(values.size() * 0.95))], "p99": values[-1], "max": values[-1]}


func _geometry_digest() -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var keys: Array = scene.terrain.leaves.keys()
	keys.sort()
	for key: String in keys:
		var tile: Dictionary = scene.terrain.leaves[key]
		digest.update(key.to_utf8_buffer())
		if tile.mesh != null: digest.update(var_to_bytes(tile.mesh.surface_get_arrays(0)))
		if tile.has("shape"): digest.update(var_to_bytes(tile.shape.get_faces()))
	return digest.finish().hex_encode()


func _difference(a: Image, b: Image) -> float:
	var sum: float = 0.0
	var count: int = 0
	for y in range(80, 500, 2):
		for x in range(80, 880, 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			sum += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			count += 3
	return sum / maxf(count, 1)
