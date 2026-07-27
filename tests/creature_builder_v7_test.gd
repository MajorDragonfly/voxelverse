extends SceneTree

const AssemblyV7 = preload(
	"res://creatures/editor/creature_assembly_blueprint_v7.gd"
)
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const SocketsV7 = preload(
	"res://creatures/editor/creature_surface_sockets_v7.gd"
)
const HistoryV7 = preload(
	"res://creatures/editor/creature_builder_history_v7.gd"
)
const SpeciesFactoryV7 = preload(
	"res://creatures/wildlife/species_assembly_factory_v7.gd"
)

const TEST_SAVE_PATH: String = "user://creature_builder_v7_test.json"
const FORBIDDEN_FIELDS: Array[String] = [
	"generation",
	"genes",
	"genome",
	"genetics",
	"mutation",
	"mutations",
	"lineage",
	"parent_seed",
]

var _failures: Array[String] = []


func _initialize() -> void:
	_test_default_assembly()
	_test_save_roundtrip()
	_test_surface_sockets()
	_test_history()
	_test_modular_species()
	_test_required_resources()
	_cleanup()
	_finish()


func _test_default_assembly() -> void:
	var blueprint: Dictionary = AssemblyV7.create_default()
	_expect(not blueprint.is_empty(), "Default V7 assembly is empty.")
	_expect(
		str(blueprint.get("progression", {}).get("phase", "")) == "creature",
		"Creature progression phase is missing."
	)
	_expect(
		int(blueprint.get("assembly", {}).get("schema", 0)) == 7,
		"Assembly schema is not V7."
	)
	_expect_no_genetic_fields(blueprint, "default assembly")


func _test_save_roundtrip() -> void:
	var blueprint: Dictionary = AssemblyV7.create_default()
	blueprint["name"] = "Builder Roundtrip"
	AssemblyV7.increment_revision(blueprint)
	var save_error: Error = AssemblyV7.save_to_file(blueprint, TEST_SAVE_PATH)
	_expect(save_error == OK, "V7 assembly save failed: %s" % save_error)
	var loaded: Dictionary = AssemblyV7.load_from_file(TEST_SAVE_PATH)
	_expect(not loaded.is_empty(), "V7 assembly roundtrip returned no data.")
	_expect(
		str(loaded.get("name", "")) == "Builder Roundtrip",
		"Creature name did not survive the V7 roundtrip."
	)
	_expect(
		AssemblyV7.get_revision(loaded) == 1,
		"Assembly revision did not survive the V7 roundtrip."
	)
	_expect_no_genetic_fields(loaded, "loaded assembly")


func _test_surface_sockets() -> void:
	var blueprint: Dictionary = AssemblyV7.create_default()
	Anatomy.ensure_anchors(blueprint, true)
	var part_index: int = Blueprint.add_part(blueprint, "horns_short")
	if part_index < 0:
		part_index = Blueprint.add_part(blueprint, "decor_crystal")
	_expect(part_index >= 0, "No test part could be added for socket validation.")
	if part_index < 0:
		return
	var snapped: bool = SocketsV7.snap_part_to_surface(blueprint, part_index)
	_expect(snapped, "Surface socket rejected a valid modular part.")
	var placement: Dictionary = Blueprint.get_part_placement(blueprint, part_index)
	_expect(
		bool(placement.get("anchor_locked", false)),
		"Surface-snapped part is not anchor locked."
	)
	_expect(
		str(placement.get("socket_type", "")).length() > 0,
		"Surface-snapped part has no socket type."
	)


func _test_history() -> void:
	var history := HistoryV7.new()
	var blueprint: Dictionary = AssemblyV7.create_default()
	history.push_state(blueprint, "Before rename")
	blueprint["name"] = "Changed"
	var restored: Dictionary = history.undo(blueprint)
	_expect(
		str(restored.get("name", "")) == "New Creature",
		"Undo did not restore the previous assembly."
	)
	var redone: Dictionary = history.redo(restored)
	_expect(
		str(redone.get("name", "")) == "Changed",
		"Redo did not restore the changed assembly."
	)


func _test_modular_species() -> void:
	var first: Dictionary = SpeciesFactoryV7.create_species(
		771_337,
		Vector2i(2, -4),
		"predator"
	)
	var repeated: Dictionary = SpeciesFactoryV7.create_species(
		771_337,
		Vector2i(2, -4),
		"predator"
	)
	_expect(not first.is_empty(), "Modular species factory returned no creature.")
	_expect_no_genetic_fields(first, "modular wildlife species")
	_expect(
		str(first.get("name", "")) == str(repeated.get("name", "")),
		"Same species seed produced a different species name."
	)
	_expect(
		Blueprint.get_body_shape(first).is_equal_approx(
			Blueprint.get_body_shape(repeated)
		),
		"Same species seed produced a different body shape."
	)
	_expect(
		Blueprint.get_part_count(first) == Blueprint.get_part_count(repeated),
		"Same species seed produced a different modular part count."
	)


func _test_required_resources() -> void:
	for path in [
		"res://creatures/editor/creature_editor.tscn",
		"res://creatures/editor/creature_editor_v7.gd",
		"res://creatures/editor/creature_assembly_blueprint_v7.gd",
		"res://creatures/editor/creature_builder_history_v7.gd",
		"res://creatures/editor/creature_surface_sockets_v7.gd",
		"res://creatures/runtime/creature_runtime_visual.gd",
		"res://creatures/wildlife/species_assembly_factory_v7.gd",
		"res://creatures/wildlife/procedural_wildlife_v7.tscn",
	]:
		_expect(load(path) != null, "Creature Builder V7 resource failed: %s" % path)


func _expect_no_genetic_fields(value: Dictionary, context: String) -> void:
	for field_name in FORBIDDEN_FIELDS:
		_expect(
			not value.has(field_name),
			"Forbidden genetic field '%s' remains in %s." % [field_name, context]
		)


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Creature Builder V7 test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
