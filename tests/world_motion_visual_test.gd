extends SceneTree
## Native captures of actual imported plants and the shared voxel work tool.
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const Props = preload("res://world/tribe/village_visuals.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 540)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 3.4, 11)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	scene.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("668ba8")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b5c9d4")
	scene.add_child(environment)
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(20, 0.15, 12)
	ground.mesh = ground_mesh
	ground.position.y = -0.12
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("63816a")
	ground.material_override = ground_material
	scene.add_child(ground)
	var profile: Dictionary = Profile.create(15838)
	for family: String in ["dense_bush_v2", "fern_cluster_v2", "flower_cluster_v2"]:
		var species: Dictionary = Flora.create_species_variant(profile, "forest", family, 0)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = Assets.get_mesh(family, 0)
		multi.instance_count = 5
		for index in range(5):
			var x: float = -5.0 + float(index) * 2.4
			multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, 0, -1.5 if family == "dense_bush_v2" else 1.2)))
			multi.set_instance_custom_data(index, Color(1, float(index) / 5.0, 0, 1))
		var foliage := MultiMeshInstance3D.new()
		foliage.multimesh = multi
		foliage.material_override = Assets.get_material(profile, species)
		scene.add_child(foliage)
	var wind := {"wind_mps": 5.0, "wind_bearing": 0.4, "atmosphere_present": true}
	Assets.set_weather_motion(wind, 0.0, true)
	var output: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		output = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(output)
		var first: PackedByteArray = await _capture(output, "wind-0")
		Assets.set_weather_motion(wind, 1.2, true)
		var second: PackedByteArray = await _capture(output, "wind-1")
		_expect(first != second, "Imported plants did not move between two weather-clock positions.")
		Assets.set_weather_motion(wind, 1.2, true)
		var frozen: PackedByteArray = await _capture(output, "wind-paused")
		_expect(second == frozen, "A fixed campaign clock did not freeze the scene.")
		var still_frames: Dictionary = await _profile_frames(wind, false)
		var moving_frames: Dictionary = await _profile_frames(wind, true)
		print(JSON.stringify({"test": "world_motion_frame_sample", "still": still_frames, "moving": moving_frames,
			"scope": "36 software-rendered fixture frames per mode; target-PC route remains open"}))
	var actor := Node3D.new()
	scene.add_child(actor)
	actor.position = Vector3(0, 0, 3.0)
	var props := Props.new()
	scene.add_child(props)
	props.show_work(actor, "wood")
	var tool: Node3D = actor.get_node_or_null("TribeWorkTool")
	_expect(tool != null and tool.visible, "Near worker has no visible work tool.")
	props.show_work(actor, "stone")
	_expect(actor.get_child_count() == 1 and tool.visible, "Repeated work created extra tools.")
	paused = true
	var remaining: float = tool._remaining
	for frame in range(3): await process_frame
	_expect(is_equal_approx(tool._remaining, remaining), "Paused work animation kept advancing.")
	paused = false
	scene.queue_free()
	await process_frame
	print(JSON.stringify({"test": "world_motion_visual", "passed": failures.is_empty(), "failures": failures, "native_capture": not output.is_empty()}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _capture(folder: String, name: String) -> PackedByteArray:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png(folder.path_join(name + ".png")) == OK, "Could not save " + name)
	return image.get_data()

func _profile_frames(weather: Dictionary, enabled: bool) -> Dictionary:
	var samples: Array[int] = []
	for frame in range(40):
		Assets.set_weather_motion(weather, float(frame) / 60.0, enabled)
		var started: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		if frame >= 4: samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	return {"p50_ms": float(samples[18]) / 1000.0, "p95_ms": float(samples[34]) / 1000.0,
		"max_ms": float(samples.back()) / 1000.0}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
