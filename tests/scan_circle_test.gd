extends SceneTree
## The visible ring, real physical shapes and occlusion agree at its edge.
const Geometry = preload("res://core/discovery/scan_circle_geometry.gd")
const Nest = preload("res://world/resources/nests/wildlife_nest.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_check(not Geometry.contact(Vector2.ZERO, 26, Vector2(58.5, 0), Vector2(58.5, 0), 33, 33).is_empty(), "A half-pixel edge overlap was lost")
	_check(Geometry.contact(Vector2.ZERO, 26, Vector2(60, 0), Vector2(60, 0), 33, 33).is_empty(), "A separated silhouette counted as scanned")
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.autosave_enabled = false
	saves.create_slot("Scankreis", 15838, "legacy_plane_v9")
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 100, 0)
	player.fall_acceleration = 0.0
	var scanner: Node = player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	var creature: Node3D = _creature(player.global_position + Vector3(0, 0, -4), 921)
	await _frames()
	var camera: Camera3D = player._gameplay_camera
	camera.look_at(creature.global_position + Vector3.UP * 0.56)
	player.toggle_inspection_mode()
	await _frames()
	var ring: Dictionary = player._scan_circle()
	_check(player.get_scan_target() == creature, "Center of the real circle did not find the animal")
	var radius: float = _screen_radius(camera, creature.get_node("CollisionShape3D"))
	_move_to_screen(creature, creature.get_node("CollisionShape3D"), camera, ring.center + Vector2(float(ring.radius) + radius - 0.7, 0))
	await _frames()
	var projected: Vector2 = camera.unproject_position(creature.get_node("CollisionShape3D").global_position)
	_check(projected.distance_to(ring.center) > float(ring.radius), "Edge case still had its body center in the circle")
	var edge_contact: Dictionary = player._scan_contact(creature, ring)
	var edge_overlap: float = float(edge_contact.get("overlap", -100.0))
	_check(edge_overlap > 0.0 and edge_overlap < 1.5, "Physical edge case did not have subpixel overlap: " + str(edge_overlap))
	_check(player.get_scan_target() == creature, "Visible edge pixel did not acquire the physical animal")
	_check(player.last_scan_rays <= 2, "Edge scan used too many physics rays")
	var edge_rays: int = player.last_scan_rays
	var initial_ring: Dictionary = ring.duplicate()
	for tick in range(12): scanner._physics_process(0.1)
	_check(scanner.ratio() > 0.4, "Edge overlap did not accumulate scan progress")
	await _frames()
	var reticle: Control = player.get_node("HUD/CreatureScanReticle")
	_check(reticle.has_target and (reticle.get_global_transform_with_canvas() * reticle.target_pixel).distance_to(player.get_scan_target_pixel()) < 1.0, "Selected animal was not marked at its visible pixel")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.5)
	collider.shape = shape
	wall.add_child(collider)
	root.add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 1, -2)
	await _frames()
	scanner._physics_process(0.1)
	_check(scanner.target == null and scanner.ratio() == 0.0, "Wall did not interrupt the edge scan")
	wall.queue_free()
	await _frames()
	var second: Node3D = _creature(player.global_position + Vector3(0, 0, -5), 922)
	await _frames()
	scanner._physics_process(0.1)
	_check(scanner.target == second and scanner.ratio() < 0.05, "Switching to a centered animal carried progress")
	second.global_position = player.global_position + Vector3(12, 0, -5)
	await _frames()
	reticle.scale = Vector2.ONE * 1.5
	ring = player._scan_circle()
	_check(float(ring.radius) > 38.0, "UI scaling did not change the hit circle")
	_move_to_screen(creature, creature.get_node("CollisionShape3D"), camera, ring.center + Vector2(float(ring.radius) + radius - 2.0, 0))
	await _frames()
	_check(player.get_scan_target() == creature, "Scaled visual ring and scan area diverged")
	for fov: float in [42.0, 88.0]:
		camera.fov = fov
		await _frames()
		radius = _screen_radius(camera, creature.get_node("CollisionShape3D"))
		_move_to_screen(creature, creature.get_node("CollisionShape3D"), camera, ring.center + Vector2(float(ring.radius) + radius - 8.0, 0))
		await _frames()
		_check(player.get_scan_target() == creature, "FOV changed the visible scan edge: " + str(fov))
	camera.fov = 70.0
	for body_scale: float in [0.65, 1.35]:
		creature.scale = Vector3.ONE * body_scale
		await _frames()
		radius = _screen_radius(camera, creature.get_node("CollisionShape3D"))
		_move_to_screen(creature, creature.get_node("CollisionShape3D"), camera, ring.center + Vector2(float(ring.radius) + radius - 8.0, 0))
		await _frames()
		_check(player.get_scan_target() == creature, "Body size changed the visible scan edge: " + str(body_scale))
	creature.scale = Vector3.ONE
	var window_size: Vector2i = root.size
	root.size = Vector2i(1280, 720)
	await _frames()
	ring = player._scan_circle()
	radius = _screen_radius(camera, creature.get_node("CollisionShape3D"))
	_move_to_screen(creature, creature.get_node("CollisionShape3D"), camera, ring.center + Vector2(float(ring.radius) + radius - 8.0, 0))
	await _frames()
	_check(player.get_scan_target() == creature, "Resolution changed the scan edge")
	root.size = window_size
	await _frames()
	var nest: Node3D = Nest.new()
	root.add_child(nest)
	nest.global_position = player.global_position + Vector3(0, 0, -4)
	nest.setup({"id": "circle-nest", "name": "Steinrücken", "seed": 17}, {}, "grassland")
	creature.global_position = player.global_position + Vector3(12, 0, -4)
	await _frames()
	_check(player.get_scan_target() == nest, "Nest did not use the same circle")
	nest.global_position = player.global_position + Vector3(0, 0, 4)
	await _frames()
	_check(player.get_scan_target() == null, "Nest behind the camera was scanned")
	paused = true
	scanner._physics_process(0.1)
	_check(scanner.ratio() == 0.0, "Pause retained scan progress")
	paused = false
	print("SCAN_CIRCLE_EVIDENCE ", JSON.stringify({"edge_screen": projected, "edge_overlap": edge_overlap, "edge_rays": edge_rays, "initial_ring": initial_ring, "resized_ring": ring}))
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SCAN_CIRCLE_PASSED")
	nest.queue_free()
	creature.queue_free()
	second.queue_free()
	player.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _creature(position: Vector3, identity: int) -> Node3D:
	var animal: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	animal.configure(2771337, identity, Vector2i.ZERO, "forager")
	root.add_child(animal)
	animal.set_physics_process(false)
	animal.global_position = position
	return animal

func _screen_radius(camera: Camera3D, collider: CollisionShape3D) -> float:
	var center: Vector3 = collider.global_position
	return camera.unproject_position(center).distance_to(camera.unproject_position(center + camera.global_basis.x * collider.shape.radius * collider.global_basis.get_scale().x))

func _move_to_screen(target: Node3D, collider: CollisionShape3D, camera: Camera3D, screen: Vector2) -> void:
	var center: Vector3 = collider.global_position
	var pixel: Vector2 = camera.unproject_position(center)
	var horizontal: float = camera.unproject_position(center + camera.global_basis.x).x - pixel.x
	var vertical: float = camera.unproject_position(center + camera.global_basis.y).y - pixel.y
	target.global_position += camera.global_basis.x * ((screen.x - pixel.x) / horizontal) + camera.global_basis.y * ((screen.y - pixel.y) / vertical)

func _frames() -> void:
	for tick in range(3):
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
