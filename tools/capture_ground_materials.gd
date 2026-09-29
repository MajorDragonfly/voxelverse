extends SceneTree
## Fixed, native before/after views of real spherical terrain meshes and palette.
const Cube = preload("res://world/space/cube_sphere.gd")
const System = preload("res://world/space/celestial_system.gd")
const Surface = preload("res://world/surface/living_planet_surface.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const Materials = preload("res://world/surface/visuals/living_surface_materials.gd")
const CATEGORIES: Array[String] = ["grassland", "desert", "rocky_highlands", "snow", "coast"]
const VIEWS: Array[String] = ["near", "middle", "far"]

class TerrainFixture extends Node:
	var surface: RefCounted
	var origin: Array
	var land_material := ShaderMaterial.new()
	var _fade_land := ShaderMaterial.new()
	var _old_land := ShaderMaterial.new()
	var ocean_material := ShaderMaterial.new()
	var _fade_water := ShaderMaterial.new()
	var _old_water := ShaderMaterial.new()

var _failures: Array[String] = []
var _report: Dictionary = {"samples": []}
var _scene: Node3D
var _camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected output directory and baseline shader path.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	var output: String = args[0]
	var baseline_code: String = FileAccess.get_file_as_string(args[1])
	if baseline_code.is_empty():
		push_error("Baseline shader is missing.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var graphical: bool = DisplayServer.get_name() != "headless"
	if graphical:
		root.size = Vector2i(960, 540)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_report["renderer"] = RenderingServer.get_current_rendering_method() if graphical else "headless-probe"
	_report["adapter"] = RenderingServer.get_video_adapter_name() if graphical else ""
	_report["godot"] = Engine.get_version_info().string
	var body: Dictionary = System.new(false, true).bodies["m1b:terra"].duplicate(true)
	body.surface_generation = Surface.GENERATION
	var surface := Surface.new(body)
	var choices: Dictionary = _locations(surface)
	_report["locations"] = choices
	if choices.size() < 4:
		_failures.append("Not enough actual biome surfaces for the fixed review.")
	if graphical:
		for category: String in CATEGORIES:
			if not choices.has(category): continue
			await _render(surface, choices[category], category, baseline_code, output)
	_report["passed"] = _failures.is_empty() and (not graphical or _report.samples.size() >= 12)
	_report["failures"] = _failures
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	file.close()
	for failure: String in _failures: push_error(failure)
	print("GROUND_MATERIAL_REVIEW ", JSON.stringify(_report))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if _report.passed else 1)

func _locations(surface: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for face in range(6):
		for y in range(-9, 10):
			for x in range(-9, 10):
				var u: float = x * 0.1
				var v: float = y * 0.1
				var d: Array = Cube.direction(face, u, v)
				var height: float = surface.height_precise(d)
				var biome: String = surface.fields(d, height).biome
				if biome in CATEGORIES and not result.has(biome):
					result[biome] = {"face": face, "u": u, "v": v, "height": height}
				if result.size() == CATEGORIES.size(): return result
	return result

func _render(surface: RefCounted, location: Dictionary, category: String, baseline_code: String, output: String) -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.25
	_scene.add_child(light)
	var centre: Array = surface.point(location.face, location.u, location.v)
	var up: Vector3 = Cube.vector(Cube.direction(location.face, location.u, location.v))
	var frame: Basis = Cube.frame(up)
	light.look_at_from_position(up * 30.0 + frame.x * 30.0 + frame.z * 20.0, Vector3.ZERO, up)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.49, 0.65, 0.73)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.74, 0.80, 0.84)
	world.environment.ambient_light_energy = 0.8
	_scene.add_child(world)
	_camera = Camera3D.new()
	_camera.fov = 64.0
	_camera.far = 500.0
	_scene.add_child(_camera)
	_camera.make_current()
	var fixture := TerrainFixture.new()
	fixture.surface = surface
	fixture.origin = centre
	_scene.add_child(fixture)
	var materials := Materials.new()
	materials.setup(fixture)
	var candidate: ShaderMaterial = fixture.land_material
	var baseline := candidate.duplicate() as ShaderMaterial
	var old_shader := Shader.new()
	old_shader.code = baseline_code
	baseline.shader = old_shader
	for name: String in ["lod_phase", "origin_phase", "origin_up", "origin_height", "body_radius", "soil_color", "rock_color"]:
		baseline.set_shader_parameter(name, candidate.get_shader_parameter(name))
	var meshes: Array[MeshInstance3D] = []
	var layout := Layout.new(surface.body.radius)
	var level: int = layout.max_level - 1
	var cells: int = 1 << level
	var cx: int = clampi(floori((float(location.u) + 1.0) * 0.5 * cells), 2, cells - 3)
	var cy: int = clampi(floori((float(location.v) + 1.0) * 0.5 * cells), 2, cells - 3)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var tile: Dictionary = Layout.patch(location.face, level, cx + x, cy + y)
			tile.mask = 0
			tile.anchor = surface.point(tile.face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
			var node := MeshInstance3D.new()
			node.mesh = Patch.upload_surface(Patch.build_arrays(tile, surface).land_arrays)
			node.position = Cube.local_position(tile.anchor, centre)
			node.material_override = baseline
			_scene.add_child(node)
			meshes.append(node)
	for view: String in VIEWS:
		var distance: float = 12.0 if view == "near" else (45.0 if view == "middle" else 110.0)
		_camera.look_at_from_position(up * (distance * 0.42) + frame.z * distance, up * 0.5, up)
		var before: Image = await _capture(output, category + "_" + view + "_before")
		var before_calls: int = RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		for node: MeshInstance3D in meshes: node.material_override = candidate
		var after: Image = await _capture(output, category + "_" + view + "_after")
		var after_calls: int = RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		if before_calls != after_calls: _failures.append("Material changed draw calls: " + category + "/" + view)
		if before != null and after != null:
			_report.samples.append({"category": category, "view": view, "distance_m": distance,
				"mean_rgb_change": _difference(before, after), "draw_calls": after_calls,
				"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
				"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())})
		for node: MeshInstance3D in meshes: node.material_override = baseline
	_scene.queue_free()
	await process_frame

func _capture(output: String, label: String) -> Image:
	for frame in range(5): await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(label + ".png")) != OK:
		_failures.append("Missing native screenshot: " + label)
		return null
	return image

func _difference(before: Image, after: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for y in range(80, 500, 8):
		for x in range(40, 920, 8):
			var a: Color = before.get_pixel(x, y)
			var b: Color = after.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			count += 3
	return total / maxf(count, 1)
