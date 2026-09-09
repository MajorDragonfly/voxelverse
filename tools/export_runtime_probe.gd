extends SceneTree

# The official release template disables --script. validate_export.py starts the
# untouched release binary separately, then uses the editor with --main-pack for
# these instrumented checks. Every res:// resource still comes from that PCK.
const Catalog = preload("res://assets/catalog/asset_catalog.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const FAMILY_IDS: Array[String] = ["ancient_oak_v2", "tall_pine_v2", "dense_bush_v2",
	"fern_cluster_v2", "flower_cluster_v2", "layered_rock_v2", "grass_tuft_v2"]

var _failures: Array[String] = []
var _report: Dictionary = {}
var _report_path: String
var _notices_path: String
var _seed_value: int = 15838


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 3 or not arguments[0].is_valid_int():
		push_error("Expected export probe arguments: seed report_path notices_path")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	_seed_value = int(arguments[0])
	_report_path = arguments[1]
	_notices_path = arguments[2]
	_report = {"seed": _seed_value, "godot": Engine.get_version_info()["string"],
		"platform": OS.get_name(), "executable": OS.get_executable_path(),
		"user_data_dir": OS.get_user_data_dir(), "engine_mode": "editor_with_release_pck"}
	_expect(not FileAccess.file_exists("res://project.godot"), "Probe resolved an unpackaged source project.")
	_expect(not FileAccess.file_exists("res://tools/validate_godot.py"), "Development tools were packaged.")
	_expect(not ResourceLoader.exists("res://tests/gameplay_acceptance_test.gd"), "Tests were packaged.")
	_expect(not FileAccess.file_exists("res://art/source/blockbench/environment/benchmark_v2/ancient_oak_v2.bbmodel"), "Source art was packaged.")
	_test_catalog_meshes()
	if not _failures.is_empty():
		_finish()
		return
	root.get_node("SaveGameService").set("autosave_enabled", false)
	root.get_node("GameState").call("start_world_with_seed", _seed_value)
	await process_frame
	_expect(change_scene_to_file("res://main/main.tscn") == OK, "Packaged main scene could not start.")
	if not await _wait_for_world():
		_finish()
		return
	var generator: Node = root.get_node("WorldGenerator")
	var initial_profile: Dictionary = generator.call("get_planet_profile")
	_expect(int(initial_profile.get("visual_generation_version", 0)) == 9, "Export did not activate V9.")
	_expect(int(initial_profile.get("planet_seed", 0)) == _seed_value, "Export used a different seed.")
	_report["flora_color_family"] = initial_profile.get("flora_color_family", "")
	_test_save_round_trip()
	await process_frame
	if _seed_value == 15838:
		await _test_planet_transition(initial_profile)
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	_finish()


func _test_catalog_meshes() -> void:
	Catalog.reset_cache()
	_expect(Catalog.get_pack_ids().has("temperate_forest_v1"), "Packaged manifest was not discovered.")
	_expect(Catalog.get_errors().is_empty(), "Packaged catalog errors: %s" % [Catalog.get_errors()])
	var count: int = 0
	for family: String in FAMILY_IDS:
		var entry: Dictionary = Catalog.get_asset(family)
		_expect(not entry.is_empty(), "Missing packaged family: %s" % family)
		if entry.is_empty():
			continue
		_expect(Catalog.validate_asset_entry(entry, true).is_empty(), "Missing packaged LOD for %s" % family)
		for variant in range(3):
			for tier in range(3):
				var mesh: Mesh = Assets.get_mesh(family, tier, variant)
				_expect(mesh != null, "Could not load %s/%d/%d from PCK." % [family, variant, tier])
				if mesh == null:
					continue
				_expect(mesh.get_surface_count() == 1, "Packaged mesh lost its single-surface contract.")
				_expect(mesh.get_aabb().size.length() > 0.01, "Packaged mesh is empty.")
				var arrays: Array = mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				_expect(not vertices.is_empty() and uvs.size() == vertices.size(), "Packaged mesh lost semantic UVs.")
				count += 1
	_expect(count == 63, "Export did not load all 63 production meshes.")
	_report["loaded_meshes"] = count


func _wait_for_world(previous_scene_id: int = 0) -> bool:
	for frame in range(3600):
		await process_frame
		if current_scene == null or current_scene.get_instance_id() == previous_scene_id:
			continue
		var manager: Node = current_scene.get_node_or_null("WorldManager")
		if manager == null or not bool(manager.get("world_initialized")):
			continue
		var player: Node3D = current_scene.get_node("Player")
		_expect(player.global_position.is_finite(), "Exported player position is invalid.")
		var chunks: Dictionary = manager.get("loaded_chunks")
		for chunk: Node in chunks.values():
			var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
			if not bool(ecology.get("generation_complete")) or ecology.get_child_count() == 0:
				continue
			var terrain: MeshInstance3D = chunk.get_node("TerrainMesh")
			var collision: CollisionShape3D = chunk.get_node("TerrainCollision")
			var water: MeshInstance3D = chunk.get_node("WaterMesh")
			_expect(terrain.mesh != null and collision.shape is HeightMapShape3D, "Exported terrain/collision is missing.")
			_expect(terrain.material_override is ShaderMaterial and water.material_override is ShaderMaterial, "Exported terrain/water materials are missing.")
			var batch: MultiMeshInstance3D = ecology.get_child(0) as MultiMeshInstance3D
			_expect(batch != null and batch.multimesh.instance_count > 0, "Exported vegetation has no instances.")
			if batch != null:
				var material: ShaderMaterial = batch.material_override as ShaderMaterial
				_expect(material != null and material.get_shader_parameter("planet_palette") is Texture2D, "Exported vegetation palette is missing.")
			_report["last_world_instances"] = int(ecology.get("instance_count"))
			return true
	_expect(false, "Packaged main scene did not produce playable terrain and vegetation.")
	return false


func _test_save_round_trip() -> void:
	var service: Node = root.get_node("SaveGameService")
	var player: Node = current_scene.get_node("Player")
	player.set("current_health", 37.0)
	_expect(bool(service.call("save_now", "user://export_round_trip.json")), "Exported save failed.")
	player.set("current_health", 11.0)
	_expect(bool(service.call("load_now", "user://export_round_trip.json")), "Exported load failed.")
	_expect(is_equal_approx(float(player.get("current_health")), 37.0), "Packaged save/load did not restore player health.")
	_report["save_round_trip"] = true


func _test_planet_transition(first_profile: Dictionary) -> void:
	var runtime: Node = current_scene.get_node("StarSystemRuntimeV7")
	var first_index: int = int(runtime.call("get_active_planet").get("index", 0))
	var previous_id: int = current_scene.get_instance_id()
	runtime.call("cycle_to_next_planet")
	if not await _wait_for_world(previous_id):
		return
	var generator: Node = root.get_node("WorldGenerator")
	_expect(generator.call("get_planet_profile") != first_profile, "Packaged planet cycle retained the old profile.")
	runtime = current_scene.get_node("StarSystemRuntimeV7")
	previous_id = current_scene.get_instance_id()
	runtime.call("activate_planet", first_index)
	if not await _wait_for_world(previous_id):
		return
	_expect(generator.call("get_planet_profile") == first_profile, "Packaged A-B-A cycle changed the initial planet.")
	_report["planet_transition"] = "A-B-A"


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var notices: String = Engine.get_license_text() + "\n\nThird-party copyright notices\n\n"
	notices += JSON.stringify(Engine.get_copyright_info(), "\t") + "\n\n"
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for license_name: String in names:
		notices += license_name + "\n" + str(licenses[license_name]) + "\n\n"
	var notices_file := FileAccess.open(_notices_path, FileAccess.WRITE)
	if notices_file != null:
		notices_file.store_string(notices)
		notices_file.close()
	else:
		_failures.append("Could not write bundled engine notices.")
	_report["passed"] = _failures.is_empty()
	_report["failures"] = _failures
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t") + "\n")
		file.close()
	else:
		_failures.append("Could not write export validation report.")
	for failure: String in _failures:
		push_error(failure)
	print("EXPORTED_RUNTIME_PROBE ", JSON.stringify(_report))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if _failures.is_empty() else 1)
