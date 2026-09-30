extends RefCounted
## INT30-08 native fixture: production sky, light, terrain/water shaders and
## tree asset, with recorded campaign seconds. Never overrides sun direction.
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Ground = preload("res://world/surface/visuals/living_ground.gdshader")
const Water = preload("res://world/surface/visuals/living_water.gdshader")
const Forecast = preload("res://world/weather/forecast_panel.gd")
var scene: Node3D
var air: Node3D
var panel: CanvasLayer
var sample: Dictionary
var material: ShaderMaterial
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var tree: SceneTree
var folder: String

class PlayerStub extends Node:
	var inspection_mode_enabled: bool = false

func run(owner: SceneTree, output: String) -> Array[String]:
	tree = owner
	folder = output
	if DisplayServer.get_name() == "headless":
		return ["Weather/water captures require a real graphical renderer."]
	var settings: Node = tree.root.get_node("DisplaySettings")
	settings.display_mode = 0
	settings.resolution = Vector2i(960, 540)
	settings.vsync_enabled = false
	settings._apply_settings(false)
	tree.root.size = Vector2i(960, 540)
	tree.root.get_node("LocaleManager")._apply("de")
	scene = Node3D.new()
	tree.root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(6, 13, 30)
	camera.look_at(Vector3(0, 4, -16))
	camera.make_current()
	var player := PlayerStub.new()
	scene.add_child(player)
	panel = Forecast.new()
	scene.add_child(panel)
	air = Atmosphere.new()
	scene.add_child(air)
	sample = {"up": Vector3.UP, "height": 0.0, "moisture": 0.65, "seconds": 0.0}
	air.configure(Profile.create(15838), 15838, Vector3.UP, func(): return sample)
	air.set_quality(1)
	air.set_process(false)
	_fixture()
	# UTC-like campaign clock starts at 15:00. These four explicit times,
	# rather than private direction writes, produce the named phases.
	for phase: Dictionary in [{"id": "dawn", "seconds": 900.0},
			{"id": "noon", "seconds": 1260.0}, {"id": "dusk", "seconds": 180.0},
			{"id": "night", "seconds": 540.0}]:
		_set_time(float(phase.seconds), player)
		await _capture("day-" + str(phase.id))
		var elevation: float = Vector3.UP.dot(air._sun_direction)
		_expect(air.sun.global_basis.z.dot(air._sun_direction) > 0.9999,
			"Rendered sun/light disagree at " + str(phase.id))
		_expect(absf(panel._day_bar.value - Atmosphere.day_progress(sample.seconds) * 100.0) < 0.001,
			"Rendered day UI/sky clock disagree at " + str(phase.id))
		if phase.id == "noon": _expect(elevation > 0.8, "Noon fixture is not daylight.")
		if phase.id == "night": _expect(elevation < -0.8 and air.sun.light_energy == 0.0, "Night fixture is not dark.")
	# Controlled cloud pair: explicitly diagnostic cover, identical clock and
	# geometry. It is not evidence of a naturally scheduled storm front.
	_set_time(1260.0, player)
	var normal: Dictionary = sample.weather.duplicate(true)
	for condition: String in ["clear", "overcast"]:
		sample.weather = Regional.preview(normal, condition)
		air.update_view(0.0, true)
		panel.present(sample.weather, [], player)
		await _capture("cover-" + condition)
	sample.weather = normal
	air.update_view(0.0, true)
	panel.present(normal, Regional.forecast("int30-review", 15838, sample.seconds,
		Cube.address("int30-review", 2, 0.2, 0.3), 6371000.0), player)
	# Ground shadow pair exposes the actual light/shadow change to review.
	air.sun.shadow_enabled = false
	var unshadowed: Image = await _capture("shadow-off")
	air.sun.shadow_enabled = true
	var shadowed: Image = await _capture("shadow-on")
	_expect(unshadowed.get_data() != shadowed.get_data(), "Native fixture has no visible sun shadows.")
	# Sea on the left, raised-lake mask on the right; identical pixels/time.
	panel.present({}, [], null)
	material.set_shader_parameter("surface_time", 1.8)
	material.set_shader_parameter("current_strength", 0.0)
	await _capture("water-current-off")
	material.set_shader_parameter("current_strength", 1.0)
	await _capture("water-current-on")
	material.set_shader_parameter("surface_time", 3.8)
	var later: Image = await _capture("water-later")
	tree.paused = true
	var sun_before: Vector3 = air._sun_direction
	var frozen: Image = await _capture("water-paused")
	_expect(later.get_data() == frozen.get_data(), "Fixed-clock paused native scene changed pixels.")
	_expect(air._sun_direction == sun_before, "Paused native sunlight moved.")
	tree.paused = false
	# Adjacent canonical times test both the solar and cloud wrap, without
	# synthesising a second animation clock.
	_set_time(7199.999, player)
	var direction_before: Vector3 = air._sun_direction
	var cloud_before: Vector3 = air.sky_material.get_shader_parameter("cloud_offset")
	_set_time(7200.001, player)
	_expect(direction_before.distance_to(air._sun_direction) < 0.00002,
		"Sun jumped at campaign day wrap.")
	_expect(cloud_before.distance_to(air.sky_material.get_shader_parameter("cloud_offset")) < 0.00001,
		"Clouds jumped at campaign animation wrap.")
	panel.present({}, [], null)
	var costs: Dictionary = {}
	for strength: float in [0.0, 1.0]:
		material.set_shader_parameter("current_strength", strength)
		costs[str(strength)] = await _measure()
	var report := {"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"seed": 15838, "size": [960, 540], "captures": rows, "current_frame_costs": costs,
		"failures": failures, "passed": failures.is_empty(),
		"scope": "Fixed production-material fixture. Sea/raised-lake masks are synthetic. Cover pair is diagnostic. Frame timings are software-runner evidence, not target-PC FPS. No normal storm exists in climate revision 1."}
	var file := FileAccess.open(folder.path_join("weather-water.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	scene.free()
	await tree.process_frame
	return failures

func _set_time(seconds: float, player: Node) -> void:
	sample.seconds = seconds
	sample.weather = Regional.sample("int30-review", 15838, seconds,
		Cube.address("int30-review", 2, 0.2, 0.3), 6371000.0)
	material.set_shader_parameter("surface_time", seconds)
	air.update_view(0.0, true)
	panel.present(sample.weather, Regional.forecast("int30-review", 15838, seconds,
		Cube.address("int30-review", 2, 0.2, 0.3), 6371000.0), player)

func _fixture() -> void:
	_box(Vector3(0, -2, -30), Vector3(95, 3, 130), Color("69854d"))
	_box(Vector3(0, 3, -14), Vector3(2, 9, 2), Color("d4d6ca"))
	for index in range(4):
		_box(Vector3(15 + index * 4, 1 + index, -30 - index * 5), Vector3(5, 4 + index * 2, 7), Color("a4aaa5"))
	var oak: Node3D = load("res://assets/packs/temperate_forest_v1/environment/benchmark_v2/ancient_oak_v2_near.glb").instantiate()
	scene.add_child(oak)
	oak.position = Vector3(-17, -0.5, -25)
	oak.process_mode = Node.PROCESS_MODE_DISABLED
	material = ShaderMaterial.new()
	material.shader = Water
	for lake in range(2):
		var plane := PlaneMesh.new()
		plane.size = Vector2(15, 20)
		var arrays: Array = plane.get_mesh_arrays()
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for index in range(uv.size()): uv[index] = Vector2(0.2 + uv[index].y * 5.0, float(lake))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.position = Vector3(-10 if lake == 0 else 10, 0, -3)
		scene.add_child(instance)

func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays: Array = box.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var ground := ShaderMaterial.new()
	ground.shader = Ground
	instance.material_override = ground
	instance.position = at
	scene.add_child(instance)

func _capture(id: String) -> Image:
	for frame in range(16): await tree.process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = tree.root.get_texture().get_image()
	_expect(picture.save_png(folder.path_join(id + ".png")) == OK, "Cannot save capture " + id)
	rows.append({"id": id, "campaign_seconds": sample.seconds, "day_fraction": Atmosphere.day_progress(sample.seconds),
		"sun_direction": [air._sun_direction.x, air._sun_direction.y, air._sun_direction.z],
		"sun_energy": air.sun.light_energy, "cloud_cover": sample.weather.get("cloud_cover"),
		"preview": sample.weather.get("preview", false), "shadows": air.sun.shadow_enabled,
		"water_time": material.get_shader_parameter("surface_time"),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	return picture

func _measure() -> Dictionary:
	var durations: Array[int] = []
	for frame in range(40):
		var start: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		if frame >= 4: durations.append(Time.get_ticks_usec() - start)
	durations.sort()
	return {"frames": durations.size(), "p50_ms": durations[18] / 1000.0,
		"p95_ms": durations[34] / 1000.0, "max_ms": durations.back() / 1000.0}

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
