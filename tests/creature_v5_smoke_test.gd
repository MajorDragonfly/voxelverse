extends SceneTree

const Blueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const BlueprintV5 = preload(
	"res://creatures/editor/creature_blueprint_v5.gd"
)
const AssemblyV7 = preload(
	"res://creatures/editor/creature_assembly_blueprint_v7.gd"
)

const TEST_PATH: String = "user://creature_v5_migration_test.json"
var _failures: Array[String] = []


func _initialize() -> void:
	_run_legacy_roundtrip_and_migration()
	_run_scene_resource_checks()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	if _failures.is_empty():
		print("Creature V5 migration compatibility test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _run_legacy_roundtrip_and_migration() -> void:
	var legacy: Dictionary = Blueprint.create_default()
	legacy["generation"] = {
		"seed": 314159265,
		"generation": 4,
		"parent_seed": 271828182,
	}
	legacy["genes"] = {"obsolete": true}
	var save_error: Error = BlueprintV5.save_to_file(legacy, TEST_PATH)
	_expect(save_error == OK, "Could not write legacy V5 migration fixture.")
	if save_error != OK:
		return
	var loaded: Dictionary = BlueprintV5.load_from_file(TEST_PATH)
	_expect(not loaded.is_empty(), "Legacy V5 fixture could not be loaded.")
	AssemblyV7.normalize(loaded)
	_expect(
		int(loaded.get("assembly", {}).get("schema", 0)) == 7,
		"Legacy creature was not upgraded to assembly schema V7."
	)
	for forbidden_field in [
		"generation",
		"genes",
		"genome",
		"genetics",
		"mutation",
		"mutations",
		"lineage",
		"parent_seed",
		"seed",
	]:
		_expect(
			not loaded.has(forbidden_field),
			"Legacy migration retained forbidden field: %s" % forbidden_field
		)
	_expect(
		Blueprint.calculate_complexity(loaded) <= Blueprint.COMPLEXITY_LIMIT,
		"Migrated creature exceeds the complexity limit."
	)


func _run_scene_resource_checks() -> void:
	for path in [
		"res://creatures/editor/creature_editor.tscn",
		"res://creatures/player/player.tscn",
		"res://main/main.tscn",
	]:
		_expect(load(path) != null, "Required runtime scene could not load: %s" % path)


func _expect(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)
