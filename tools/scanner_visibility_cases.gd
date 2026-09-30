extends RefCounted
## The same moving, real animal cases run headless and in the render driver.
var failures: Array[String] = []
var measurements: Array[Dictionary] = []
var _tree: SceneTree
var _player: Node3D
var _camera: Camera3D
var _scanner: Node
var _capture: String
var _frame: int = 0
var _title: Label

func run(tree: SceneTree, player: Node3D, capture: String = "") -> Dictionary:
	_tree = tree
	_player = player
	_camera = player._gameplay_camera
	_scanner = player.get_node("CreatureScanner")
	_capture = capture
	if not capture.is_empty():
		DirAccess.make_dir_recursive_absolute(capture)
		_title = Label.new()
		_title.position = Vector2(16, 200)
		_title.add_theme_font_size_override("font_size", 18)
		_title.add_theme_color_override("font_shadow_color", Color.BLACK)
		_title.add_theme_constant_override("shadow_offset_x", 2)
		_tree.root.add_child(_title)
	var reticle: Control = player.get_node("HUD/CreatureScanReticle")
	var sizes: Array[Vector2i] = [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]
	var original_size: Vector2i = _tree.root.size
	var original_scale: float = _tree.root.content_scale_factor
	var original_fov: float = _camera.fov
	for size: Vector2i in sizes:
		_tree.root.size = size
		for scaling: float in [1.0, 1.25, 1.5]:
			_tree.root.content_scale_factor = scaling
			await _settle()
			for body_scale: float in [0.65, 1.35]:
				var animal: Node3D = _animal(2771337, 923)
				animal.scale = Vector3.ONE * body_scale
				animal.global_position = player.global_position + Vector3(0, 0, -5)
				await _settle()
				_camera.look_at(animal.global_position + Vector3.UP * 0.56 * body_scale)
				await _settle()
				var circle: Dictionary = player._scan_circle()
				var physical_factor: float = float(size.x) / _tree.root.get_visible_rect().size.x
				_align_edge(animal, circle.center + Vector2(-float(circle.radius) + 0.7 / physical_factor, 0))
				await _settle()
				_scanner.reset()
				var times: Array[float] = []
				var legacy_times: Array[float] = []
				var legacy_misses: int = 0
				var minimum_overlap: float = INF
				for tick in range(30):
					# Motion remains below one screen pixel of visible overlap. The
					# procedural runtime animation stays active throughout this case.
					var wanted: float = float(circle.center.x) - float(circle.radius) + (0.7 + sin(tick * 0.32) * 0.18) / physical_factor
					await _settle(1)
					_align_edge(animal, Vector2(wanted, circle.center.y))
					var legacy_start: int = Time.get_ticks_usec()
					if player.get_scan_target() != animal: legacy_misses += 1
					legacy_times.append((Time.get_ticks_usec() - legacy_start) / 1000.0)
					_scanner._physics_process(1.0 / 30.0)
					times.append(_scanner.last_query_usec / 1000.0)
					_check(_scanner.target == animal, "Moving visible edge lost target at %s scale %.2f body %.2f tick %d" % [size, scaling, body_scale, tick])
					if _scanner.target != null:
						_check(_scanner.target_pixel.distance_to(circle.center) <= float(circle.radius) + 0.01, "Marker escaped the drawn scan disc")
					minimum_overlap = minf(minimum_overlap, (_right_edge(animal).x - (float(circle.center.x) - float(circle.radius))) * physical_factor)
					await _record("Moving mesh edge / %s / UI %.0f%% / body %.2f" % [size, scaling * 100, body_scale])
				_check(_scanner.ratio() > 0.38, "Motion restarted progress for the same visible animal")
				measurements.append({"case": "moving_edge", "size": [size.x, size.y], "ui_scale": scaling, "body_scale": body_scale,
					"viewport": [_tree.root.get_visible_rect().size.x, _tree.root.get_visible_rect().size.y], "circle": {"center": circle.center, "radius": circle.radius},
					"minimum_overlap_px": minimum_overlap, "query_ms": _stats(times), "legacy_query_ms": _stats(legacy_times), "legacy_misses": legacy_misses, "progress": _scanner.ratio()})
				print("SCAN_MATRIX_CASE ", JSON.stringify(measurements.back()))
				animal.queue_free()
				await _settle()
	_tree.root.size = Vector2i(1280, 720)
	_tree.root.content_scale_factor = 1.0
	await _settle()
	var first: Node3D = _animal(2771337, 925)
	var second: Node3D = _animal(2871448, 926)
	first.global_position = player.global_position + Vector3(-0.45, 0, -5)
	second.global_position = player.global_position + Vector3(0.45, 0, -5)
	_camera.look_at(player.global_position + Vector3(0, 0.6, -5))
	await _settle()
	_scanner.reset()
	var switches: int = 0
	var last: Node3D
	for tick in range(40):
		first.position.x = player.position.x - 0.45 + sin(tick * 0.3) * 0.025
		second.position.x = player.position.x + 0.45 - sin(tick * 0.3) * 0.025
		await _settle(1)
		_scanner._physics_process(1.0 / 30.0)
		if last != null and _scanner.target != last: switches += 1
		last = _scanner.target
		await _record("Two moving competitors / stable visible selection")
	_check(last != null and switches == 0, "Two similarly placed moving animals flickered selection: %d" % switches)
	var original: Node3D = last
	var other: Node3D = second if original == first else first
	original.global_position.x += 30.0
	_camera.look_at(other.global_position + Vector3.UP * 0.56)
	await _settle()
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == other and _scanner.ratio() < 0.02, "Individual switch inherited scan progress")
	await _record("Target switch / progress starts from zero")
	_camera.rotate_y(0.8)
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == null and _scanner.ratio() == 0.0, "One-frame sight loss retained progress")
	await _record("Brief sight loss / no target and zero progress")
	_camera.look_at(other.global_position + Vector3.UP * 0.56)
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == other and _scanner.ratio() < 0.02, "Reacquisition inherited old progress")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 6, 0.4)
	collision.shape = shape
	wall.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	wall.add_child(mesh)
	_tree.root.add_child(wall)
	wall.global_position = _camera.global_position.lerp(other.global_position + Vector3.UP * 0.56, 0.7)
	await _settle()
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == null and _scanner.ratio() == 0.0, "Completely occluded visual animal was scanned")
	await _record("Full wall occlusion / scan is blocked")
	wall.queue_free()
	await _settle()
	other.get_node("SpeciesVisual").hide()
	var legacy_hidden_hit: bool = player.get_scan_target() == other
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == null, "Invisible movement capsule invented a visible animal")
	await _record("Hidden mesh / capsule cannot be scanned")
	other.get_node("SpeciesVisual").show()
	other.global_position = player.global_position + Vector3(0, 0, -float(player.inspection_radius) - 0.5)
	_camera.look_at(other.global_position + Vector3.UP * 0.56)
	await _settle()
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == null, "Rendered animal outside player inspection range was scanned")
	await _record("Outside inspection range / scan is blocked")
	other.global_position = player.global_position + Vector3(0, 0, -5)
	_camera.look_at(other.global_position + Vector3.UP * 0.56)
	for fov: float in [42.0, 88.0]:
		_camera.fov = fov
		await _settle()
		var fov_circle: Dictionary = player._scan_circle()
		_align_edge(other, fov_circle.center + Vector2(-float(fov_circle.radius) + 0.7, 0))
		_scanner._physics_process(1.0 / 30.0)
		_check(_scanner.target == other, "Visible mesh lost edge target at FOV %.0f" % fov)
		await _record("FOV %.0f / visible edge target" % fov)
	_tree.paused = true
	_scanner._physics_process(1.0 / 30.0)
	_check(_scanner.target == null and _scanner.ratio() == 0.0, "Pause retained visual scan progress")
	_tree.paused = false
	measurements.append({"case": "two_targets", "switches": switches, "short_loss": "reset", "full_occlusion": "blocked", "invisible_capsule": "blocked", "legacy_hidden_hit": legacy_hidden_hit, "range": "blocked", "fov": [42, 88], "pause": "reset"})
	first.queue_free()
	second.queue_free()
	if _title != null: _title.queue_free()
	_scanner.reset()
	_tree.root.size = original_size
	_tree.root.content_scale_factor = original_scale
	_camera.fov = original_fov
	await _settle()
	return {"failures": failures, "measurements": measurements, "captured_frames": _frame, "rendered": not _capture.is_empty()}

func _animal(species: int, individual: int) -> Node3D:
	var animal: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	animal.configure(species, individual, Vector2i.ZERO, "forager")
	_tree.root.add_child(animal)
	animal.set_physics_process(false)
	animal._preview.set_motion("walk")
	return animal

func _settle(count: int = 3) -> void:
	for tick in range(count):
		await _tree.physics_frame
		await _tree.process_frame

func _right_edge(animal: Node3D) -> Vector2:
	var right := Vector2(-INF, 0)
	for reference: WeakRef in _scanner.silhouette._visual_nodes(animal):
		var node: Node3D = reference.get_ref()
		if not node.is_visible_in_tree(): continue
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh
		var count: int = node.multimesh.instance_count if node is MultiMeshInstance3D else 1
		var transforms: Array[Transform3D] = []
		if node is MultiMeshInstance3D: transforms = _scanner.silhouette._batch_transforms(node, count)
		for index in range(count):
			var transform: Transform3D = node.global_transform * transforms[index] if node is MultiMeshInstance3D else node.global_transform
			for point: Vector3 in _scanner.silhouette._mesh_faces(mesh):
				var pixel: Vector2 = _camera.unproject_position(transform * point)
				if pixel.x > right.x: right = pixel
	return right

func _align_edge(animal: Node3D, wanted: Vector2) -> void:
	for iteration in range(3): _move_pixels(animal, wanted - _right_edge(animal))

func _move_pixels(animal: Node3D, offset: Vector2) -> void:
	var center: Vector3 = animal.global_position
	var pixel: Vector2 = _camera.unproject_position(center)
	var horizontal: float = _camera.unproject_position(center + _camera.global_basis.x).x - pixel.x
	var vertical: float = _camera.unproject_position(center + _camera.global_basis.y).y - pixel.y
	animal.global_position += _camera.global_basis.x * (offset.x / horizontal) + _camera.global_basis.y * (offset.y / vertical)

func _record(text: String) -> void:
	if _capture.is_empty(): return
	_title.text = "INT30-05 / " + text + "\nQuery: %.3f ms / scan: %.0f%%" % [_scanner.last_query_usec / 1000.0, _scanner.ratio() * 100.0]
	await _tree.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _tree.root.get_texture().get_image()
	if _frame % 30 == 0:
		var native: String = _capture.path_join("native")
		DirAccess.make_dir_recursive_absolute(native)
		_check(image.save_png(native.path_join("frame-%05d.png" % _frame)) == OK, "Native capture frame could not be saved")
	# A fixed output canvas avoids mixing video dimensions across the matrix.
	image.resize(1920, 1080)
	_check(image.save_png(_capture.path_join("frame-%05d.png" % _frame)) == OK, "Capture frame could not be saved")
	_frame += 1

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median": values[values.size() / 2], "p95": values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)], "max": values.back()}

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
