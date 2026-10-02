extends RefCounted
## A visible foreign actor's empty movement capsule is not visual occlusion.
class Obstruction extends CharacterBody3D:
	var is_dead := false
	func get_inspection_data() -> Dictionary: return {}
var failures: Array[String] = []
var capture := ""
var observer: Node3D
func run(tree: SceneTree, directory: String = "") -> Array[String]:
	capture = directory
	if not capture.is_empty(): DirAccess.make_dir_recursive_absolute(capture)
	var geometry: RefCounted = preload("res://core/discovery/scan_silhouette.gd").new()
	if geometry.has_method("_ray_mesh"):
		var plane := PlaneMesh.new()
		_expect(geometry._ray_mesh(plane, Transform3D.IDENTITY, Vector3(0, 1, 0), Vector3(0, -1, 0)), "A valid zero-coordinate mesh hit was treated as no intersection")
		_expect(not geometry._ray_mesh(plane, Transform3D.IDENTITY, Vector3(2, 1, 2), Vector3(2, -1, 2)), "A ray outside the mesh bounds invented occlusion")
	var root: Window = tree.root
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.autosave_enabled = false
	saves.create_slot("R32-05 visual occlusion", 15838, "legacy_plane_v9")
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	observer = player
	if not capture.is_empty(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.global_position = Vector3(0, 100, 0)
	player.fall_acceleration = 0
	var scanner: Node = player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	var animal: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	animal.configure(2771337, 911227, Vector2i.ZERO, "forager")
	root.add_child(animal)
	animal.set_physics_process(false)
	animal.global_position = player.global_position + Vector3(0, 0, -5)
	for tick in range(4): await tree.physics_frame; await tree.process_frame
	player._gameplay_camera.look_at(animal.global_position + Vector3.UP * 0.56)
	player.toggle_inspection_mode()
	_expect(scanner.get_scan_target() == animal, "Unobstructed production animal missing")
	await _capture(tree, "unobstructed")
	var obstruction := Obstruction.new()
	obstruction.collision_layer = 4
	obstruction.collision_mask = 0
	obstruction.add_to_group(&"wildlife")
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 2.5
	capsule.height = 6
	collider.shape = capsule
	obstruction.add_child(collider)
	var visual := Node3D.new()
	visual.name = "SpeciesVisual"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.2
	mesh.mesh = box
	mesh.position.x = 4
	visual.add_child(mesh)
	obstruction.add_child(visual)
	root.add_child(obstruction)
	obstruction.global_position = player._gameplay_camera.global_position.lerp(animal.global_position + Vector3.UP * 0.56, 0.6)
	for tick in range(3): await tree.physics_frame; await tree.process_frame
	_expect(scanner.get_scan_target() == animal, "Visible off-ray foreign mesh's empty capsule hid the target")
	await _capture(tree, "empty-foreign-capsule")
	# Cover every target triangle with real visible geometry; rejection survives.
	mesh.position = Vector3.ZERO
	var cover := BoxMesh.new()
	cover.size = Vector3(6, 6, 0.3)
	mesh.mesh = cover
	for tick in range(3): await tree.physics_frame; await tree.process_frame
	_expect(scanner.get_scan_target() != animal, "Real foreign animal geometry did not occlude the target")
	await _capture(tree, "real-foreign-geometry")
	# Move the entire query capsule out of the ray while retaining the same
	# visible cover at this pixel, as an animated limb outside its body collider.
	obstruction.position.x += 8
	mesh.position.x -= 8
	for tick in range(3): await tree.physics_frame; await tree.process_frame
	_expect(scanner.get_scan_target() != animal, "Foreign visible mesh outside its movement capsule failed to occlude")
	await _capture(tree, "foreign-geometry-outside-capsule")
	visual.hide()
	_expect(scanner.get_scan_target() == animal, "Hidden foreign body occluded a visible target")
	await _capture(tree, "hidden-foreign-geometry")
	obstruction.queue_free(); animal.queue_free()
	for tick in range(3): await tree.physics_frame; await tree.process_frame
	var nest: Node3D = preload("res://world/resources/nests/wildlife_nest.gd").new()
	root.add_child(nest)
	nest.global_position = player.global_position + Vector3(0, 0, -4)
	nest.setup({"id": "r32-visual-nest", "name": "Kieselrücken", "seed": 17}, {}, "grassland")
	player._gameplay_camera.look_at(nest.global_position + Vector3.UP * 0.45)
	for tick in range(3): await tree.physics_frame; await tree.process_frame
	_expect(scanner.get_scan_target() == nest, "Visible production nest was not scannable")
	await _capture(tree, "visible-nest")
	for child: Node in nest.get_children():
		if child is MeshInstance3D: child.hide()
	_expect(scanner.get_scan_target() == null, "Invisible nest's query cylinder invented a visible target")
	await _capture(tree, "hidden-nest")
	for child: Node in nest.get_children():
		if child is MeshInstance3D: child.show()
	_expect(scanner.get_scan_target() == nest, "Restored nest geometry remained unscannable")
	await _capture(tree, "restored-nest")
	nest.queue_free(); player.queue_free()
	await tree.process_frame
	print("R32_05_VISIBLE_OCCLUSION ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	return failures
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _capture(tree: SceneTree, name: String) -> void:
	if capture.is_empty() or DisplayServer.get_name() == "headless": return
	var scanner: Node = observer.get_node("CreatureScanner")
	scanner.target = scanner.get_scan_target()
	await tree.process_frame
	await RenderingServer.frame_post_draw
	_expect(tree.root.get_texture().get_image().save_png(capture.path_join(name + ".png")) == OK, "Regression capture write failed")
