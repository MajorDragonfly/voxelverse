extends SceneTree
## Native geometry and actual food/home nodes: deterministic restart, streaming
## identity, harvest/regrowth without collider replacement, and exposed faces.
const Visuals = preload("res://world/visuals/scenery/resource_visual_factory.gd")
const Voxels = preload("res://world/visuals/scenery/resource_voxel_mesh.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fingerprint(mesh: ArrayMesh) -> String:
	return var_to_bytes(mesh.surface_get_arrays(0)).hex_encode().sha256_text()

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	var profile: Dictionary = Profile.terrain_profile(15838)
	var signatures: Array = []
	var shapes: Dictionary = {}
	for seed_value in range(12):
		var a: Dictionary = Visuals.forage(seed_value, 0.75, 1.0, 8, 0.25, 0.12, profile, "forest")
		shapes[a.form] = true
		signatures.append(fingerprint(a.foliage))
		check(a.fruit.get_surface_count() == 1, "Every edible form needs visible fruit: " + str(seed_value))
		var bounds: AABB = a.foliage.get_aabb()
		check(bounds.size.y > 0.15 and bounds.size.y < 1.35 and bounds.size.x < 1.6 and bounds.size.z < 1.6, "Unexpected plant bounds")
		check(a.foliage.surface_get_array_index_len(0) < a.occupied_cells*36, "Hidden faces were not removed")
	check(shapes.size() == 6, "Missing distinct silhouettes")
	var unique: Dictionary = {}
	for signature: String in signatures: unique[signature] = true
	check(unique.size() == 12, "Instances reuse the same geometry")
	var other: Dictionary = Visuals.forage(0, 0.75, 1.0, 8, 0.25, 0.12, Profile.terrain_profile(63352), "savanna")
	check(fingerprint(other.foliage) != signatures[0], "Planet/biome palette is not connected")
	var nest_mesh: ArrayMesh = Visuals.nest(42,1.25,0.25,24,2,0.12,profile,"forest")
	signatures.append(fingerprint(nest_mesh))
	check(nest_mesh.get_aabb().size.y > 0.3 and nest_mesh.get_aabb().size.y < 0.7, "Nest lost its shallow bowl")
	# Two touching cells have ten external faces, not twelve boxes' faces.
	var grid := {Vector3i.ZERO: Color.WHITE, Vector3i.RIGHT: Color.WHITE}
	var mesh: ArrayMesh = Voxels.build(grid, Vector3.ONE)
	check(mesh.surface_get_array_index_len(0) == 60, "Grid includes an internal face")
	var arrays: Array = mesh.surface_get_arrays(0)
	# Anchor the convention in Godot's own primitive, not in this mesher.
	# Godot front faces wind clockwise, opposite to (b-a) cross (c-a).
	var native: Array = BoxMesh.new().get_mesh_arrays()
	var native_indices: PackedInt32Array = native[Mesh.ARRAY_INDEX]
	var native_vertices: PackedVector3Array = native[Mesh.ARRAY_VERTEX]
	var native_a: int = native_indices[0]
	var native_winding: float = (native_vertices[native_indices[1]]-native_vertices[native_a]).cross(native_vertices[native_indices[2]]-native_vertices[native_a]).dot(native[Mesh.ARRAY_NORMAL][native_a])
	check(native_winding < 0.0, "Unexpected Godot primitive front-face convention")
	for i in range(0,arrays[Mesh.ARRAY_INDEX].size(),3):
		var a: int = arrays[Mesh.ARRAY_INDEX][i]
		var b: int = arrays[Mesh.ARRAY_INDEX][i+1]
		var c: int = arrays[Mesh.ARRAY_INDEX][i+2]
		var winding: float = (arrays[Mesh.ARRAY_VERTEX][b]-arrays[Mesh.ARRAY_VERTEX][a]).cross(arrays[Mesh.ARRAY_VERTEX][c]-arrays[Mesh.ARRAY_VERTEX][a]).dot(arrays[Mesh.ARRAY_NORMAL][a])
		check(winding * native_winding > 0.0, "Resource front face disagrees with Godot BoxMesh")
	var holder := Node3D.new()
	root.add_child(holder)
	var bush: Node3D = load("res://world/resources/plants/berry_bush.tscn").instantiate()
	bush.snap_to_terrain = false
	bush.persistent_food_key = "visual-test:body-a:plant-1"
	bush.visual_profile = profile
	holder.add_child(bush)
	await process_frame
	await process_frame
	var original_mesh: ArrayMesh = bush.bush_mesh.mesh
	var original_collision: Shape3D = bush.bush_collision.shape
	var original_fruit: ArrayMesh = bush.fruit_mesh.mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = bush._get_visual_seed()
	var radius: int = maxi(2, bush.bush_radius_voxels+rng.randi_range(-1,1))
	var height: int = maxi(2, bush.bush_height_voxels+rng.randi_range(-1,1))
	check(original_collision.size.is_equal_approx(Vector3(radius*2*0.25*0.72,height*0.25*0.85,radius*2*0.25*0.72)), "Existing saved food collider dimensions changed")
	var food: Dictionary = bush._entry()
	food.remaining = 0.0
	food.regrow_at = root.get_node("GameState").campaign.data.elapsed_seconds + bush.REGROW_SECONDS
	bush._sync_visual()
	check(not bush.fruit_mesh.visible and not bush.has_food_available(), "Depleted stock still shows berries")
	bush.global_position += Vector3(12000,-9000,4000)
	bush._generate_bush()
	check(bush.bush_mesh.mesh == original_mesh and bush.bush_collision.shape == original_collision, "Rebase/harvest rebuilt the plant or collider")
	root.get_node("GameState").campaign.data.elapsed_seconds += bush.REGROW_SECONDS + 1.0
	bush._sync_visual()
	check(bush.fruit_mesh.visible and bush.has_food_available() and bush.fruit_mesh.mesh == original_fruit, "Regrowth rebuilt fruit or lost its stock")
	var nest: Node3D = load("res://world/resources/nests/nest.tscn").instantiate()
	nest.snap_to_terrain = false
	nest.persistent_visual_key = "body-a:nest"
	nest.visual_profile = profile
	# Keep home/tribe gameplay out of this isolated mesh check; real consumers
	# run in the existing spherical campaign and home progression acceptance.
	for child_name in ["HomeGroup","Tribe","PlantFoodStreamer"]: nest.get_node(child_name).free()
	holder.add_child(nest)
	await process_frame
	var before: String = fingerprint(nest.nest_mesh.mesh)
	nest.position = Vector3(12000,4000,-5000)
	nest.basis = Basis(Vector3.FORWARD, PI*0.5)
	nest._generate_nest()
	check(fingerprint(nest.nest_mesh.mesh) == before, "Home appearance changed after radial origin shift")
	check(nest.get_respawn_position().is_equal_approx(nest.to_global(Vector3.UP*nest.respawn_height)), "Respawn marker lost radial orientation")
	nest.persistent_visual_key = "body-b:nest"
	nest._generate_nest()
	check(fingerprint(nest.nest_mesh.mesh) != before, "Different body has the same nest")
	holder.free()
	if "--resource-restart" in OS.get_cmdline_user_args():
		var saved: Array = JSON.parse_string(FileAccess.get_file_as_string("user://resource_visuals.json"))
		check(saved == signatures, "Visuals changed across a fresh Godot process")
	else:
		var file := FileAccess.open("user://resource_visuals.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(signatures))
		file.close()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/resource_visuals_test.gd","--","--resource-restart"],output,true)
		check(status == 0 and str(output).contains("RESOURCE_VISUALS_PASSED") and not str(output).contains("SCRIPT ERROR"), "Native restart failed: " + str(output))
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("RESOURCE_VISUALS_PASSED: six forms, twelve identities, cold restart, palette, food lifecycle and radial nest")
	await preload("res://core/runtime_shutdown.gd").finish(self,0 if failures.is_empty() else 1)
