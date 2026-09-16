extends SceneTree
## Geometric regression: every eye piece fits its own aperture for all four
## families, mirrored/non-uniform authoring, blink frames, gaze and rebuilds.
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Eyes = preload("res://creatures/runtime/creature_eye_expression.gd")
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
var failures: Array[String] = []
var checks: int = 0
var minimum_depth_gap: float = INF
var minimum_aperture_gap: float = INF

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	_families()
	_blink()
	await _lifecycle()
	print(JSON.stringify({"test": "creature_eye_expression", "checks": checks,
		"minimum_depth_gap": minimum_depth_gap, "minimum_aperture_gap": minimum_aperture_gap,
		"passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _families() -> void:
	for id: String in ["eyes_beady", "eyes_wide", "eyes_stalks", "eyes_cluster"]:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.5, 1.6, 0.75), Vector3(1.8, 0.45, 1.4)]:
			for side: float in [-1.0, 1.0]:
				var host := Node3D.new()
				root.add_child(host)
				host.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
				var part := Node3D.new()
				host.add_child(part)
				part.transform = Transform3D(Basis.from_euler(Vector3(0.2, side * 0.4, -0.3)).scaled(Vector3(0.8, 1.2, 1.0)), Vector3(0.1, 0.4, -0.2))
				part.set_meta("creature_part_category", "eyes")
				part.set_meta("part_shape", shape)
				part.set_meta("creature_part_side", side)
				var design: Dictionary = Assembly.create_default()
				Geometry.build(part, {"id": id}, {"category": "eyes"}, design)
				var sockets: Array = part.get_meta("eye_expression_sockets", [])
				check(sockets.size() == (3 if id == "eyes_cluster" else 1), "Missing independent eye sockets: " + id)
				var rest: Transform3D = part.transform
				var stalk: Node3D = part.get_node_or_null("EyeStalk")
				var stalk_rest: Transform3D = stalk.transform if stalk != null else Transform3D.IDENTITY
				var node_count: int = part.get_child_count()
				var controller := Eyes.new()
				controller.bind(host)
				for frame in range(21):
					for yaw: float in [-0.3, 0.0, 0.3]:
						var pose := {"eye_open": float(frame) / 20.0, "look_yaw": yaw}
						controller.apply(pose)
						for eye: Dictionary in sockets: _check_eye(eye, float(frame) / 20.0)
						check(part.transform == rest, "Blink changed eye socket transform")
						if stalk != null: check(stalk.transform == stalk_rest, "Blink shortened or moved stalk")
						var first: Transform3D = sockets[0].parts[1].node.transform
						controller.apply(pose)
						check(sockets[0].parts[1].node.transform == first, "Gaze/closure accumulates")
				controller.apply({"eye_open": 10.0, "look_yaw": INF})
				for eye: Dictionary in sockets: _check_eye(eye, 1.0)
				controller.apply({"eye_open": NAN, "look_yaw": NAN})
				for eye: Dictionary in sockets: _check_eye(eye, 1.0)
				controller.apply({"eye_open": 0.9999})
				var almost_open: Transform3D = sockets[0].parts[0].node.transform
				controller.reset()
				var fully_open: Transform3D = sockets[0].parts[0].node.transform
				check(almost_open.origin.distance_to(fully_open.origin) < 0.001 and almost_open.basis.y.distance_to(fully_open.basis.y) < 0.001, "Pop at full opening")
				for eye: Dictionary in sockets:
					for piece: Dictionary in eye.parts: check(piece.node.transform.is_equal_approx(piece.rest) and piece.node.visible, "Reset did not restore eye")
				check(part.get_child_count() == node_count, "Blink allocates nodes")
				host.free()
				controller.unbind() # stale node references after actor deletion

func _check_eye(eye: Dictionary, opening: float) -> void:
	var upper: AABB = _lid_bounds(eye.upper)
	var lower: AABB = _lid_bounds(eye.lower)
	var mesh: AABB = eye.upper.multimesh.mesh.get_aabb()
	for index in range(eye.upper.multimesh.instance_count):
		var top: AABB = _instance_pose(eye.upper.multimesh, index) * mesh
		var bottom: AABB = _instance_pose(eye.lower.multimesh, index) * mesh
		check(top.position.y >= bottom.end.y - 0.000001, "Lids cross each other")
		if opening == 0.0:
			check(absf(top.position.y - bottom.end.y) < 0.000002, "Closed lid has a hole")
		if index > 0:
			var previous: AABB = _instance_pose(eye.upper.multimesh, index - 1) * mesh
			check(absf(top.position.x - previous.end.x) < 0.000002, "Gap between lid columns")
	for piece: Dictionary in eye.parts:
		var node: MeshInstance3D = piece.node
		check(node.transform.is_finite(), "Non-finite eye pose")
		if opening == 0.0:
			check(not node.visible, "Globe/iris/glint shows through closed lid")
			continue
		check(node.visible, "Open eye missing")
		var box: AABB = node.transform * node.mesh.get_aabb()
		var depth_gap: float = box.position.z - maxf(upper.position.z, lower.position.z)
		minimum_depth_gap = minf(minimum_depth_gap, depth_gap)
		check(depth_gap > 0.0, "Eye geometry pokes in front of brow/lid")
		var top: float = eye.white.end.y - eye.white.size.y * (1.0 - opening) * 0.75
		var bottom: float = eye.white.position.y + eye.white.size.y * (1.0 - opening) * 0.25
		var gap: float = minf(top - box.end.y, box.position.y - bottom)
		minimum_aperture_gap = minf(minimum_aperture_gap, gap)
		check(gap >= -0.000001, "Eye geometry crosses aperture edge")
		check(box.position.x >= upper.position.x and box.end.x <= upper.end.x, "Gaze escapes socket width")
		if piece.gaze:
			check(box.position.x >= eye.white.position.x and box.end.x <= eye.white.end.x, "Iris/glint escapes white")

func _instance_pose(mm: MultiMesh, index: int) -> Transform3D:
	# Inspect the actual submitted GPU buffer, as the existing batching test does.
	var buffer: PackedFloat32Array = mm.buffer
	var offset: int = index * 12
	return Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
		Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
		Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])),
		Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11]))

func _lid_bounds(lid: MultiMeshInstance3D) -> AABB:
	var bounds: AABB
	for index in range(lid.multimesh.instance_count):
		var box: AABB = _instance_pose(lid.multimesh, index) * lid.multimesh.mesh.get_aabb()
		bounds = box if index == 0 else bounds.merge(box)
	return bounds

func _blink() -> void:
	for hz in [30, 60, 120]:
		for seed_value in [0, 5, 42, 71]:
			var emotion := Emotion.new()
			emotion.configure(seed_value)
			var closed: int = 0
			for frame in range(hz * 7):
				var pose: Dictionary = emotion.advance(1.0 / hz, {"intent": "flee"})
				if pose.eye_open == 0.0: closed += 1
				check(pose.eye_open >= 0.0 and pose.eye_open <= 1.0, "Emotion enlarges globe beyond socket")
			check(closed > 0, "No full blink at %d Hz seed %d" % [hz, seed_value])

func _lifecycle() -> void:
	var design: Dictionary = Assembly.create_default()
	Assembly.BaseBlueprint.add_part(design, "eyes_stalks")
	Assembly.BaseBlueprint.add_part(design, "eyes_cluster")
	Anatomy.reset_all_anchors(design)
	var original: String = var_to_str(design)
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		preview.set_expression_pose({"eye_open": 0.0, "look_yaw": 0.3})
		preview._process(0.1)
		check(not preview._motion._eyes._eyes.is_empty(), "Preview did not bind eyes")
		for eye: Dictionary in preview._motion._eyes._eyes: _check_eye(eye, 0.0)
		var pupils: Array[Dictionary] = []
		for eye: Dictionary in preview._motion._eyes._eyes: pupils.append_array(eye.parts)
		preview.set_motion("edit")
		for piece: Dictionary in pupils: check(piece.node.visible and piece.node.transform.is_equal_approx(piece.rest), "Edit retains closed eyes")
	preview.set_motion("idle")
	preview.set_process(false)
	preview.set_expression_pose({"eye_open": 0.0})
	preview._process(0.1)
	preview.rebuild()
	preview.set_process(false)
	preview.set_expression_pose({"eye_open": 0.5, "look_yaw": -0.3})
	preview._process(0.1)
	for eye: Dictionary in preview._motion._eyes._eyes: _check_eye(eye, 0.5)
	check(var_to_str(design) == original, "Eye animation altered blueprint")
	preview.free()
	await process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not failures.has(message): failures.append(message)
