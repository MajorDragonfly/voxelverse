extends SceneTree

const Model = preload("res://world/home_group/home_group_state.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const SAVE: String = "user://home_group_test.json"

class ReadyWorld:
	extends Node
	var world_initialized: bool = true

var failures: Array[String] = []
var state: Node
var saves: Node
var scene: Node3D
var player: CharacterBody3D
var home: Node
var capture_dir: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--restart-check" in args:
		_expect(saves.load_now(), "Separate process could not load group campaign.")
		var body: Dictionary = state.get_current_body()
		_expect(body.has("home_group"), "Campaign import discarded body-owned group.")
		if body.has("home_group"):
			_expect(Model.validate(body["home_group"], str(body["id"]), str(state.campaign.data["player_species_id"])).is_empty(), "Restart changed group identities or data.")
			_expect(body["home_group"]["members"][0]["order"] == "home", "Restart lost individual home command.")
		_finish()
		return
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	await _frames(30)
	_expect(home.can_use_panel(), "Nest controller did not initialize with playable scene.")
	_expect(home.group_state().is_empty(), "Merely loading a nest manufactured residents.")
	var original_progression: Dictionary = root.get_node("ProgressionService").export_state().duplicate(true)
	var previous_mouse: int = Input.mouse_mode
	_key(KEY_N)
	await process_frame
	_expect(home.panel.is_open and paused, "N did not open a paused, usable group panel.")
	await _capture("01_empty")
	await _click(home.panel.find_child("EstablishHome", true, false))
	_expect(home.group_state().get("members", []).size() == 2, "Actual GUI click did not establish two persistent residents: " + str(home.panel._message.text))
	if home.group_state().is_empty():
		await _cleanup()
		_finish()
		return
	await _capture("02_group")
	var initial: Dictionary = home.group_state().duplicate(true)
	var ids: Array = [initial["members"][0]["id"], initial["members"][1]["id"]]
	await _click(home.panel.find_child("FollowAll", true, false))
	_expect(home.member_record(ids[0])["order"] == "follow" and home.member_record(ids[1])["order"] == "follow", "Follow-all GUI did not persist both commands.")
	_key(KEY_F2)
	_key(KEY_K)
	_expect(current_scene == scene and home.panel.is_open, "Group menu allowed competing editor/skilltree actions.")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not paused and not home.panel.is_open and Input.mouse_mode == previous_mouse, "Closing did not restore pause/mouse ownership.")
	player.position.x = 12.0
	var actor: CharacterBody3D = home.actors[ids[0]]
	var before: Vector3 = actor.global_position
	await _frames(150)
	_expect(actor.global_position.x > before.x + 3.0, "Follower did not walk toward the player.")
	_expect(actor.is_on_floor(), "Follower lost physical floor contact.")
	_expect(actor.get_node("AdaptiveLocomotionAnimator").get_leg_count() > 0, "Resident is not bound to the existing walking animation.")
	var result: Dictionary = home.issue_order("wait", ids[0])
	_expect(result["ok"], "Individual wait command failed.")
	var wait_point: Vector3 = actor.global_position
	player.position.x = 20.0
	await _frames(80)
	_expect(Vector2(actor.position.x - wait_point.x, actor.position.z - wait_point.z).length() < 0.1, "Waiting member kept following.")
	_expect(home.member_record(ids[1])["order"] == "follow", "Individual command affected the other member.")
	var solid := _box(Vector3(2.0, 4.0, 20.0), actor.global_position + Vector3(1.3, 1.5, 0))
	await _frames(3)
	_expect(not home.safe_step(actor, Vector3.RIGHT), "Resident steering accepted a high wall.")
	solid.queue_free()
	_expect(not home.safe_step(actor, Vector3(100, 0, 0)), "Resident steering accepted an unloaded ledge.")
	var old_path: String = saves.save_path
	saves.save_path = "user://missing_parent/home.json"
	var before_fail: Dictionary = home.group_state().duplicate(true)
	result = home.issue_order("home")
	_expect(not result["ok"] and home.group_state() == before_fail, "Failed save changed live orders instead of rolling back.")
	saves.save_path = old_path
	_expect(home.issue_order("home", ids[0])["ok"], "Return-home command failed.")
	await _frames(160)
	_expect(actor.global_position.distance_to(home.home_position()) < 4.8, "Member did not walk back to its nest.")
	_expect(home.issue_order("wait")["ok"], "Could not stop residents for relocation check.")
	var before_move: Array = home.group_state()["members"].duplicate(true)
	player.position = Vector3(8, 100.05, -8)
	_expect(home.establish_home()["ok"], "Could not relocate home on clear ground.")
	_expect(home.group_state()["members"] == before_move, "Moving home teleported, duplicated or reset members.")
	actor = home.actors[ids[0]]
	player.current_health = 50.0
	await _frames(35)
	_expect(player.current_health > 50.0 and player.current_health < 52.0, "Fed player did not rest slowly at home.")
	player.current_hunger = 0.0
	var rested: float = player.current_health
	await _frames(35)
	_expect(player.current_health == rested, "Home supplied free recovery while starving.")
	player.current_hunger = 100.0
	player.position.x = 160.0
	var far_point: Vector3 = actor.global_position
	_expect(home.issue_order("follow")["ok"], "Far follower command failed.")
	await _frames(10)
	_expect(not actor.visible and actor.global_position == far_point, "Unloaded companion teleported or wandered without terrain.")
	player.position = Vector3(8, 100.05, -8)
	_expect(home.issue_order("home", ids[0])["ok"], "Could not restore the saved home command.")
	_expect(saves.save_now(), "Group snapshot failed.")
	var saved_group: Dictionary = home.group_state().duplicate(true)
	var migration := Campaign.new()
	migration.import_state(state.campaign.export_state())
	_expect(migration.body_record(saved_group.body_id)["home_group"] == saved_group, "Existing campaign import does not preserve extension.")
	var output: Array = []
	var restart_args: PackedStringArray = ["--headless"]
	# Godot consumes --main-pack before get_cmdline_args; the export harness
	# explicitly passes the tested pack through the user-argument boundary.
	if "--restart-pack" in args:
		restart_args.append_array(["--main-pack", args[args.find("--restart-pack") + 1]])
	else:
		restart_args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	restart_args.append_array(["--script", get_script().resource_path, "--", "--restart-check"])
	var code: int = OS.execute(OS.get_executable_path(), restart_args, output, true)
	_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh process rejected snapshot: " + str(output))
	_expect(root.get_node("ProgressionService").export_state() == original_progression, "Nest/group operations changed behavior points, discoveries or unlocks.")
	# Save 8 validates nested contracts before replacing the joint snapshot.
	# Future group data stays opaque in memory; the previous readable file is
	# preserved until the compatible group is restored, with no new residents.
	var previous_bytes: String = FileAccess.get_file_as_string(SAVE)
	var body: Dictionary = state.get_current_body_record()
	body["home_group"]["schema"] = 99
	var future: Dictionary = body["home_group"].duplicate(true)
	home._refresh_runtime()
	_expect(not home.issue_order("follow")["ok"] and body["home_group"] == future, "Unsupported group was changed.")
	_expect(not saves.save_now() and body["home_group"] == future and FileAccess.get_file_as_string(SAVE) == previous_bytes, "Unsupported group replaced the last compatible snapshot or was reset.")
	body["home_group"] = saved_group
	home._refresh_runtime()
	await _frames(3)
	# Loaded snapshots rebuild actor identities/commands, without a second team.
	_expect(saves.save_now(), "Could not restore valid snapshot.")
	_expect(saves.load_now(), "Same-process group reload failed.")
	await _frames(30)
	_expect(home.actors.size() == 2 and home.group_state()["members"][0]["id"] == ids[0], "Reload duplicated or replaced residents.")
	var old_campaign: String = str(state.campaign.data["id"])
	var old_body: Dictionary = state.get_current_body()
	state.activate_planet(state.system_seed, 1, 63352)
	await _frames(30)
	_expect(home.group_state().is_empty() and home.actors.is_empty(), "Different body inherited the first body's nest group.")
	state.activate_planet(state.system_seed, 0, 15838)
	await _frames(30)
	_expect(home.actors.size() == 2 and str(state.campaign.data["id"]) == old_campaign, "Revisiting body lost original group.")
	_expect(state.get_current_body()["id"] == old_body["id"], "Revisit changed body identity.")
	home.panel.open_panel()
	await _capture("03_restored")
	root.size = Vector2i(800, 600)
	await _frames(3)
	await _capture("04_compact")
	await _cleanup()
	_expect(not paused, "Removing open home scene left the next scene paused.")
	state.start_world_with_seed(15838)
	await _frames(3)
	_expect(not state.get_current_body().has("home_group"), "New campaign retained old residents.")
	_finish()

func _build_fixture() -> void:
	root.size = Vector2i(1280, 800)
	scene = Node3D.new()
	scene.name = "HomeGroupFixture"
	root.add_child(scene)
	current_scene = scene
	var manager := ReadyWorld.new()
	manager.name = "WorldManager"
	scene.add_child(manager)
	_box(Vector3(80, 1, 80), Vector3(0, 99.5, 0))
	player = load("res://creatures/player/player.tscn").instantiate()
	scene.add_child(player)
	player.position = Vector3(0, 100.05, 0)
	player.set_physics_process(false)
	player.set_process(false)
	var nest: Node3D = load("res://world/resources/nests/nest.tscn").instantiate()
	nest.snap_to_terrain = false
	scene.add_child(nest)
	nest.position = Vector3(0, 100.02, 0)
	home = nest.get_node("HomeGroup")
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	scene.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.19, 0.25, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.80, 0.88, 0.80)
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8, 107, 14)
	camera.look_at(Vector3(0, 101, 0))
	camera.make_current()

func _box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.29, 0.39, 0.24)
	visual.material_override = material
	body.add_child(visual)
	scene.add_child(body)
	body.position = position
	return body

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _click(button: Button) -> void:
	_expect(button != null and button.is_visible_in_tree(), "Required button is absent.")
	if button == null:
		return
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(not image.is_empty(), "Empty viewport capture.")
	image.save_png(capture_dir.path_join(label + ".png"))

func _cleanup() -> void:
	scene.queue_free()
	await _frames(4)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: " + message)

func _finish() -> void:
	print(JSON.stringify({"test": "home_group", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
