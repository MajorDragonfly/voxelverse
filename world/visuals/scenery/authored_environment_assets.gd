extends RefCounted

const Catalog = preload("res://assets/catalog/asset_catalog.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const PaletteShader = preload("res://assets/catalog/planet_foliage.gdshader")

static var _meshes: Dictionary = {}
static var _bindings: Dictionary = {}
static var _materials: Dictionary = {}
static var _planet_seed: int = -1
static var _requests: Dictionary = {}
static var _load_frame: int = -1


static func prepare_lods(asset_id: String, geometry_variant: int) -> bool:
	var entry: Dictionary = Catalog.get_asset(asset_id)
	var lods: Dictionary = entry.get("geometry_variants", {}).get(str(geometry_variant), entry.get("lod", {}))
	var frame: int = Engine.get_process_frames()
	for tier: String in ["near", "mid", "far"]:
		var path: String = str(lods.get(tier, ""))
		if path.is_empty() or _meshes.has(path) or not ResourceLoader.exists(path):
			continue
		if not _requests.has(path):
			_requests[path] = frame
			return false
		if frame <= int(_requests[path]) or _load_frame == frame:
			return false
		# Imported scenes allocate renderer resources. Keep those allocations on
		# the main thread, with one cold resource per frame across every chunk.
		_load_frame = frame
		var scene := load(path) as PackedScene
		_cache_scene_mesh(path, scene)
		_requests.erase(path)
		return false
	return true


static func finish_pending_loads() -> void:
	# Loads are atomic main-thread steps; pending entries have not started and
	# can be cancelled without spawning work while a world is being torn down.
	_requests.clear()


static func _cache_scene_mesh(path: String, scene: PackedScene) -> Mesh:
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	var mesh: Mesh = _find_mesh(instance)
	instance.free()
	if mesh != null:
		_meshes[path] = mesh
	return mesh


static func get_mesh(asset_id: String, tier: int, geometry_variant: int = 0) -> Mesh:
	var key: String = "%s/%s/%s" % [asset_id, geometry_variant, tier]
	if _bindings.has(key):
		return _bindings[key]
	var mesh: Mesh = resolve_mesh(Catalog.get_asset(asset_id), tier, geometry_variant)
	if mesh != null:
		_bindings[key] = mesh
	return mesh


static func resolve_mesh(entry: Dictionary, tier: int, geometry_variant: int = 0) -> Mesh:
	var variants: Dictionary = entry.get("geometry_variants", {})
	var lods: Dictionary = variants.get(str(geometry_variant), entry.get("lod", {}))
	# Try the requested tier, then the closest higher-detail valid resource.
	var names: Array[String] = ["near", "mid", "far"]
	for candidate in range(clampi(tier, 0, 2), -1, -1):
		var path: String = str(lods.get(names[candidate], ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		if _meshes.has(path):
			return _meshes[path]
		var scene := load(path) as PackedScene
		var mesh: Mesh = _cache_scene_mesh(path, scene)
		_requests.erase(path)
		if mesh != null:
			return mesh
	return null


static func get_material(profile: Dictionary, species: Dictionary) -> ShaderMaterial:
	var seed_value: int = int(profile.get("planet_seed", 0))
	if _planet_seed != seed_value:
		_materials.clear()
		_planet_seed = seed_value
	var key: String = str(species.get("species_id", "default"))
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = PaletteShader
	material.set_shader_parameter("planet_palette", Slots.create_texture(species.get("palette", profile.get("material_slots", {}))))
	if "rock" in str(species.get("family_id", "")):
		material.set_shader_parameter("wind_strength", 0.0)
	_materials[key] = material
	return material


static func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var mesh: Mesh = _find_mesh(child)
		if mesh != null:
			return mesh
	return null


static func get_cache_counts() -> Dictionary:
	return {"meshes": _meshes.size(), "materials": _materials.size()}
