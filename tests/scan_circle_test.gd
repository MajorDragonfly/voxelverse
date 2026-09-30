extends SceneTree
## The production scanner follows visible animated meshes, not an empty capsule.
const Geometry = preload("res://core/discovery/scan_circle_geometry.gd")
const Nest = preload("res://world/resources/nests/wildlife_nest.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	# Separate broad-phase checks do not prove that a mesh is visible.
	_check(not Geometry.contact(Vector2.ZERO, 26, Vector2(58.5, 0), Vector2(58.5, 0), 33, 33).is_empty(), "A half-pixel broad-phase overlap was lost")
	_check(Geometry.contact(Vector2.ZERO, 26, Vector2(60, 0), Vector2(60, 0), 33, 33).is_empty(), "A separated broad-phase silhouette overlapped")
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
	await _frames()
	player.toggle_inspection_mode()
	var visibility: RefCounted = load("res://tools/scanner_visibility_cases.gd").new()
	var evidence: Dictionary = await visibility.run(self, player)
	for failure: String in evidence.failures: failures.append(failure)
	print("SCAN_VISIBLE_MOTION_EVIDENCE ", JSON.stringify(evidence))
	var nest: Node3D = Nest.new()
	root.add_child(nest)
	nest.global_position = player.global_position + Vector3(0, 0, -4)
	nest.setup({"id": "circle-nest", "name": "Steinrücken", "seed": 17}, {}, "grassland")
	player._gameplay_camera.look_at(nest.global_position + Vector3.UP * 0.45)
	await _frames()
	_check(scanner.get_scan_target() == nest, "Nest did not use the same drawn circle")
	nest.global_position = player.global_position + Vector3(0, 0, 4)
	await _frames()
	_check(scanner.get_scan_target() == null, "Nest behind the camera was scanned")
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("SCAN_CIRCLE_PASSED")
	nest.queue_free()
	player.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _frames() -> void:
	for tick in range(3): await physics_frame; await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
