extends SceneTree
## Native material diagnosis. Uses production meshes, palettes and atmosphere;
## controlled placements isolate material changes from streaming and weather.
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const Materials = preload("res://world/surface/visuals/living_surface_materials.gd")
var report: Dictionary = {"seed": 15838, "samples": [], "probes": [], "failures": []}
var scene: Node3D
var holder: Node3D
var camera: Camera3D
var atmosphere: Node3D
var output: String
var shaders: Dictionary = {}
var bindings: Array[Dictionary] = []
var view_frame := Basis.IDENTITY

class TerrainFixture extends Node:
	var surface: RefCounted
	var origin: Array
	var land_material := ShaderMaterial.new()
	var _fade_land := ShaderMaterial.new()
	var _old_land := ShaderMaterial.new()
	var ocean_material := ShaderMaterial.new()
	var _fade_water := ShaderMaterial.new()
	var _old_water := ShaderMaterial.new()

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		push_error("Requires a native renderer, output directory and baseline shader directory")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 540)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	report.shader_sha256 = {}
	for version: String in ["before", "after"]:
		var include_path: String = args[1].path_join("planet_surface_detail.gdshaderinc") if version == "before" else "res://assets/catalog/planet_surface_detail.gdshaderinc"
		var detail: String = FileAccess.get_file_as_string(include_path)
		if detail.is_empty():
			push_error("Missing material include: " + include_path)
			quit(1)
			return
		report.shader_sha256[version + "/include"] = detail.sha256_text()
		for kind: String in ["planet_foliage", "surface_scenery"]:
			var shader_path: String = args[1].path_join(kind + ".gdshader") if version == "before" else ("res://assets/catalog/" if kind == "planet_foliage" else "res://world/surface/visuals/") + kind + ".gdshader"
			var shader := Shader.new()
			var code: String = FileAccess.get_file_as_string(shader_path)
			if code.is_empty():
				push_error("Missing material shader: " + shader_path)
				quit(1)
				return
			report.shader_sha256[version + "/" + kind] = code.sha256_text()
			shader.code = code.replace('#include "res://assets/catalog/planet_surface_detail.gdshaderinc"', detail)
			shaders[version + "/" + kind] = shader
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.godot = Engine.get_version_info().string
	report.resolution = [960, 540]
	report.scope = "Controlled production asset/terrain fixture; 16 render samples per side/view, frozen campaign-clock atmosphere. Real campaign horizon/streaming is a separate review. Software times are not target-PC FPS."
	for category: String in ["forest", "stone", "ground"]:
		await _scene(category)
		for phase: String in ["day", "night"]:
			_set_time(0.0 if phase == "day" else 720.0)
			for index in range(3):
				var distance_m: float = [12.0, 45.0, 110.0][index]
				for binding: Dictionary in bindings:
					binding.visual.multimesh.mesh = Assets.get_mesh(binding.family, index)
					binding.shader_kind = "surface_scenery" if index == 2 else "planet_foliage"
					binding.material.set_shader_parameter("detailed_patch", false)
				camera.look_at_from_position(view_frame * Vector3(distance_m * 0.12, distance_m * 0.28 + 1.0, distance_m), view_frame * Vector3(0, 1.0, 0), view_frame.y)
				var sample := {"category": category, "phase": phase, "distance_m": distance_m,
					"camera_transform": var_to_str(camera.transform), "light": _light_record()}
				for version: String in ["before", "after"]:
					_apply(version)
					sample[version] = await _capture("%s_%s_%dm_%s" % [category, phase, int(distance_m), version])
				if sample.before.draw_calls != sample.after.draw_calls or sample.before.primitives != sample.after.primitives:
					report.failures.append("Material changed rendering geometry/counts: " + category + "/" + phase)
				report.samples.append(sample)
		await _teardown()
	await _scene("forest")
	_make_probe_planes()
	_set_time(120.0)
	camera.look_at_from_position(Vector3(0, 2.0, 9), Vector3(0, 2.0, 0))
	# Unshaded comparison isolates the pattern from shadow-cascade movement.
	atmosphere.environment.background_mode = Environment.BG_COLOR
	atmosphere.environment.background_color = Color("15202b")
	atmosphere.environment.fog_enabled = false
	atmosphere.environment.volumetric_fog_enabled = false
	atmosphere.environment.ssao_enabled = false
	atmosphere.environment.glow_enabled = false
	for version: String in ["before", "after"]:
		for kind: String in ["planet_foliage", "surface_scenery"]:
			var shader := Shader.new()
			shader.code = shaders[version + "/" + kind].code.replace("render_mode diffuse_burley;", "render_mode unshaded;")
			shaders[version + "/probe_" + kind] = shader
		_apply(version, true)
		await _capture("rebase_" + version + "_original", 0)
		var original: Image = root.get_texture().get_image()
		var shift := Vector3(83.25, -77.5, 129.125)
		holder.position = -shift
		camera.position -= shift
		await _capture("rebase_" + version + "_shifted", 0)
		var shifted: Image = root.get_texture().get_image()
		report.probes.append({"version": version, "mean_rgb_rebase_change": _difference(original, shifted), "shift_m": var_to_str(shift)})
		holder.position = Vector3.ZERO
		camera.position += shift
		# Same near mesh and palette on both shaders: isolate the material handoff.
		_apply(version, true)
		await _capture("handoff_" + version + "_opaque", 0)
		var opaque: Image = root.get_texture().get_image()
		for binding: Dictionary in bindings:
			binding.material.shader = shaders[version + "/probe_surface_scenery"]
			binding.material.set_shader_parameter("detailed_patch", true)
			binding.material.set_shader_parameter("patch_coverage", 1.0)
		await _capture("handoff_" + version + "_transition", 0)
		report.probes.append({"version": version, "mean_rgb_handoff_change": _difference(opaque, root.get_texture().get_image())})
	await _teardown()
	for probe: Dictionary in report.probes:
		if probe.has("mean_rgb_handoff_change") and probe.mean_rgb_handoff_change > 0.0001:
			report.failures.append("Shader handoff changed the material on identical geometry: " + probe.version)
		if probe.has("mean_rgb_rebase_change"):
			if probe.version == "after" and probe.mean_rgb_rebase_change > 0.0001:
				report.failures.append("Candidate material moved during the controlled origin rebase")
			if probe.version == "before" and probe.mean_rgb_rebase_change < 0.001:
				report.failures.append("Baseline did not reproduce the origin-dependent pattern")
	report.passed = report.failures.is_empty()
	FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("INT30_MATERIAL_REVIEW ", JSON.stringify(report))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.passed else 1)

func _scene(category: String) -> void:
	view_frame = Basis.IDENTITY
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	holder = Node3D.new()
	scene.add_child(holder)
	camera = Camera3D.new()
	camera.fov = 64
	camera.far = 1000
	scene.add_child(camera)
	camera.make_current()
	atmosphere = Atmosphere.new()
	scene.add_child(atmosphere)
	atmosphere.set_process(false)
	var profile: Dictionary = Profile.create(15838)
	atmosphere.configure(profile, 15838, Vector3.UP, func() -> Dictionary: return {"up": Vector3.UP, "seconds": 120.0, "height": 20.0, "moisture": 0.2, "weather": {"cloud_cover": 0.2, "atmosphere_present": true}})
	if category == "ground":
		_ground()
		return
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(300, 0.2, 300)
	ground.mesh = box
	ground.position.y = -0.1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("637357")
	material.roughness = 0.97
	ground.material_override = material
	holder.add_child(ground)
	var families: Array = ["ancient_oak_v2", "tall_pine_v2", "dense_bush_v2"] if category == "forest" else ["layered_rock_v2"]
	for family: String in families:
		var species: Dictionary = Flora.create_species_variant(profile, "forest", family, 0)
		var visual := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = Assets.get_mesh(family, 0)
		multi.instance_count = 9
		for index in range(9):
			var x: float = (index % 3 - 1) * 6.0
			var z: float = -(index / 3) * 10.0
			if family == "tall_pine_v2": x += 3.0; z -= 4.0
			if family == "dense_bush_v2": x += 1.5; z += 2.0
			multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, float(index) * 0.4), Vector3(x, 0, z)))
			multi.set_instance_custom_data(index, Color(0.94 + float(index % 3) * 0.03, 0, 0, 1))
		visual.multimesh = multi
		var shader_material := ShaderMaterial.new()
		shader_material.set_shader_parameter("planet_palette", Slots.create_texture(species.palette))
		shader_material.set_shader_parameter("wind_strength", 0.0)
		shader_material.set_shader_parameter("nearby_ownership", ImageTexture.create_from_image(Image.create(2048, 1, false, Image.FORMAT_R8)))
		visual.material_override = shader_material
		holder.add_child(visual)
		bindings.append({"material": shader_material, "visual": visual, "family": family, "shader_kind": "planet_foliage"})

func _ground() -> void:
	var campaign: Dictionary = Context.create({"id": "material-fixture", "seed": 15838})
	var surface: RefCounted = Factory.create(Context.descriptor(campaign))
	var spawn: Dictionary = campaign.surface_context.spawn
	var centre: Array = Cube.cartesian(spawn, surface.body.radius)
	centre = surface.point(spawn.face, spawn.u, spawn.v)
	var frame: Basis = Cube.frame(Cube.vector(Cube.direction(spawn.face, spawn.u, spawn.v)))
	view_frame = frame
	var profile: Dictionary = Profile.create(15838)
	atmosphere.configure(profile, 15838, frame.y, func() -> Dictionary: return {"up": frame.y, "seconds": 120.0, "height": 20.0, "moisture": 0.2, "weather": {"cloud_cover": 0.2, "atmosphere_present": true}})
	var fixture := TerrainFixture.new()
	fixture.surface = surface
	fixture.origin = centre
	scene.add_child(fixture)
	Materials.new().setup(fixture)
	var layout := Layout.new(surface.body.radius)
	var level: int = layout.max_level - 2
	var side: int = 1 << level
	var cx: int = floori((spawn.u + 1.0) * 0.5 * side)
	var cy: int = floori((spawn.v + 1.0) * 0.5 * side)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var tile: Dictionary = Layout.patch(spawn.face, level, cx + x, cy + y)
			tile.mask = 0
			tile.anchor = surface.point(tile.face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
			var mesh := MeshInstance3D.new()
			mesh.mesh = Patch.upload_surface(Patch.build_arrays(tile, surface).land_arrays)
			mesh.position = Cube.local_position(tile.anchor, centre)
			mesh.material_override = fixture.land_material
			holder.add_child(mesh)

func _make_probe_planes() -> void:
	# Exact, axis-aligned geometry avoids attributing float-rounding changes at
	# complex voxel silhouettes to the material. Real assets are captured above.
	bindings.clear()
	for child: Node in holder.get_children(): child.free()
	var profile: Dictionary = Profile.create(15838)
	for index in range(3):
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 3)
		var arrays: Array = quad.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var slot: int = [1, 5, 13][index]
		uv.fill(Vector2((float(slot) + 0.5) / 32.0, 0.5))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = Vector3((index - 1) * 2, 2, 0)
		var material := ShaderMaterial.new()
		material.set_shader_parameter("planet_palette", Slots.create_texture(profile.material_slots))
		material.set_shader_parameter("wind_strength", 0.0)
		visual.material_override = material
		holder.add_child(visual)
		bindings.append({"material": material, "shader_kind": "planet_foliage"})

func _set_time(seconds: float) -> void:
	var sample: Dictionary = atmosphere.source.call()
	sample.seconds = seconds
	atmosphere.source = func() -> Dictionary: return sample
	atmosphere.update_view(0.0, true)

func _light_record() -> Dictionary:
	return {"seconds": atmosphere._elapsed, "sun_direction": var_to_str(atmosphere._sun_direction), "sun_energy": atmosphere.sun.light_energy, "ambient_energy": atmosphere.environment.ambient_light_energy, "tonemap_white": atmosphere.environment.tonemap_white, "cloud_cover": 0.2}

func _apply(version: String, probe: bool = false) -> void:
	for binding: Dictionary in bindings:
		binding.material.shader = shaders[version + ("/probe_" if probe else "/") + binding.shader_kind]

func _capture(label: String, measured_frames: int = 16) -> Dictionary:
	for index in range(6): await RenderingServer.frame_post_draw
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var frames: Array[float] = []
	var rid: RID = root.get_viewport_rid()
	for index in range(measured_frames):
		var started: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec() - started) / 1000.0)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	var image: Image = root.get_texture().get_image()
	if image.save_png(output.path_join(label + ".png")) != OK: report.failures.append("Missing capture " + label)
	return {"frame_ms": _distribution(frames), "render_cpu_ms": _distribution(cpu), "render_gpu_ms": _distribution(gpu), "draw_calls": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME), "primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}

func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	return {"count": values.size(), "p50": values[values.size() / 2], "p95": values[mini(values.size() - 1, int(values.size() * 0.95))]}

func _difference(a: Image, b: Image) -> float:
	var sum: float = 0.0
	var count: int = 0
	for y in range(40, 500, 2):
		for x in range(80, 880, 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			sum += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			count += 3
	return sum / maxf(count, 1)

func _teardown() -> void:
	bindings.clear()
	current_scene = null
	scene.queue_free()
	await process_frame
