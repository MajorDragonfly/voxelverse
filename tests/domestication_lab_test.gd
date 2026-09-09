extends SceneTree
const Scene = preload("res://world/domestication/lab/domestication_lab.tscn")
const Fixture = preload("res://world/domestication/lab/lab_fixture.gd")
const State = preload("res://world/domestication/animal_state.gd")
var lab: Node3D
var failures: Array[String] = []
var measurements: Dictionary = {}
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves := root.get_node("SaveGameService")
	saves.session_managed = true
	saves.session_active = false
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://d2_tests/campaign_sentinel.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves.save_path.get_base_dir()))
	var sentinel := FileAccess.open(saves.save_path, FileAccess.WRITE)
	if sentinel == null:
		printerr("D2_FAIL: Cannot create campaign sentinel")
		quit(1)
		return
	sentinel.store_string("campaign-must-remain-untouched")
	sentinel.close()
	var campaign_before: String = JSON.stringify(root.get_node("GameState").campaign.data)
	var progression_before: String = JSON.stringify(root.get_node("ProgressionService").export_state())
	lab = Scene.instantiate()
	lab.store.path = "user://d2_tests/%s/snapshot.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(lab)
	current_scene = lab
	await _frames(12)
	_expect(lab.booted and lab.snapshot["phase"] == 1, "Probe did not boot into tribal phase")
	# The buttons call the same production-independent controller under test.
	lab.buttons["friend"].pressed.emit()
	_expect(lab.controller.record(Fixture.ANIMAL)["owner_faction_id"] == "", "Befriend button tamed animal")
	lab.buttons["phase"].pressed.emit()
	lab.buttons["offer"].pressed.emit()
	_expect(lab.controller.last_result["code"] == "tribal_age_required", "Phase 0 button allowed taming")
	lab.buttons["phase"].pressed.emit()
	lab.selected_food = "meat"
	lab.buttons["offer"].pressed.emit()
	_expect(lab.controller.last_result["code"] == "wrong_food", "Wrong food button worked")
	lab.selected_food = "roots"
	# Put the handler and animal on opposite sides of the real collider, in range.
	lab.handler.position = Vector3(-4, 0, 0)
	lab.animal.position = Vector3(-0.5, 0, 0)
	await _frames(4)
	_expect(not lab.live_context()["line_of_sight"], "Physical rock did not occlude sight")
	lab.buttons["offer"].pressed.emit()
	_expect(lab.controller.last_result["code"] == "no_line_of_sight", "Futter crossed actual rock")
	lab.handler.position = Vector3(0, 0, 2)
	lab.animal.position = Vector3(2, 0, 1)
	await _frames(4)
	lab.buttons["offer"].pressed.emit()
	await _frames(15)
	var before_pause: float = lab.controller.record(Fixture.ANIMAL)["pending"].get("elapsed", 0.0)
	paused = true
	for i in range(10): await process_frame
	_expect(lab.controller.record(Fixture.ANIMAL)["pending"].get("elapsed", 0.0) == before_pause, "Scene pause advanced offer")
	paused = false
	lab.buttons["flee"].pressed.emit()
	_expect(lab.controller.record(Fixture.ANIMAL)["pending"].is_empty() and lab.snapshot["stock"]["roots"] == 12, "Flight charged unfinished meal")
	lab.animal.fleeing = 0
	for i in range(4):
		lab.buttons["offer"].pressed.emit()
		await _frames(125)
	_expect(lab.controller.record(Fixture.ANIMAL)["status"] == "tamed" and lab.snapshot["stock"]["roots"] == 8, "Four real timed meals did not tame")
	lab.handler.position = Vector3(8, 0, 5)
	lab.buttons["follow"].pressed.emit()
	var follow_start: Vector3 = lab.animal.global_position
	await _frames(180)
	var follow_distance: float = lab.animal.global_position.distance_to(lab.handler.global_position)
	measurements["follow_travel_m"] = follow_start.distance_to(lab.animal.global_position)
	measurements["follow_remaining_m"] = follow_distance
	_expect(follow_start.distance_to(lab.animal.global_position) > 4.0 and follow_distance < 2.0, "Follow did not move real body to handler")
	lab.buttons["wait"].pressed.emit()
	var wait_position: Vector3 = lab.animal.global_position
	lab.handler.position = Vector3(10, 0, -5)
	await _frames(60)
	measurements["wait_drift_m"] = wait_position.distance_to(lab.animal.global_position)
	_expect(wait_position.distance_to(lab.animal.global_position) < 0.08, "Wait moved after handler")
	lab.buttons["save"].pressed.emit()
	var saved_id: String = lab.controller.record(Fixture.ANIMAL)["object_id"]
	lab.buttons["load"].pressed.emit()
	await _frames(4)
	_expect(lab.controller.record(Fixture.ANIMAL)["object_id"] == saved_id and lab.controller.record(Fixture.ANIMAL)["order"] == "wait", "Load lost individual/order")
	_expect(wait_position.distance_to(lab.animal.global_position) < 0.08, "Load lost physical position")
	lab.buttons["home"].pressed.emit()
	var home_start: Vector3 = lab.animal.global_position
	var entered_rock: bool = false
	for i in range(460):
		await physics_frame
		var p: Vector3 = lab.animal.global_position
		if p.x > -3.65 and p.x < -1.35 and p.z > -5.75 and p.z < 1.75: entered_rock = true
	measurements["home_travel_m"] = home_start.distance_to(lab.animal.global_position)
	measurements["home_remaining_m"] = lab.animal.global_position.distance_to(Fixture.HOME)
	_expect(not entered_rock, "Animal passed through obstacle collider")
	_expect(lab.animal.global_position.distance_to(Fixture.HOME) < 0.6, "Home could not route around obstacle")
	_expect(lab.animal.global_position.y > -0.1 and lab.animal.global_position.y < 0.15, "Animal lost ground contact")
	lab.buttons["save"].pressed.emit()
	lab.buttons["load"].pressed.emit()
	await _frames(3)
	_expect(lab.controller.record(Fixture.ANIMAL)["order"] == "home" and lab.animal.global_position.distance_to(Fixture.HOME) < 0.6, "Home order or position not restored")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(args[args.find("--capture") + 1])
	lab.buttons["hurt"].pressed.emit()
	lab.buttons["hurt"].pressed.emit()
	lab.buttons["load"].pressed.emit()
	await _frames(3)
	_expect(lab.controller.record(Fixture.ANIMAL)["status"] == "dead" and lab.animal.status == "Verstorben", "Death was not restored")
	_expect(JSON.stringify(root.get_node("GameState").campaign.data) == campaign_before, "Probe changed campaign")
	_expect(JSON.stringify(root.get_node("ProgressionService").export_state()) == progression_before, "Probe changed social/progression ledger")
	# Exercise the real close notifications, including SaveGameService's handler.
	lab.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	saves.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_expect(FileAccess.get_file_as_string(saves.save_path) == "campaign-must-remain-untouched", "Probe overwrote campaign save on close")
	root.remove_child(lab)
	lab.queue_free()
	await process_frame
	print(JSON.stringify({"checks": checks, "measurements": measurements, "failures": failures}))
	print("D2_LAB_PASS" if failures.is_empty() else "D2_LAB_FAIL")
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in range(count): await physics_frame

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("D2_FAIL: " + label)
