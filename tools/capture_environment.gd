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

class WaterReviewChunk extends Node3D:
	var chunk_coordinates := Vector2i.ZERO
	func get_chunk_width() -> float:
		return 32.0
	func get_chunk_depth() -> float:
		return 32.0


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
		"assets", "species":
			await _assets()
		"cluster":
			await _cluster()
		"creature":
			await _creature()
		"water":
			await _water_continuity()
		"hydrology":
			await _hydrology()
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
	var species_review: bool = _config["case"] == "species"
	for family: String in FAMILIES:
		if species_review and family not in ["ancient_oak_v2", "tall_pine_v2", "dense_bush_v2", "layered_rock_v2"]:
			continue
		var group := Node3D.new()
		_scene.add_child(group)
		var species: Dictionary = Flora.create_species_variant(profile, "forest", family, 0)
		var near_mesh: Mesh = Assets.get_mesh(family, 0, int(species["geometry_variant"]))
		var bounds: AABB = near_mesh.get_aabb()
		var spacing: float = maxf(bounds.size.x, bounds.size.z) * 1.25
		for tier in range(3):
			if species_review:
				species = Flora.create_species_variant(profile, "forest", family, tier)
			var node := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = Assets.get_mesh(family, 0 if species_review else tier, int(species["geometry_variant"]))
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
		var distance: float = maxf((spacing * 2.0 + bounds.size.x) / (2.0 * half_fov * aspect), bounds.size.y / (2.0 * half_fov)) * (1.55 if family == "tall_pine_v2" else 1.25)
		_camera.position = target + Vector3(0, distance * 0.24, distance)
		_camera.look_at(target)
		await _capture(family, {"asset_id": family, "geometry_variant": species["geometry_variant"],
			"tiers_left_to_right": ["Near", "Near", "Near"] if species_review else ["Near", "Mid", "Far"],
			"variants_left_to_right": [0, 1, 2] if species_review else [0, 0, 0]})
		group.queue_free()
		await process_frame


func _world() -> void:
	change_scene_to_file("res://main/main.tscn")
	var started: int = Time.get_ticks_usec()
	var setup_limit: int = _setup_limit_usec()
	var last_diagnostic: int = started
	var setup_frames: Array[float] = []
	var ready: bool = false
	for frame in range(100000):
		if Time.get_ticks_usec() - started > setup_limit:
			break
		var previous: int = Time.get_ticks_usec()
		await process_frame
		setup_frames.append((Time.get_ticks_usec() - previous) / 1000.0)
		if current_scene == null:
			continue
		_scene = current_scene
		var manager: Node = _scene.get_node("WorldManager")
		# A stationary review player must survive long software-renderer setup.
		# Wildlife still runs its normal movement/animation; combat has its own
		# gameplay gate and must not relocate this camera via a nest respawn.
		_scene.get_node("Player").set_process(false)
		for creature: Node in _scene.get_node("FaunaStreamerV7").get_children():
			creature.set("predator_attack_damage", 0.0)
		if Time.get_ticks_usec() - last_diagnostic > 5_000_000:
			print("Capture streaming ", JSON.stringify(_streaming_state(manager)))
			last_diagnostic = Time.get_ticks_usec()
		if not bool(manager.get("world_initialized")):
			continue
		_scene.get_node("Player").set_physics_process(false)
		if int(manager.call("get_pending_chunk_count")) != 0:
			continue
		ready = bool(manager.get_node("LandscapeHorizon").generation_complete)
		for chunk: Node in manager.get("loaded_chunks").values():
			if not bool(chunk.get_node("ProceduralEcosystemV6").get("generation_complete")) or chunk.get_node("ProceduralEcosystemV6").is_processing():
				ready = false
				break
		if ready:
			break
	if is_instance_valid(_scene):
		_report["streaming_state"] = _streaming_state(_scene.get_node("WorldManager"))
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
	var expected_spawn: Vector3 = root.get_node("WorldGenerator").call("get_scenic_spawn")
	if Vector2(player.position.x, player.position.z).distance_to(Vector2(expected_spawn.x, expected_spawn.z)) > 0.1:
		_failures.append("Review player left the deterministic scenic spawn.")
	if chunks.size() != 25 or total_instances < 500:
		_failures.append("World review did not exercise a populated 25-chunk meadow/forest fixture.")
	await _capture("world", {"chunks": chunks.size(), "instances": total_instances,
		"spawn": [player.position.x, player.position.y, player.position.z]})

	await _capture_landscape_views(player.global_position)


func _capture_landscape_views(spawn: Vector3) -> void:
	var generator: Node = root.get_node("WorldGenerator")
	var peak := spawn
	var water := spawn
	var water_distance: float = INF
	var sea: float = generator.get_sea_level()
	for z in range(-20, 21):
		for x in range(-20, 21):
			var point := spawn + Vector3(x * 16.0, 0, z * 16.0)
			point.y = generator.get_visual_terrain_height(point.x, point.z)
			if point.y > peak.y:
				peak = point
			var distance: float = Vector2(point.x - spawn.x, point.z - spawn.z).length()
			if point.y < sea - 0.35 and distance < water_distance:
				water_distance = distance
				water = point
	_camera.global_position = spawn + Vector3(0, 3.5, 0)
	_camera.look_at(peak)
	await _capture("landscape", {"target": [peak.x, peak.y, peak.z], "surface_height": peak.y})
	if water_distance < 120.0:
		var shore: Vector3 = spawn
		for step in range(20):
			var point: Vector3 = spawn.lerp(water, step / 20.0)
			point.y = generator.get_visual_terrain_height(point.x, point.z)
			if point.y > sea + 0.2:
				shore = point
		_camera.global_position = shore + Vector3(0, 2.6, 0)
		_camera.look_at(Vector3(water.x, sea + 0.05, water.z))
		await _capture("shore_water", {"camera": [_camera.position.x, _camera.position.y, _camera.position.z], "water_target": [water.x, sea, water.z]})
	else:
		_failures.append("Water review seed no longer supplies a nearby visible shore.")


func _streaming_state(manager: Node) -> Dictionary:
	var states: Array[Dictionary] = []
	for chunk: Node in manager.get("loaded_chunks").values():
		var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
		states.append({"chunk": str(chunk.get("chunk_coordinates")),
			"terrain_ready": chunk.get("generation_complete"), "phase": ecology.get("_phase"),
			"processing": ecology.is_processing(), "lod": ecology.get("_lod_tier"),
			"published": ecology.get("_publish_index"), "stats": ecology.call("get_generation_stats")})
	return {"world_initialized": manager.get("world_initialized"),
		"pending_chunks": manager.call("get_pending_chunk_count"), "chunks": states,
		"player_position": str(_scene.get_node("Player").position),
		"player_dead": _scene.get_node("Player").get("is_dead")}


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


func _water_continuity() -> void:
	# Controlled, actual GPU rendering of full and partial shared-water overlap.
	# Freeze shader time in a review-only copy; production shaders are unchanged.
	_scene = Node3D.new()
	root.add_child(_scene)
	current_scene = _scene
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.32, 0.42, 0.48)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	_scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	_scene.add_child(light)
	var generator: Node = root.get_node("WorldGenerator")
	var sea: float = generator.get_sea_level()
	var bed := MeshInstance3D.new()
	var bed_mesh := PlaneMesh.new()
	bed_mesh.size = Vector2(100, 100)
	bed.mesh = bed_mesh
	bed.position.y = sea - 1.7
	bed.rotation_degrees.x = 5.0
	var bed_material := StandardMaterial3D.new()
	bed_material.albedo_color = Color(0.43, 0.39, 0.30)
	bed.material_override = bed_material
	_scene.add_child(bed)
	_camera = Camera3D.new()
	_scene.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 14.0
	_camera.position = Vector3(0, sea + 30, 5)
	_camera.look_at(Vector3(0, sea, 0))
	_camera.make_current()
	var surface: Script = load("res://world/streaming/world_water_mesh_job.gd")
	var builder: Script = load("res://world/visuals/terrain/water_mesh_builder_v7.gd")
	var reference: Node = load("res://world/visuals/terrain/terrain_chunk.tscn").instantiate()
	var settings: Dictionary = reference.get_node("Visuals").get_water_settings()
	reference.free()
	var material: ShaderMaterial = builder.make_material(generator.get_planet_profile(), settings)
	var frozen := Shader.new()
	frozen.code = material.shader.code.replace("TIME", "7.0")
	material.shader = frozen
	var shared := MeshInstance3D.new()
	var shared_mesh := ArrayMesh.new()
	shared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.build(generator, Vector2.ZERO, 384.0))
	shared.mesh = shared_mesh
	shared.material_override = material
	_scene.add_child(shared)
	var chunk := WaterReviewChunk.new()
	_scene.add_child(chunk)
	var fallback := MeshInstance3D.new()
	fallback.name = "WaterMesh"
	chunk.add_child(fallback)
	# Use the real local builder, including inspector-to-nested-grid rounding.
	builder.build(chunk, fallback, settings)
	var fallback_material: ShaderMaterial = fallback.material_override
	fallback_material.shader = frozen
	fallback.visible = false
	var details: Dictionary = {"shader_time": 7.0, "shared_vertices": 37249, "partial_boundary_x": 0.0}
	await _capture("water_shared_reference", details)
	fallback.visible = true
	fallback_material.set_shader_parameter("clip_shared_surface", true)
	fallback_material.set_shader_parameter("shared_surface_bounds", Vector4(-384, -384, 384, 384))
	await _capture("water_clipped_fallback", details)
	material.set_shader_parameter("clip_shared_surface", true)
	material.set_shader_parameter("shared_surface_bounds", Vector4(-384, -384, 0, 384))
	fallback_material.set_shader_parameter("shared_surface_bounds", Vector4(0, -384, 384, 384))
	await _capture("water_partial_overlap", details)
	# Negative control: the image gate must detect doubled transparent water.
	material.set_shader_parameter("clip_shared_surface", false)
	fallback_material.set_shader_parameter("clip_shared_surface", false)
	await _capture("water_overlap_control", details)
	_comparison_images.erase("water_shared_reference")
	# Equal checker beds at known vertical depths isolate the material from
	# terrain colour, perspective and lighting. The deep floor must disappear.
	fallback.visible = false
	bed.visible = false
	_camera.position = Vector3(0, sea + 30, 0.001)
	_camera.look_at(Vector3(0, sea, 0))
	var checker := Shader.new()
	checker.code = "shader_type spatial; render_mode unshaded; varying vec2 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;} void fragment(){float v=mod(floor(p.x*2.0)+floor(p.y*2.0),2.0); ALBEDO=vec3(mix(0.22,0.82,v));}"
	var checker_material := ShaderMaterial.new()
	checker_material.shader = checker
	for i in range(3):
		var patch := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(4, 18)
		patch.mesh = plane
		patch.material_override = checker_material
		patch.position = Vector3((i - 1) * 4, sea - [0.3, 2.0, 8.0][i], 0)
		_scene.add_child(patch)
	shared.visible = false
	await _capture("water_depth_bare", {"depths_m": [0.3, 2.0, 8.0]})
	var bare: Image = root.get_texture().get_image()
	shared.visible = true
	await _capture("water_depth_steps", {"depths_m": [0.3, 2.0, 8.0]})
	var covered: Image = root.get_texture().get_image()
	var contrast_ratios: Array[float] = []
	for i in range(3):
		var sum: float = 0.0
		var weight: float = 0.0
		for z in range(-3, 4):
			for x in range(-2, 3):
				var point := Vector3((i - 1) * 4 + x * 0.5 + 0.12, sea, z * 0.5 + 0.12)
				var first := Vector2i(_camera.unproject_position(point))
				var second := Vector2i(_camera.unproject_position(point + Vector3(0.5, 0, 0)))
				sum += absf(covered.get_pixelv(first).get_luminance() - covered.get_pixelv(second).get_luminance())
				weight += absf(bare.get_pixelv(first).get_luminance() - bare.get_pixelv(second).get_luminance())
		contrast_ratios.append(sum / maxf(weight, 0.001))
	if contrast_ratios[0] < 0.08 or contrast_ratios[2] > 0.06 or contrast_ratios[0] < contrast_ratios[2] + 0.08:
		_failures.append("Water depth does not retain a visible shallow bed and obscure the deep bed.")
	_report["water_depth_contrast"] = contrast_ratios
	print("WATER_DEPTH_RENDER ", JSON.stringify({"seed": _config["seed"], "bed_contrast_ratio": contrast_ratios}))


func _hydrology() -> void:
	_fixture()
	var generator: Node = root.get_node("WorldGenerator")
	var drainage: Script = load("res://world/generation/drainage_network.gd")
	var spawn: Vector3 = generator.get_scenic_spawn()
	var region := Vector2i(floori(spawn.x / 384.0), floori(spawn.z / 384.0))
	var route: Dictionary = {}
	var lake: Dictionary = {}
	var closest: float = INF
	for z in range(-2, 3):
		for x in range(-2, 3):
			var candidate: Dictionary = generator.get_drainage_region(region + Vector2i(x, z))
			if candidate.is_empty():
				continue
			for body: Dictionary in candidate["lakes"]:
				var distance: float = (body["center"] as Vector2).distance_squared_to(Vector2(spawn.x, spawn.z))
				if float(body["level"]) > generator.get_sea_level() + 2.0 and distance < closest:
					closest = distance
					route = candidate
					lake = body
	if lake.is_empty():
		_failures.append("Hydrology capture did not find an elevated lake and connected river.")
		return
	var center: Vector2 = lake["center"]
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(center.x, float(lake["level"]) + 4.0, center.y)
	player.add_to_group(&"player")
	_scene.add_child(player)
	var manager: Node3D = load("res://world/world_manager.tscn").instantiate()
	manager.choose_scenic_spawn_for_default_start = false
	_scene.add_child(manager)
	var started: int = Time.get_ticks_usec()
	var setup_limit: int = _setup_limit_usec()
	var ready: bool = false
	while Time.get_ticks_usec() - started < setup_limit:
		await process_frame
		if not manager.world_initialized or manager.get_pending_chunk_count() > 0:
			continue
		ready = manager.get_node("LandscapeHorizon").generation_complete
		for chunk: Node3D in manager.loaded_chunks.values():
			ready = ready and chunk.generation_complete and chunk.get_node("ProceduralEcosystemV6").generation_complete and chunk.terrain_presence >= 1.0
		if ready:
			break
	if not ready:
		_failures.append("Hydrology world did not finish streaming.")
		return
	_report["setup_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	var horizon: Node3D = manager.get_node("LandscapeHorizon")
	var details: Dictionary = {"source": str(route["source"]), "outlet": str(route["sink"]),
		"lake_center": str(center), "lake_level": lake["level"], "sea_level": generator.get_sea_level(),
		"river_length": route["length"], "chunks": manager.loaded_chunks.size()}
	var middle: Vector2 = drainage.center_at(route, 0.45)
	var target := Vector3(middle.x, float(lake["level"]) * 0.5, middle.y)
	var lateral: Vector2 = route["lateral"]
	_camera.position = target + Vector3(lateral.x * 105.0, 145.0, lateral.y * 105.0)
	_camera.look_at(target)
	await _capture("hydrology_overview", details)
	var shore_target := Vector3(center.x, float(lake["level"]) + 0.03, center.y)
	_camera.position = _lake_shore_camera(generator, center, float(lake["radius"]), shore_target.y)
	_camera.look_at(shore_target)
	details["shore_camera"] = str(_camera.position)
	await _capture("hydrology_shore", details)
	# Freeze unrelated animation and use the live terrain materials/coverage.
	# The image gate must see a real intermediate shape, not only a timer value.
	manager.set_process(false)
	horizon.set_process(false)
	for chunk: Node3D in manager.loaded_chunks.values():
		chunk.set_process(false)
		chunk.get_node("ChunkLODControllerV7").set_process(false)
		chunk.get_node("ProceduralEcosystemV6").visible = false
		chunk._terrain_lod_blend = 0.0
		chunk._apply_lod_visibility()
		var local_water: MeshInstance3D = chunk.get_node("WaterMesh")
		if local_water.material_override is ShaderMaterial:
			var frozen := Shader.new()
			frozen.code = local_water.material_override.shader.code.replace("TIME", "7.0")
			local_water.material_override.shader = frozen
	var shared: MeshInstance3D = horizon.get_node("DistantWater")
	var frozen_water := Shader.new()
	frozen_water.code = shared.material_override.shader.code.replace("TIME", "7.0")
	shared.material_override.shader = frozen_water
	var selected: Node3D = manager.loaded_chunks[manager.current_player_chunk]
	var ground: float = generator.get_terrain_height(selected.position.x, selected.position.z)
	target = Vector3(selected.position.x, ground, selected.position.z)
	_camera.position = target + Vector3(36, 40, 44)
	_camera.look_at(target)
	for amount: float in [0.0, 0.5, 1.0]:
		selected.terrain_presence = amount
		horizon._update_coverage()
		await _capture("terrain_transition_%d" % roundi(amount * 100.0), {"presence": amount, "chunk": str(selected.chunk_coordinates), "decorations_hidden": true})
	var initial: Image = _comparison_images["terrain_transition_0"]
	var halfway: Image = _comparison_images["terrain_transition_50"]
	var final_image: Image = _comparison_images["terrain_transition_100"]
	var first_change: float = _mean_rgb_difference(initial, halfway)
	var second_change: float = _mean_rgb_difference(halfway, final_image)
	if first_change < 0.0005 or second_change < 0.0005:
		_failures.append("GPU terrain transition has no distinct intermediate geometry.")
	_report["terrain_transition_rgb_changes"] = [first_change, second_change]
	print("HYDROLOGY_RENDER ", JSON.stringify({"seed": _config["seed"], "lake": details, "transition_rgb_changes": [first_change, second_change]}))
	for label: String in ["terrain_transition_0", "terrain_transition_50", "terrain_transition_100"]:
		_comparison_images.erase(label)


func _lake_shore_camera(generator: Node, center: Vector2, radius: float, level: float) -> Vector3:
	# A spring basin may sit behind a high rim. Camera-ground clearance alone
	# does not make its water visible; check the entire ray to the lake centre.
	var best := Vector3(center.x, INF, center.y)
	for i in range(16):
		var shore: Vector2 = center + Vector2.from_angle(TAU * i / 16.0) * (radius + 17.0)
		var height: float = maxf(level + 8.0, generator.get_terrain_height(shore.x, shore.y) + 6.0)
		for step in range(1, 32):
			var fraction: float = step / 32.0
			var point: Vector2 = shore.lerp(center, fraction)
			var blocker: float = generator.get_visual_terrain_height(point.x, point.y) + 2.0
			height = maxf(height, (blocker - level * fraction) / (1.0 - fraction))
		if height < best.y:
			best = Vector3(shore.x, height, shore.y)
	return best


func _setup_limit_usec() -> int:
	# llvmpipe's Forward+ resource creation can exceed two minutes for a full
	# forest fixture, even while publication continues. Fast setup is explicitly
	# outside the gameplay frame measurements; retain a bounded watchdog here.
	var seconds: int = 240 if bool(_report["software_renderer"]) and bool(_config.get("fast_setup", false)) else 120
	_report["setup_limit_seconds"] = seconds
	return seconds * 1_000_000


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
	if label in ["hydrology_overview", "hydrology_shore", "terrain_transition_50", "landscape", "shore_water", "water_depth_steps"]:
		var preview: Image = image.duplicate()
		preview.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		print("REVIEW_PREVIEW ", str(_config["seed"]), " ", label, " ", Marshalls.raw_to_base64(preview.save_jpg_to_buffer(0.76)))
	if label.begins_with("terrain_transition_"):
		_comparison_images[label] = image
	if label in ["far_batches", "creature_individual", "water_shared_reference"]:
		_comparison_images[label] = image
	elif label in ["water_clipped_fallback", "water_partial_overlap", "water_overlap_control"]:
		var error: float = _mean_rgb_difference(_comparison_images["water_shared_reference"], image)
		_samples[-1]["mean_rgb_error_from_reference"] = error
		if label == "water_overlap_control":
			if error < 0.001:
				_failures.append("Water parity gate failed to detect its overlapping-surface negative control.")
		elif error > 0.004:
			_failures.append("Shared water has a gap or double blend in %s: mean RGB error %.6f" % [label, error])
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


func _mean_rgb_difference(first: Image, second: Image) -> float:
	first.convert(Image.FORMAT_RGB8)
	second.convert(Image.FORMAT_RGB8)
	var before: PackedByteArray = first.get_data()
	var after: PackedByteArray = second.get_data()
	var error_sum: int = 0
	for index in range(before.size()):
		error_sum += absi(int(before[index]) - int(after[index]))
	return float(error_sum) / float(before.size()) / 255.0


func _distribution(values: Array[float]) -> Dictionary:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {}
	return {"median": ordered[ordered.size() / 2], "p95": ordered[mini(ceili(ordered.size() * 0.95) - 1, ordered.size() - 1)],
		"p99": ordered[mini(ceili(ordered.size() * 0.99) - 1, ordered.size() - 1)], "max": ordered[-1]}
