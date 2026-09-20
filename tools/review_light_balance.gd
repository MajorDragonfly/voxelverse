extends SceneTree
## PT17-02: fixed material/lighting fixture, not a procedural campaign screenshot.
## The before controller is read verbatim from the recorded Git basis by Python.
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Ground = preload("res://world/surface/visuals/living_ground.gdshader")
const Water = preload("res://world/surface/visuals/living_water.gdshader")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var scene: Node3D
var air: Node3D
var camera: Camera3D
var output: String
var sample := {"up": Vector3.UP, "height": 30.0, "moisture": 0.45, "seconds": 750.0,
	"weather": {"cloud_cover": 0.16, "precipitation": 0.0, "visibility_m": 18000.0}}
var captures: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args := OS.get_cmdline_user_args()
	output = args[args.find("--capture") + 1]
	var controller := "res://world/visuals/atmosphere/campaign_atmosphere.gd"
	if "--controller" in args: controller = args[args.find("--controller") + 1]
	if DisplayServer.get_name() == "headless":
		push_error("Light review requires a graphical renderer.")
		quit(1)
		return
	for i in range(4): await process_frame
	var settings := root.get_node("DisplaySettings")
	settings.display_mode = 0
	settings.resolution = Vector2i(960, 540)
	settings._apply_settings(false)
	scene = Node3D.new()
	root.add_child(scene)
	air = load(controller).new()
	scene.add_child(air)
	air.configure(Profile.create(15838), 15838, Vector3.UP, func(): return sample)
	air.set_process(false)
	air.set_quality(1)
	camera = Camera3D.new()
	camera.far = 12000.0
	scene.add_child(camera)
	camera.make_current()
	_fixture()
	for i in range(4): await process_frame
	# Freeze creature pose and water/sky time for comparable pixels.
	for child in scene.get_children():
		if child != air and child != camera: child.process_mode = Node.PROCESS_MODE_DISABLED
	var noon := Vector3(0.35, 0.82, 0.44).normalized()
	await _capture("slope-noon", Vector3(15, 10, 21), Vector3(8, 3, -12), noon)
	await _capture("forest-noon", Vector3(-15, 4, 13), Vector3(-16, 3, -15), noon)
	await _capture("horizon-noon", Vector3(0, 8, 20), Vector3(0, 20, -250), noon)
	await _capture("water-noon", Vector3(0, 7, 12), Vector3(0, 0, -7), noon)
	air.set_quality(2)
	await _capture("slope-cinematic", Vector3(15, 10, 21), Vector3(8, 3, -12), noon)
	air.set_quality(1)
	sample.weather.cloud_cover = 0.96
	sample.weather.precipitation = 0.65
	await _capture("slope-overcast", Vector3(15, 10, 21), Vector3(8, 3, -12), noon)
	sample.weather.cloud_cover = 0.16
	sample.weather.precipitation = 0.0
	await _capture("slope-sunset", Vector3(15, 10, 21), Vector3(8, 3, -12), Vector3(-0.5, 0.09, -0.85).normalized())
	await _capture("forest-night", Vector3(-15, 4, 13), Vector3(-16, 3, -15), Vector3(-0.5, -0.8, -0.3).normalized())
	var report := {"seed": 15838, "clock_seconds": sample.seconds, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string,
		"scope": "Fixed voxel fixture with production ground/water shaders, tree asset and creature. No target-PC/FPS acceptance.", "captures": captures}
	var file := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	scene.free()
	print("LIGHT_BALANCE_RENDER_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)

func _fixture() -> void:
	_box(Vector3(0, -1, -35), Vector3(120, 2, 150), Color("628449"), true)
	# Pale rock and snow terraces retain the real voxel shader's grain/strata.
	for step in range(6):
		_box(Vector3(12, float(step) * 1.5, -float(step) * 4.0 - 8.0), Vector3(18, 3, 14), Color("e9ece5"), true)
	for x in range(3):
		for z in range(3):
			var tree: Node3D = load("res://assets/packs/temperate_forest_v1/environment/benchmark_v2/ancient_oak_v2_near.glb").instantiate()
			scene.add_child(tree)
			tree.position = Vector3(-10.0 - x * 9.0, 0, -8.0 - z * 12.0)
	for i in range(5):
		_box(Vector3(float(i) * 150.0 - 300.0, 20.0, -600.0 - i * 170.0), Vector3(180, 100 + i * 35, 150), Color("849185"), true)
	# A pool uses the same opaque depth-aware water shader as the campaign.
	var plane := PlaneMesh.new()
	plane.size = Vector2(11, 15)
	var arrays := plane.get_mesh_arrays()
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in range(uv.size()): uv[i] = Vector2(0.2 + uv[i].y * 7.0, 0)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water := MeshInstance3D.new()
	water.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = Water
	material.set_shader_parameter("surface_time", 750.0)
	water.material_override = material
	scene.add_child(water)
	water.position = Vector3(0, 0.12, -9)
	for at: Vector3 in [Vector3(7, 0, 4), Vector3(-14, 0, -5)]:
		var creature := Preview.new()
		scene.add_child(creature)
		creature.set_editor_state(Assembly.create_default(), -1, -1, false)
		creature.position = at
		if creature.has_meta("ground_y"): creature.position.y = -float(creature.get_meta("ground_y"))

func _box(at: Vector3, size: Vector3, color: Color, ground: bool) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = Ground
	instance.material_override = material
	scene.add_child(instance)
	instance.position = at

func _capture(id: String, at: Vector3, target: Vector3, sunlight: Vector3) -> void:
	camera.position = at
	camera.look_at(target)
	air._sun_direction = sunlight
	air.sun.basis = Basis.looking_at(-sunlight, Vector3.UP)
	air.sky_material.set_shader_parameter("sun_direction", sunlight)
	air.update_view(0.0, true)
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(picture.save_png(output.path_join(id + ".png")) == OK)
	var clipped: int = 0
	var dark: int = 0
	var total: int = 0
	var luminance: float = 0.0
	# Lower half excludes most sky; report descriptive metrics, not FPS claims.
	for y in range(picture.get_height() / 2, picture.get_height(), 2):
		for x in range(0, picture.get_width(), 2):
			var pixel := picture.get_pixel(x, y)
			var value: float = pixel.get_luminance()
			if minf(pixel.r, minf(pixel.g, pixel.b)) > 0.98: clipped += 1
			if value < 0.015: dark += 1
			luminance += value
			total += 1
	captures.append({"id": id, "camera": str(camera.transform), "sun_direction": str(sunlight),
		"preset": air.quality, "sun_energy": air.sun.light_energy, "ambient_energy": air.environment.ambient_light_energy,
		"white": air.environment.tonemap_white, "exposure": air.environment.tonemap_exposure,
		"clipped_fraction": float(clipped) / total, "black_fraction": float(dark) / total,
		"mean_luminance": luminance / total, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
