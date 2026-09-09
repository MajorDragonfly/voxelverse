extends SceneTree
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Data = preload("res://assembly/core/creature_body_attachments.gd")
const Contract = preload("res://creatures/runtime/creature_body_contract.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Follower = preload("res://creatures/runtime/creature_body_attachment.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Adapter = preload("res://assembly/adapters/creature_assembly_adapter.gd")
const Factory = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Gait = preload("res://creatures/runtime/creature_gait_profile.gd")
const SAVE: String = "user://body_contract_restart.json"
var failures: Array[String] = []
var measurements: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--verify-body-restart" in OS.get_cmdline_user_args():
		_verify_restart()
	else:
		_check_legacy_and_invalid()
		for pairs in range(1, 4):
			_check_body(pairs)
		_check_roundtrip()
		_check_species()
		await _check_editor()
		var output: Array = []
		var status: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_body_contract_test.gd", "--", "--verify-body-restart"], output, true)
		_expect(status == 0 and str(output).contains("BODY_RESTART_PASSED") and not str(output).contains("SCRIPT ERROR"), "Fresh-process attachment reload failed: " + str(output))
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("BODY_RESTART_PASSED" if "--verify-body-restart" in OS.get_cmdline_user_args() else "CREATURE_BODY_CONTRACT_PASSED " + JSON.stringify(measurements))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func design(pairs: int) -> Dictionary:
	var blueprint: Dictionary = Assembly.create_default()
	blueprint["parts"] = []
	for index in range(pairs):
		Assembly.BaseBlueprint.add_part(blueprint, ["legs_walker", "legs_stubby", "legs_spider"][index])
	Anatomy.reset_all_anchors(blueprint)
	for index in range(pairs):
		var part: Dictionary = blueprint["parts"][index]
		part["anchor_t"] = 0.25 + index * 0.24
		part["scale"] = 0.8 + index * 0.24
		part["joint"] = {"upper": 1.35 + index * 0.1, "lower": 0.75, "offset": Vector3(0.1, 0.04, 0.12)}
		part["rotation"] = Vector3(8, -15, 12)
		part["end_part_id"] = "feet_claws" if index == 0 else "feet_hooves"
		part["end_rotation"] = Vector3(3, 14, -5)
	Anatomy.rebind_all_parts(blueprint)
	Assembly.normalize(blueprint)
	return blueprint


func _preview(blueprint: Dictionary, parent: Node = root) -> Preview:
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(blueprint, -1, -1, false)
	return preview


func _check_legacy_and_invalid() -> void:
	var blueprint: Dictionary = design(2)
	blueprint["assembly"].erase(Data.KEY)
	var before: String = JSON.stringify(blueprint)
	var result: Dictionary = Contract.describe(blueprint)
	_expect(result["attachment_source"] == "legacy_default" and result["sockets"].size() == 3, "Legacy design has no deterministic geometric defaults.")
	_expect(before == JSON.stringify(blueprint), "Read-only body contract changed legacy anatomy/IDs.")
	Assembly.normalize(blueprint)
	var migrated: String = JSON.stringify(blueprint)
	Assembly.normalize(blueprint)
	_expect(migrated == JSON.stringify(blueprint), "Attachment migration is not idempotent.")
	for payload in [{"schema": 99, "sockets": {}}, {"schema": 1, "sockets": []}, null]:
		blueprint["assembly"][Data.KEY] = payload
		var original: String = JSON.stringify(blueprint)
		Assembly.normalize(blueprint)
		_expect(JSON.stringify(blueprint) == original, "Unsupported payload was replaced.")
		_expect(not Contract.resolve(blueprint)["errors"].is_empty(), "Unsupported payload exposed sockets.")
	blueprint["assembly"][Data.KEY] = Data.defaults()
	for bad in [NAN, INF, "bad", -10.0, 40.0]:
		var data: Dictionary = Data.defaults()
		data["sockets"]["saddle.primary"]["t"] = bad
		_expect(not Data.validate(data).is_empty(), "Invalid spine parameter was accepted.")
	var missing: Dictionary = Data.defaults()
	missing["sockets"].erase("harness.left")
	_expect(not Data.validate(missing).is_empty(), "Missing authored socket silently regenerated.")
	var socket: Dictionary = Data.read(blueprint)["sockets"]["saddle.primary"]
	socket["offset"][1] = -0.3
	Data.set_socket(blueprint, "saddle.primary", socket)
	_expect(Contract.resolve(blueprint)["errors"].has("socket_inside_skin:saddle.primary"), "Buried attachment was exposed to equipment.")


func _check_body(pairs: int) -> void:
	var blueprint: Dictionary = design(pairs)
	var parent := Node3D.new()
	root.add_child(parent)
	# A large translated, tilted and scaled local surface frame, not world Y.
	parent.transform = Transform3D(Basis.from_euler(Vector3(1.1, -0.7, 0.35)).scaled(Vector3(1.3, 0.9, 1.15)), Vector3(1500, -700, 2300))
	var preview := _preview(blueprint, parent)
	var rest: Dictionary = Contract.inspect_rest(preview)
	_expect(rest["leg_count"] == pairs * 2 and rest["all_feet_on_plane"], "2/4/6-leg rest contact failed in tilted frame.")
	var before: String = JSON.stringify(blueprint)
	var follower := Follower.new()
	root.add_child(follower)
	follower.bind(preview, "saddle.primary")
	var body: Node3D = preview.get_node("BodyV4")
	var local: Transform3D = preview.body_socket("saddle.primary")["body_transform"]
	var maximum_gap: float = 0.0
	var minimum_support: int = pairs * 2
	var maximum_attachment_error: float = 0.0
	for mode in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for sample_index in range(25):
			preview._motion.sample(mode, float(sample_index) * 0.13)
			# Player bite posing also moves BodyV4 independently of the preview.
			body.rotation.x = sin(float(sample_index) * 0.2) * 0.15
			follower.sync_pose()
			var expected: Transform3D = body.global_transform * local
			maximum_attachment_error = maxf(maximum_attachment_error, follower.global_position.distance_to(expected.origin))
			_expect(follower.available and follower.global_basis.is_equal_approx(expected.basis), "Payload lost body rotation/scale.")
			var grounded: int = 0
			for rig: Dictionary in preview._motion.get("_legs"):
				var point: Vector3 = parent.to_local(rig["foot"].global_position)
				var gap: float = point.y - float(preview.get_meta("ground_y"))
				maximum_gap = maxf(maximum_gap, maxf(-gap, 0))
				if absf(gap) < 0.002:
					grounded += 1
			minimum_support = mini(minimum_support, grounded)
	_expect(maximum_gap < 0.002 and minimum_support >= pairs, "Moving soles penetrated radial plane or lost support.")
	_expect(maximum_attachment_error < 0.002, "Rider drifted from the moving body.")
	_expect(before == JSON.stringify(blueprint), "Animation baked world transforms into the design.")
	preview.set_motion("edit")
	preview.rebuild()
	follower.sync_pose()
	_expect(follower.available, "Rebuilding the preview lost the stable attachment ID.")
	var socket: Dictionary = Data.read(blueprint)["sockets"]["saddle.primary"]
	socket["enabled"] = false
	Data.set_socket(blueprint, "saddle.primary", socket)
	preview.rebuild()
	follower.sync_pose()
	_expect(not follower.available and not follower.visible, "Disabled attachment left a stale rider visible.")
	socket["enabled"] = true
	Data.set_socket(blueprint, "saddle.primary", socket)
	blueprint["body"]["scale"] = 1.6
	Assembly.SpineProfile.set_body_length_scale(blueprint, 1.7)
	preview.rebuild()
	follower.sync_pose()
	_expect(follower.available and not preview.body_socket("saddle.primary")["body_transform"].origin.is_equal_approx(local.origin), "Socket failed to follow reshaped body.")
	measurements.append({"legs": pairs * 2, "max_rest_gap": rest["max_contact_error"], "max_rest_stretch": rest["max_rest_stretch"],
		"max_penetration": maximum_gap, "minimum_support": minimum_support, "max_attachment_error": maximum_attachment_error})
	parent.free()
	follower.sync_pose()
	_expect(not follower.available, "Freed target left a stale body attachment.")
	follower.free()


func _check_roundtrip() -> void:
	var blueprint: Dictionary = design(3)
	var socket: Dictionary = Data.read(blueprint)["sockets"]["saddle.primary"]
	socket["t"] = 0.63
	socket["offset"] = [0.05, 0.12, 0.04]
	socket["rotation_degrees"] = [8.0, 17.0, -5.0]
	Data.set_socket(blueprint, "saddle.primary", socket)
	var stats: Dictionary = Assembly.BaseBlueprint.calculate_stats(blueprint)
	var contract: Dictionary = Contract.describe(blueprint)
	_expect(Assembly.save_to_file(blueprint, SAVE) == OK, "V7 save failed.")
	var loaded: Dictionary = Assembly.load_from_file(SAVE)
	_expect(_json_equal(Data.read(blueprint), Data.read(loaded)), "V7 save/load lost authored body sockets: %s -> %s" % [Data.read(blueprint), Data.read(loaded)])
	_expect(Contract.describe(loaded) == contract, "Reload changed the body contract geometry.")
	_expect(Assembly.BaseBlueprint.calculate_stats(loaded) == stats, "Attachment changed creature stats.")
	var observation: Dictionary = Records.observation(blueprint, "contract-test")
	var visual: Dictionary = Records.visual_for({"journal": JSON.parse_string(JSON.stringify(observation))})
	_expect(_json_equal(Data.read(visual), Data.read(blueprint)), "Journal JSON lost the attachment payload.")
	_expect(Adapter.to_modular_blueprint(blueprint)["metadata"][Data.KEY] == Data.read(blueprint), "Modular adapter omitted body attachments.")
	var witness := FileAccess.open("user://body_contract_expected.json", FileAccess.WRITE)
	witness.store_string(JSON.stringify({"contract": contract, "data": Data.read(blueprint), "design_id": blueprint["design_id"]}))
	witness.close()


func _verify_restart() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://body_contract_expected.json"))
	var loaded: Dictionary = Assembly.load_from_file(SAVE)
	_expect(loaded.get("design_id") == expected["design_id"], "Restart changed the design ID.")
	_expect(Data.read(loaded) == expected["data"], "Restart lost socket offsets/rotation.")
	_expect(_json_equal(Contract.describe(loaded), expected["contract"]), "Fresh process changed resolved body geometry: %s -> %s" % [Contract.describe(loaded), expected["contract"]])
	var preview := _preview(loaded)
	_expect(Contract.inspect_rest(preview)["leg_count"] == 6 and Contract.inspect_rest(preview)["all_feet_on_plane"], "Restart lost six-foot stance.")
	preview.free()


func _check_species() -> void:
	for seed_value in [12, 101, 9081]:
		var a: Dictionary = Factory.create_species(seed_value, Vector2i(1, -2), "grazer")
		var b: Dictionary = Factory.create_species(seed_value, Vector2i(1, -2), "grazer")
		var before: String = JSON.stringify(a)
		var first: Dictionary = Contract.describe(a)
		_expect(first == Contract.describe(b) and before == JSON.stringify(a), "D1 body evidence was nondeterministic or mutated the species.")
		_expect(first["sockets"].size() == 3 and first["errors"].is_empty(), "Generated species lacks inspectable body sockets.")


func _check_editor() -> void:
	root.size = Vector2i(1600, 900)
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	editor.set("blueprint", design(2))
	editor.call("_set_mode", "body")
	var toggle: CheckButton = editor.find_child("ShowBodyFittings", true, false)
	await _click(toggle.get_global_rect().get_center())
	_expect(editor.get("_show_fittings"), "Real fitting-toggle click did not show proxies.")
	var preview: Preview = editor.get("_preview")
	_expect(preview.get_node_or_null("BodyV4/BodyAttachments/saddle_primary/FitGuide/Saddle") != null, "Workshop has no actual saddle witness.")
	var original: Dictionary = Data.read(editor.get("blueprint"))
	var t: SpinBox = editor.find_child("BodySocket_t", true, false)
	t.value = 65
	_expect(is_equal_approx(Data.read(editor.get("blueprint"))["sockets"]["saddle.primary"]["t"], 0.65), "Socket control did not edit the blueprint.")
	editor.call("_undo_edit")
	_expect(Data.read(editor.get("blueprint")) == original, "Undo did not restore body fittings.")
	editor.call("_redo_edit")
	_expect(is_equal_approx(Data.read(editor.get("blueprint"))["sockets"]["saddle.primary"]["t"], 0.65), "Redo lost body fittings.")
	editor.set("_fitting_id", "harness.left")
	editor.call("_change_fitting", 12.0, "rotation_degrees", 1)
	editor.call("_mirror_fitting")
	var mirrored: Dictionary = Data.read(editor.get("blueprint"))
	_expect(mirrored["sockets"]["harness.right"]["rotation_degrees"][1] == -12.0, "Harness reflection lost rotation sign.")
	editor.call("_set_mode", "test")
	editor.call("_choose_motion", "walk")
	var before: String = JSON.stringify(editor.get("blueprint"))
	for frame in range(4):
		await process_frame
	_expect(before == JSON.stringify(editor.get("blueprint")) and preview.body_socket("saddle.primary").size() > 0, "Movement preview changed or lost body fittings.")
	editor.free()
	await process_frame


func _click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 30:
		failures.append(message)


# JSON has one number type; Godot restores integral values as floats. Compare
# structure exactly and numeric roundoff below one millionth of a design unit.
func _json_equal(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _json_equal(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for index in range(a.size()):
			if not _json_equal(a[index], b[index]):
				return false
		return true
	return a == b
