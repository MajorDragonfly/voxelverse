extends SceneTree
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Library = preload("res://creatures/editor/creature_part_library.gd")
const Joints = preload("res://creatures/runtime/creature_part_articulation.gd")
const Mouths = preload("res://creatures/editor/creature_mouth_geometry.gd")
const Hands = preload("res://creatures/editor/creature_hand_geometry.gd")
const SAVE: String = "user://articulation_restart.json"
const MOUTHS: Array[String] = ["mouth_grazer", "mouth_broad_beak", "mouth_predator_jaws",
	"mouth_filter_snout", "mouth_canine_snout", "mouth_crocodile_snout", "mouth_octopus_beak"]
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	if "--restart" in OS.get_cmdline_user_args():
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://articulation_expected.json"))
		var loaded: Dictionary = Assembly.load_from_file(SAVE)
		check(_saved_fingerprint(loaded) == expected.hash,
			"Fresh process changed saved identity, transformations or appearance")
		await _preview_lifecycle(loaded)
	else:
		_geometry_contract()
		_action_contract()
		await _preview_lifecycle(_design())
		await _gameplay_actions()
		var design: Dictionary = _design()
		check(Assembly.save_to_file(design, SAVE) == OK, "Design save failed")
		var file := FileAccess.open("user://articulation_expected.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"hash": _saved_fingerprint(design)}))
		file.close()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_part_articulation_test.gd", "--", "--restart"], output, true)
		check(status == 0 and str(output).contains("ARTICULATION_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"),
			"Restart failed: " + str(output))
	for failure: String in failures: push_error(failure)
	print(("ARTICULATION_RESTART_PASSED" if "--restart" in OS.get_cmdline_user_args() else "ARTICULATION_PASSED")
		+ " " + JSON.stringify({"checks": checks, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _model(id: String, shape: Vector3, side: float) -> Node3D:
	var model := Node3D.new()
	model.set_meta("creature_part_side", side)
	if id.begins_with("mouth_"):
		Geometry.build(model, Library.get_part(id), {"category": "mouth", "shape_scale": shape}, Assembly.create_default())
	else:
		model.set_meta("part_shape", shape)
		Geometry._terminal(model, id, Color.WHITE, Color.WHITE)
	return model


func _geometry_contract() -> void:
	for id: String in MOUTHS + ["hands_crab_claws", "hands_pincers"]:
		check(Mouths.articulation(id, 999).is_empty() and Hands.articulation(id, 999).is_empty(), "Future joints silently downgraded")
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			var left: Node3D = _model(id, shape, 1.0)
			var right: Node3D = _model(id, shape, -1.0)
			var first := Joints.new()
			var second := Joints.new()
			first.bind(left)
			second.bind(right)
			check(first.debug_state().joints > 0, "No joint for " + id)
			var rest: Dictionary = {}
			for mesh: MeshInstance3D in left.get_children(): rest[mesh.name] = mesh.transform
			var original_count: int = left.get_child_count()
			for amount: float in [0.0, 0.25, 0.5, 1.0, 0.15, 1.0]:
				first.set_pose(amount, amount)
				second.set_pose(amount, amount)
				var changed: int = 0
				for mesh: MeshInstance3D in left.get_children():
					var mirrored: MeshInstance3D = right.get_node(NodePath(str(mesh.name)))
					check(mesh.transform.is_finite() and mirrored.transform.is_finite(), "Nonfinite joint transform")
					check((mesh.position * Vector3(-1, 1, 1)).is_equal_approx(mirrored.position), "Joint center did not reflect: " + id + "/" + str(mesh.name))
					if str(mesh.name).contains("Tooth") or str(mesh.name).contains("Tip") or str(mesh.name).contains("Finger"):
						check((mesh.basis.y * Vector3(-1, 1, 1)).is_equal_approx(mirrored.basis.y), "Joint direction did not reflect: " + id + "/" + str(mesh.name))
					check(mesh.basis.determinant() > 0.99 and mesh.basis.determinant() < 1.01, "Joint deformed its mesh")
					if not mesh.transform.is_equal_approx(rest[mesh.name]): changed += 1
				check(amount == 0.0 or changed > 0, "Opening does not move visible anatomy: " + id)
				check(left.get_child_count() == original_count, "Per-pose scene allocation")
				if id == "mouth_crocodile_snout":
					check(left.get_node("LowerJaw").position.y <= rest.LowerJaw.origin.y + 0.00001, "Lower jaw opens into upper jaw")
					check(left.get_node("SnoutBridge").transform == rest.SnoutBridge, "Upper snout moved with lower jaw")
				if id == "hands_crab_claws":
					check(left.get_node("FixedTip").position.x <= rest.FixedTip.origin.x + 0.00001, "Fixed claw closes inward")
					check(left.get_node("MovableTip").position.x >= rest.MovableTip.origin.x - 0.00001, "Movable claw closes inward")
			first.reset()
			for mesh: MeshInstance3D in left.get_children(): check(mesh.transform == rest[mesh.name], "Rest transform drifted")
			# Rebinding while posed first restores the authored reference.
			first.set_pose(1, 1)
			first.bind(left)
			for mesh: MeshInstance3D in left.get_children(): check(mesh.transform == rest[mesh.name], "Rebind adopted an animated rest pose")
			left.free()
			right.free()
			first.reset()
			second.unbind()
	check(Mouths.articulation("mouth_future").is_empty() and Hands.articulation("hands_future").is_empty(), "Unknown joint profile accepted")


func _action_contract() -> void:
	var peaks: Array[float] = []
	for fps: int in [30, 60, 144]:
		var model: Node3D = _model("mouth_crocodile_snout", Vector3.ONE, 1)
		var motion := Joints.new()
		motion.bind(model)
		var rest: Transform3D = model.get_node("LowerJaw").transform
		check(motion.play("bite"), "Bite rejected")
		var peak: float = 0.0
		for frame in range(fps * 2):
			motion.advance(1.0 / fps)
			peak = maxf(peak, motion.debug_state().mouth)
		check(model.get_node("LowerJaw").transform == rest and not motion.is_active(), "Bite did not settle exactly")
		peaks.append(peak)
		motion.play("eat")
		motion.advance(0.12)
		var before: Transform3D = model.get_node("LowerJaw").transform
		motion.play("bite")
		check(model.get_node("LowerJaw").transform == before, "Interrupt snapped the mesh immediately")
		check(not motion.play("eat"), "Eating interrupted bite")
		check(not motion.play("fly") and not motion.play("bite", NAN), "Invalid action accepted")
		motion.set_pose(NAN, INF)
		check(model.get_node("LowerJaw").transform == rest, "Invalid pose damaged the mesh")
		motion.set_pose(100.0, -30.0)
		check(motion.debug_state().mouth == 1.0 and motion.debug_state().grip == 0.0, "Pose limits ignored")
		model.free()
	check(peaks.min() > 0.7 and peaks.max() - peaks.min() < 0.08, "Frame rate materially changes bite opening")


func _design() -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	design.parts = []
	for id: String in ["legs_walker", "legs_walker", "legs_walker", "mouth_crocodile_snout", "arms_claws"]:
		Assembly.BaseBlueprint.add_part(design, id)
	Anatomy.reset_all_anchors(design)
	design.parts[3].rotation = Vector3(18, -23, 12)
	design.parts[3].shape_scale = Vector3(0.8, 1.1, 1.4)
	design.parts[4].end_part_id = "hands_crab_claws"
	design.parts[4].end_rotation = Vector3(18, -23, 12)
	design.parts[4].end_shape_scale = Vector3(0.8, 1.1, 1.4)
	Anatomy.rebind_all_parts(design)
	return design


func _preview_lifecycle(design: Dictionary) -> void:
	var frame := Node3D.new()
	root.add_child(frame)
	frame.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	frame.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var original: String = var_to_str(design)
	check(preview._articulation.debug_state().joints == 5, "Full body must have jaw and two joints per mirrored claw")
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for amount: float in [0.0, 0.5, 1.0, 0.0]:
			preview._process(0.1)
			var feet: Array[Vector3] = []
			for leg: Dictionary in preview._motion._legs: feet.append(leg.foot.global_position)
			preview.set_articulation_pose(amount, amount)
			for index in range(feet.size()): check(preview._motion._legs[index].foot.global_position == feet[index], "Jaw/grip moved planted feet")
	preview.set_motion("edit")
	check(not preview.is_processing(), "Edit mode still processes")
	preview.play_part_action("bite")
	preview.set_process(false)
	preview._process(0.1)
	preview.rebuild()
	check(preview._articulation.debug_state().mouth == 0.0 and not preview.is_processing(), "Rebuild kept stale action or mesh references")
	preview.play_part_action("eat")
	paused = true
	var paused_time: float = preview._articulation.debug_state().time
	for index in range(5): await process_frame
	check(preview._articulation.debug_state().time == paused_time, "Paused scene advances articulation")
	paused = false
	preview.reset_part_actions()
	check(var_to_str(design) == original, "Animation rewrote blueprint")
	frame.free()
	await process_frame


func _gameplay_actions() -> void:
	root.get_node("GameState").start_world_with_seed(12345)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	for index in range(3): await process_frame
	var preview: Preview = player.get_node("CreatureRuntimeVisual/BlueprintCreatureVisual")
	var animator: Node = player.get_node("AdaptiveLocomotionAnimator")
	animator.set_physics_process(false)
	animator._bind_runtime_visual()
	player.current_hunger = 25.0
	player.diet_plant = 2.0
	check(player.consume_food("plant", 10.0), "Valid meal failed")
	check(preview._articulation.debug_state().action == "eat", "Successful meal did not animate")
	preview.reset_part_actions()
	player.current_hunger = player.maximum_hunger
	check(not player.consume_food("plant", 10.0) and preview._articulation.debug_state().action == "", "Rejected meal animated")
	player._trigger_bite_animation()
	check(preview._articulation.debug_state().action == "bite", "Player animator did not trigger joints")
	var wildlife: Node = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	wildlife.configure(2771337, 42, Vector2i.ZERO, "predator")
	root.add_child(wildlife)
	wildlife.set_physics_process(false)
	for index in range(2): await process_frame
	wildlife.position = player.position + Vector3(0, 0, -1.0)
	preview.reset_part_actions()
	player._bite_cooldown_timer = 0.0
	player.set_physics_process(true)
	check(player.perform_bite_on_target(wildlife), "Actual player bite failed")
	check(preview._articulation.debug_state().action == "bite", "Accepted attack did not animate")
	preview.reset_part_actions()
	check(not player.perform_bite_on_target(wildlife) and preview._articulation.debug_state().action == "", "Rejected repeated attack animated")
	player.set_physics_process(false)
	wildlife._intent = "chase"
	wildlife._warning = 0.0
	wildlife._ignore_player = false
	wildlife._attack_timer = 0.0
	var health_before: float = player.current_health
	wildlife._try_predator_attack(player)
	check(wildlife._bite_target != null and wildlife._preview._articulation.debug_state().action != "bite" and player.current_health == health_before, "Predator skipped its cancellable wind-up")
	# The living-creature controller lands its bite after the warning motion.
	# Advance the real controller while this fixture holds both actors in place.
	for tick in range(20): wildlife._physics_process(1.0 / 60.0)
	check(wildlife._preview._articulation.debug_state().action == "bite", "Predator attack did not animate")
	check(player.current_health < health_before, "Predator bite animated without damage")
	wildlife._die()
	check(wildlife._preview._articulation.debug_state().action == "", "Death retained an attack")
	wildlife.free()
	player.free()
	await process_frame


func _saved_fingerprint(design: Dictionary) -> String:
	# Compare the full saved reference contract, including terminals. Parsing
	# both sides canonicalizes equivalent JSON schema numbers (1 versus 1.0).
	return JSON.stringify(JSON.parse_string(JSON.stringify(Assembly.serialize_snapshot(design)))).sha256_text()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value and message not in failures: failures.append(message)
