extends SceneTree

const Assembly = preload("res://assembly/core/modular_assembly.gd")
const History = preload("res://assembly/core/modular_assembly_history.gd")
const MeshBuilder = preload("res://assembly/runtime/modular_voxel_mesh_builder.gd")
const BuildingParts = preload("res://civilization/buildings/building_part_library.gd")
const BuildingBlueprint = preload("res://civilization/buildings/building_blueprint.gd")
const BuildingRegistry = preload("res://civilization/buildings/building_design_registry.gd")
const CreatureBlueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const CreatureAdapter = preload("res://assembly/adapters/creature_assembly_adapter.gd")
const CreatureHistory = preload("res://creatures/editor/creature_builder_history_v7.gd")

const TEST_PATH: String = "user://building_builder_framework_test.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_generic_assembly()
	_test_building_blueprint()
	_test_merged_mesh()
	_test_creature_adapter()
	_test_design_registry()
	_test_shared_creature_history()
	await _test_builder_scene()
	_cleanup()
	_finish()


func _test_generic_assembly() -> void:
	var blueprint: Dictionary = Assembly.create("test", "Assembly Test")
	Assembly.set_grid_size(blueprint, 0.25)
	var index: int = Assembly.add_part(
		blueprint,
		"cube",
		Vector3(0.11, 0.12, 0.13)
	)
	Assembly.transform_part(blueprint, index, Vector3(0.20, 0.0, 0.0))
	var placement: Dictionary = Assembly.get_part(blueprint, index)
	var position: Vector3 = placement.get("position", Vector3.ZERO)
	_expect(is_equal_approx(position.x, 0.25), "Grid snap did not quantize the X position.")
	var duplicated: int = Assembly.duplicate_part(blueprint, index)
	_expect(duplicated == 1, "Generic assembly duplicate failed.")
	_expect(
		str(Assembly.get_part(blueprint, 0).get("uid", ""))
		!= str(Assembly.get_part(blueprint, 1).get("uid", "")),
		"Duplicated assembly parts share a UID."
	)
	var history := History.new()
	history.push_state(blueprint, "Before remove")
	Assembly.remove_part(blueprint, 0)
	var restored: Dictionary = history.undo(blueprint)
	_expect(restored.get("parts", []).size() == 2, "Generic undo did not restore assembly parts.")
	var serialized: Dictionary = Assembly.serialize(restored)
	var roundtrip: Dictionary = Assembly.deserialize(serialized)
	_expect(roundtrip.get("parts", []).size() == 2, "Assembly serialization roundtrip lost parts.")


func _test_building_blueprint() -> void:
	var blueprint: Dictionary = BuildingBlueprint.create_default()
	_expect(blueprint.get("parts", []).size() >= 5, "Default building contains too few parts.")
	_expect(BuildingBlueprint.validate(blueprint).is_empty(), "Default building blueprint is invalid.")
	var stats: Dictionary = BuildingBlueprint.calculate_stats(blueprint)
	_expect(float(stats.get("housing", 0.0)) > 0.0, "Default building has no housing value.")
	Assembly.add_part(blueprint, "tower_square", Vector3(4.0, 0.0, 0.0))
	var new_stats: Dictionary = BuildingBlueprint.calculate_stats(blueprint)
	_expect(
		float(new_stats.get("defense", 0.0)) > float(stats.get("defense", 0.0)),
		"Building stats did not react to modular tower placement."
	)
	var save_error: Error = BuildingBlueprint.save_to_file(blueprint, TEST_PATH)
	_expect(save_error == OK, "Building blueprint could not be saved.")
	var loaded: Dictionary = BuildingBlueprint.load_from_file(TEST_PATH)
	_expect(
		loaded.get("parts", []).size() == blueprint.get("parts", []).size(),
		"Building blueprint save roundtrip lost parts."
	)


func _test_merged_mesh() -> void:
	var blueprint: Dictionary = BuildingBlueprint.create_default()
	for index in range(12):
		Assembly.add_part(
			blueprint,
			"opening_window_small",
			Vector3(float(index % 4) - 1.5, 1.0 + float(index / 4), -2.15)
		)
	var mesh: ArrayMesh = MeshBuilder.build_mesh(
		blueprint,
		BuildingParts.get_all_parts(),
		-1
	)
	_expect(mesh.get_surface_count() == 1, "Modular building did not merge into one primitive mesh surface.")
	_expect(mesh.get_aabb().size.length() > 1.0, "Merged building mesh has invalid bounds.")


func _test_creature_adapter() -> void:
	var creature: Dictionary = CreatureBlueprint.create_default()
	var adapted: Dictionary = CreatureAdapter.to_modular_blueprint(creature)
	_expect(str(adapted.get("assembly_type", "")) == "creature", "Creature adapter returned wrong assembly type.")
	_expect(adapted.get("metadata", {}) is Dictionary, "Creature adapter has no migration metadata.")


func _test_design_registry() -> void:
	var set: Dictionary = BuildingRegistry.create_city_design_set(424_242)
	for type_name in BuildingBlueprint.BUILDING_TYPES:
		_expect(set.has(type_name), "City design set is missing '%s'." % type_name)
		var design_value: Variant = set.get(type_name)
		_expect(design_value is Dictionary, "City registry did not return a building blueprint.")
		if design_value is Dictionary:
			_expect(
				BuildingBlueprint.get_building_type(design_value) == type_name,
				"City registry returned wrong design type for '%s'." % type_name
			)


func _test_shared_creature_history() -> void:
	var history := CreatureHistory.new()
	var creature: Dictionary = CreatureBlueprint.create_default()
	history.push_state(creature, "Creature shared history")
	creature["name"] = "Changed"
	var restored: Dictionary = history.undo(creature)
	_expect(not restored.is_empty(), "Creature shared assembly history failed to undo.")
	_expect(str(restored.get("name", "")) != "Changed", "Creature history did not restore prior state.")


func _test_builder_scene() -> void:
	var scene := load("res://civilization/buildings/building_builder.tscn") as PackedScene
	_expect(scene != null, "Building Builder scene failed to load.")
	if scene == null:
		return
	var builder := scene.instantiate()
	root.add_child(builder)
	for _frame in range(10):
		await process_frame
	var preview := builder.get_node_or_null("BuildingPreview")
	_expect(preview != null, "Building Builder preview was not created.")
	var ui := builder.get_node_or_null("BuildingBuilderUI")
	_expect(ui != null, "Building Builder UI was not created.")
	var back_button := builder.get_node_or_null("BuildingBuilderUI/BackToWorld")
	_expect(back_button != null, "Building Builder navigation button was not installed.")
	var builder_blueprint: Variant = builder.get("blueprint")
	_expect(
		builder_blueprint is Dictionary
		and builder_blueprint.get("parts", []).size() >= 5,
		"Building Builder did not initialize a usable assembly."
	)
	builder.queue_free()
	await process_frame


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Modular Assembly Framework test passed.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
		return
	for failure in _failures:
		push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 1)
