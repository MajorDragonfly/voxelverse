extends SceneTree

# Offline review tool. Never loaded by gameplay or included in release packages.
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const FAMILIES: Array[String] = ["ancient_oak_v2", "tall_pine_v2", "dense_bush_v2",
	"fern_cluster_v2", "flower_cluster_v2", "layered_rock_v2", "grass_tuft_v2"]

var _config: Dictionary
var _report: Dictionary
var _scene: Node3D
var _camera: Camera3D
var _samples: Array[Dictionary] = []
var _failures: Array[String] = []
var _comparison_images: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Expected an absolute capture configuration JSON path.")
		quit(1)
		return
	_config = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	if DisplayServer.get_name() == "headless":
		push_error("Visual acceptance requires a real rendering driver, not --headless.")
		quit(1)
		return
	root.get_node("SaveGameService").set("autosave_enabled", false)
	root.get_node("GameState").call("start_world_with_seed", int(_config["seed"]))
	await process_frame
	await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(int(_config["width"]), int(_config["height"]))
	root.content_scale_size = root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var adapter: String = RenderingServer.get_video_adapter_name()
	var software: bool = RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU
	for token: String in ["llvmpipe", "lavapipe", "softpipe", "software", "swiftshader"]:
		software = software or token in adapter.to_lower()
	_report = {"seed": _config["seed"], "case": _config["case"], "godot": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": adapter,
		"adapter_api": RenderingServer.get_video_adapter_api_version(), "software_renderer": software,
		"resolution": [root.size.x, root.size.y], "fast_setup": _config.get("fast_setup", false),
		"target_hardware_acceptance": false, "samples": _samples}
	if bool(_config.get("fast_setup", false)):
		RenderingServer.render_loop_enabled = false
	match str(_config["case"]):
		"world":
			await _world()
		"assets":
			await _assets()
		"cluster":
			await _cluster()
		"creature":
			await _creature()
		_:
			_failures.append("Unknown review case.")
	RenderingServer.render_loop_enabled = true
	if is_instance_valid(_scene):
		_scene.queue_free()
		current_scene = null
	await process_frame
	Assets.finish_pending_loads()
	_report["passed"] = _failures.is_empty() and not _samples.is_empty()
	_report["failures"] = _failures
	var file := FileAccess.open(str(_config["output"]).path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write capture report.")
		quit(1)
		return
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	file.close()
	for failure: String in _failures:
		push_error(failure)
	print("ENVIRONMENT_CAPTURE ", JSON.stringify(_report))
	quit(0 if bool(_report["passed"]) else 1)


func _fixture() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	current_scene = _scene
	var environment: Node = load("res://world/visuals/planet_visual_environment.tscn").instantiate()
	_scene.add_child(environment)
	_camera = Camera3D.new()
	_camera.fov = 48.0
	_camera.far = 500.0
	_scene.add_child(_camera)
	_camera.make_current()


func _assets() -> void:
	_fixture()
	var profile: Dictionary = root.get_node("WorldGenerator").call("get_planet_profile")
	for family: String in FAMILIES:
		var group := Node3D.new()
		_scene.add_child(group)
		var species: Dictionary = Flora.create_species_variant(profile, "forest", family, 0)
		var near_mesh: Mesh = Assets.get_mesh(family, 0, int(species["geometry_variant"]))
		var bounds: AABB = near_mesh.get_aabb()
		var spacing: float = maxf(bounds.size.x, bounds.size.z) * 1.25
		for tier in range(3):
			var node := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = Assets.get_mesh(family, tier, int(species["geometry_variant"]))
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3((tier - 1) * spacing, 0, 0)))
			mm.set_instance_custom_data(0, Color(1, 0, 0, 1))
			node.multimesh = mm
			node.material_override = Assets.get_material(profile, species)
			group.add_child(node)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(spacing * 5, spacing * 3)
		ground.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.27, 0.29, 0.28)
		material.roughness = 1.0
		ground.material_override = material
		ground.position.y = -0.035
		group.add_child(ground)
		var target := Vector3(0, bounds.size.y * 0.45, 0)
		var half_fov: float = tan(deg_to_rad(_camera.fov * 0.5))
		var aspect: float = float(root.size.x) / float(root.size.y)
		var distance: float = maxf((spacing * 2.0 + bounds.size.x) / (2.0 * half_fov * aspect), bounds.size.y / (2.0 * half_fov)) * 1.25
		_camera.position = target + Vector3(0, distance * 0.24, distance)
		_camera.look_at(target)
		await _capture(family, {"asset_id": family, "geometry_variant": species["geometry_variant"],
			"tiers_left_to_right": ["Near", "Mid", "Far"]})
		group.queue_free()
		await process_frame


func _world() -> void:
	change_scene_to_file("res://main/main.tscn")
	var started: int = Time.get_ticks_usec()
	var setup_frames: Array[float] = []
	var ready: bool = false
	for frame in range(100000):
		if Time.get_ticks_usec() - started > 120_000_000:
			break
		var previous: int = Time.get_ticks_usec()
		await process_frame
		setup_frames.append((Time.get_ticks_usec() - previous) / 1000.0)
		if current_scene == null:
			continue
		_scene = current_scene
		var manager: Node = _scene.get_node("WorldManager")
		if not bool(manager.get("world_initialized")):
			continue
		_scene.get_node("Player").set_physics_process(false)
		if int(manager.call("get_pending_chunk_count")) != 0:
			continue
		ready = true
		for chunk: Node in manager.get("loaded_chunks").values():
			if not bool(chunk.get_node("ProceduralEcosystemV6").get("generation_complete")) or chunk.get_node("ProceduralEcosystemV6").is_processing():
				ready = false
				break
		if ready:
			break
	if not ready:
		_failures.append("World streaming did not finish for capture.")
		return
	_report["setup_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	_report["setup_frame_ms"] = _distribution(setup_frames)
	var player: Node3D = _scene.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.hide()
	_hide_ui(root)
	_camera = Camera3D.new()
	_scene.add_child(_camera)
	_camera.fov = 70.0
	_camera.far = 500.0
	_camera.global_position = player.global_position + Vector3(0, 3.5, 0)
	_camera.look_at(player.global_position + Vector3(-18, 5.0, -40))
	_camera.make_current()
	var total_instances: int = 0
	var chunks: Dictionary = _scene.get_node("WorldManager").get("loaded_chunks")
	for chunk: Node in chunks.values():
		total_instances += int(chunk.get_node("ProceduralEcosystemV6").get("instance_count"))
	await _capture("world", {"chunks": chunks.size(), "instances": total_instances,
		"spawn": [player.position.x, player.position.y, player.position.z]})


func _cluster() -> void:
	_fixture()
	var generator: Node = root.get_node("WorldGenerator")
	var spawn: Vector3 = generator.call("get_scenic_spawn")
	var chunk: Node3D = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
	var width: float = float(chunk.call("get_chunk_width"))
	chunk.set("chunk_coordinates", Vector2i(roundi(spawn.x / width), roundi(spawn.z / width)))
	_scene.add_child(chunk)
	var ecosystem: Node = chunk.get_node("ProceduralEcosystemV6")
	for frame in range(6000):
		await process_frame
		if bool(ecosystem.get("generation_complete")):
			break
	if not bool(ecosystem.get("generation_complete")):
		_failures.append("Cluster fixture did not finish.")
		return
	chunk.get_node("ChunkLODControllerV7").set_process(false)
	var height: float = float(chunk.call("get_surface_height_at_local_position", 0.0, 0.0))
	var target: Vector3 = chunk.position + Vector3(0, height + 3.5, 0)
	_camera.position = target + Vector3(30, 24, 46)
	_camera.look_at(target)
	# Controlled comparison: exactly the same placements, light, camera and Far
	# geometry. Disable per-batch distance culling only in this isolated fixture.
	for node: Node in ecosystem.get_children():
		if node is GeometryInstance3D:
			node.visibility_range_end = 0.0
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("wind_strength", 0.0)
	if ecosystem.has_method("set_cluster_enabled"):
		ecosystem.call("set_cluster_enabled", false)
	ecosystem.call("set_lod_tier", 2)
	chunk.call("set_lod_tier", 2)
	await _capture("far_batches", ecosystem.call("get_generation_stats"))
	if ecosystem.has_method("set_cluster_enabled"):
		ecosystem.call("set_cluster_enabled", true)
		for frame in range(6000):
			await process_frame
			if bool(ecosystem.call("get_generation_stats").get("cluster_complete", false)):
				break
		if not bool(ecosystem.call("get_generation_stats")["cluster_ready"]):
			_failures.append("Cluster review fixture failed to create its HLOD.")
		await _capture("far_cluster", ecosystem.call("get_generation_stats"))


func _creature() -> void:
	_fixture()
	var factory: Script = load("res://creatures/wildlife/species_assembly_factory_v7.gd")
	var blueprint: Dictionary = factory.create_species(int(_config["seed"]), Vector2i.ZERO, "grazer")
	var preview_script: Script = load("res://creatures/runtime/creature_runtime_preview.gd")
	_camera.position = Vector3(4.0, 2.8, 5.0)
	_camera.look_at(Vector3(0, 0.2, 0))
	for batched: bool in [false, true]:
		var preview: Node3D = preview_script.new()
		preview.set("batch_runtime_boxes", batched)
		preview.set("blueprint", blueprint.duplicate(true))
		var started: int = Time.get_ticks_usec()
		_scene.add_child(preview)
		var details: Dictionary = _render_inventory(preview)
		details["build_ms"] = (Time.get_ticks_usec() - started) / 1000.0
		await _capture("creature_batched" if batched else "creature_individual", details)
		preview.queue_free()
		await process_frame


func _render_inventory(node: Node) -> Dictionary:
	var counts: Dictionary = {"mesh_nodes": 0, "multimesh_nodes": 0, "instances": 0}
	if node is MeshInstance3D:
		counts["mesh_nodes"] += 1
	elif node is MultiMeshInstance3D:
		counts["multimesh_nodes"] += 1
		counts["instances"] += node.multimesh.instance_count
	for child: Node in node.get_children():
		var child_counts: Dictionary = _render_inventory(child)
		for key: String in counts:
			counts[key] += int(child_counts[key])
	return counts


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child: Node in node.get_children():
		_hide_ui(child)


func _capture(label: String, details: Dictionary) -> void:
	RenderingServer.render_loop_enabled = true
	for warmup in range(int(_config.get("warmup", 20))):
		await RenderingServer.frame_post_draw
	var wall: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var calls: Array[float] = []
	var primitives: Array[float] = []
	var rid: RID = root.get_viewport_rid()
	var previous: int = Time.get_ticks_usec()
	for frame in range(int(_config["frames"])):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		wall.append((now - previous) / 1000.0)
		previous = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
		calls.append(float(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)))
		primitives.append(float(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)))
	var image: Image = root.get_texture().get_image()
	var filename: String = label + ".png"
	if image == null or image.is_empty() or image.save_png(str(_config["output"]).path_join(filename)) != OK:
		_failures.append("Could not capture " + filename)
	if calls.max() <= 0.0:
		_failures.append("No real draw calls were recorded for " + label)
	_samples.append({"label": label, "image": filename, "details": details,
		"frames": wall.size(), "frame_ms": _distribution(wall),
		"render_cpu_ms": _distribution(cpu), "render_gpu_ms": _distribution(gpu),
		"gpu_timestamps_available": gpu.max() > 0.0, "draw_calls": _distribution(calls),
		"rendered_primitives": _distribution(primitives)})
	if label in ["far_batches", "creature_individual"]:
		_comparison_images[label] = image
	elif label in ["far_cluster", "creature_batched"]:
		var before_label: String = "far_batches" if label == "far_cluster" else "creature_individual"
		var before: Image = _comparison_images[before_label]
		before.convert(Image.FORMAT_RGB8)
		image.convert(Image.FORMAT_RGB8)
		var before_data: PackedByteArray = before.get_data()
		var after_data: PackedByteArray = image.get_data()
		var error_sum: int = 0
		for index in range(before_data.size()):
			error_sum += absi(int(before_data[index]) - int(after_data[index]))
		var error: float = float(error_sum) / float(before_data.size()) / 255.0
		_samples[-1]["mean_rgb_error_from_reference"] = error
		if error > 0.004:
			_failures.append("Rendered geometry/color parity failed for %s: mean RGB error %.6f" % [label, error])
		if float(_samples[-1]["draw_calls"]["median"]) >= float(_samples[-2]["draw_calls"]["median"]):
			_failures.append("Rendered batching did not reduce draw calls for " + label)
		_comparison_images.erase(before_label)
	print("Captured ", label, " draws=", calls[-1])


func _distribution(values: Array[float]) -> Dictionary:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {}
	return {"median": ordered[ordered.size() / 2], "p95": ordered[mini(ceili(ordered.size() * 0.95) - 1, ordered.size() - 1)],
		"p99": ordered[mini(ceili(ordered.size() * 0.99) - 1, ordered.size() - 1)], "max": ordered[-1]}
