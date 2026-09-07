extends SceneTree

const Catalog = preload("res://assets/catalog/asset_catalog.gd")
const Resolver = preload("res://assembly/runtime/modular_asset_resolver.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_catalog_discovery()
	_test_lod_resolution()
	_test_asset_transform()
	_test_validation()
	_test_source_art_isolated()
	_finish()


func _test_catalog_discovery() -> void:
	Catalog.reset_cache()
	var pack_ids: Array[String] = Catalog.get_pack_ids()
	_expect(
		pack_ids.has("temperate_forest_v1"),
		"Temperate Forest V1 runtime pack was not discovered."
	)
	_expect(
		Catalog.get_errors().is_empty(),
		"Asset catalog reported manifest errors: %s" % Catalog.get_errors()
	)


func _test_lod_resolution() -> void:
	var entry: Dictionary = {
		"asset_id": "test_tree",
		"kind": "environment_tree",
		"lod": {
			"near": "res://near.glb",
			"mid": "res://mid.glb",
			"far": "res://far.glb",
		},
	}
	_expect(
		Catalog.resolve_lod_path(entry, 0) == "res://near.glb",
		"Near LOD path resolution failed."
	)
	_expect(
		Catalog.resolve_lod_path(entry, 1) == "res://mid.glb",
		"Mid LOD path resolution failed."
	)
	_expect(
		Catalog.resolve_lod_path(entry, 2) == "res://far.glb",
		"Far LOD path resolution failed."
	)
	entry["lod"] = {
		"near": "res://near.glb",
		"mid": "res://mid.glb",
		"far": "",
	}
	_expect(
		Catalog.resolve_lod_path(entry, 2) == "res://mid.glb",
		"Far LOD did not fall back to Mid."
	)
	var inline_definition: Dictionary = {
		"id": "inline_test",
		"lod_scenes": {
			"near": "res://inline_near.tscn",
			"mid": "res://inline_mid.tscn",
		},
	}
	_expect(
		Resolver.resolve_scene_path(inline_definition, 1)
		== "res://inline_mid.tscn",
		"Inline authored LOD resolution failed."
	)


func _test_asset_transform() -> void:
	var definition: Dictionary = {
		"asset_transform": {
			"position": [0.0, 0.25, -0.5],
			"rotation": [0.0, 90.0, 0.0],
			"scale": [0.5, 0.5, 0.5],
		}
	}
	var transform: Dictionary = Resolver.get_asset_transform(definition)
	_expect(
		(transform.get("position", Vector3.ZERO) as Vector3).is_equal_approx(
			Vector3(0.0, 0.25, -0.5)
		),
		"Authored asset position correction failed."
	)
	_expect(
		(transform.get("scale", Vector3.ONE) as Vector3).is_equal_approx(
			Vector3(0.5, 0.5, 0.5)
		),
		"Authored asset scale correction failed."
	)


func _test_validation() -> void:
	var invalid: Array[String] = Catalog.validate_asset_entry({
		"kind": "environment_tree",
		"lod": {"near": "res://missing.glb"},
	}, false)
	_expect(not invalid.is_empty(), "Asset validation accepted an entry without asset_id.")
	var unknown_definition: Dictionary = {
		"id": "test_part",
		"asset_id": "not_registered",
	}
	_expect(
		not Resolver.validate_definition(unknown_definition).is_empty(),
		"Assembly asset resolver accepted an unknown asset_id."
	)


func _test_source_art_isolated() -> void:
	_expect(
		FileAccess.file_exists("res://art/source/.gdignore"),
		"Editable source-art tree is not protected by .gdignore."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Asset Pipeline test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
