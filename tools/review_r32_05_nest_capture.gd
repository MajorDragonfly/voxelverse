extends "res://tools/capture_nest_discovery.gd"
## Simultaneous same-species IDs; label inputs here are explicit fixture values.
## Authoritative colony counts are checked separately in the public sphere probe.
var observations: Array[Dictionary] = []

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	saves.session_managed = true; saves.autosave_enabled = false
	if "--verify-pair-restart" in args:
		var index: int = args.find("--verify-pair-restart")
		saves.save_path = args[index + 1]
		_check(saves.load_now(), "Fresh process could not load the nest pair")
		var owner: Dictionary = state.get_current_body_record()
		_check(progression.has_nest_scan("pair-one", owner.id, owner.seed), "Fresh process lost first nest")
		_check(progression.has_nest_scan("pair-two", owner.id, owner.seed) == (args[index + 2] == "both"), "Fresh process changed second nest discovery")
		print("R32_NEST_PAIR_RESTART ", args[index + 2])
		await _finish(); return
	if args.is_empty() or DisplayServer.get_name() == "headless": quit(1); return
	output = args[0]
	root.get_node("LocaleManager").save_preference(args[1] if args.size() > 1 else "de")
	root.size = Vector2i(1280, 720)
	var slot: String = saves.create_slot("R32-05 simultaneous nest pair", 15838, "legacy_plane_v9")
	var owner: Dictionary = state.get_current_body_record()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("183743")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d2e4df")
	environment.environment.ambient_light_energy = 0.75
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -20, 0); root.add_child(light)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 100, 0); player.fall_acceleration = 0
	player.get_node("CreatureRuntimeVisual").hide(); player.get_node("BodyMesh").hide()
	var scanner: Node = player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	title = Label.new(); title.position = Vector2(16, 200); root.add_child(title)
	var first: Node3D = _nest("pair-one", player.global_position + Vector3(-1.9, 0, -5))
	var second: Node3D = _nest("pair-two", player.global_position + Vector3(1.9, 0, -5))
	for tick in range(4): await physics_frame; await process_frame
	player.toggle_inspection_mode()
	# Each before view targets a distinct, simultaneously loaded unknown nest.
	for nest: Node3D in [first, second]:
		player._gameplay_camera.look_at(nest.global_position + Vector3.UP * 0.45)
		await physics_frame
		scanner._physics_process(1.0 / 30.0)
		first.refresh(player, 4); second.refresh(player, 3)
		_check(scanner.target == nest and nest.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Unknown pair member leaked species/count or lost target")
		await _chapter("before-" + str(nest.colony.id), player, first, second)
	player._gameplay_camera.look_at(first.global_position + Vector3.UP * 0.45)
	for tick in range(85):
		await physics_frame
		scanner._physics_process(1.0 / 30.0)
		first.refresh(player, 4); second.refresh(player, 3)
		await _record("First nest / %d%% / fixture residents 4" % roundi(scanner.ratio() * 100))
	_check(scanner.known and progression.has_nest_scan("pair-one", owner.id, owner.seed), "First pair scan failed")
	_check(not progression.has_nest_scan("pair-two", owner.id, owner.seed), "First scan discovered same-species second ID")
	await _chapter("first-discovered", player, first, second)
	_check(saves.save_now(), "First-only pair save failed")
	var first_restart: int = _restart_pair(slot, "first")
	_check(saves.load_now(), "First-only pair reload failed")
	# Unload/recreate the known landmark through the same public visual setup.
	var first_position: Vector3 = first.global_position
	first.queue_free()
	for tick in range(3): await physics_frame; await process_frame
	first = _nest("pair-one", first_position)
	for tick in range(3): await physics_frame; await process_frame
	scanner._physics_process(1.0 / 30.0)
	first.refresh(player, 2); second.refresh(player, 3)
	_check(scanner.target == first and scanner.known and first.label.text == Text.format_text("LIVING_NEST", {"species": "Kieselrücken", "count": 2}), "Recreated nest lost discovery/current supplied count")
	await _chapter("first-recreated-count-two", player, first, second)
	player._gameplay_camera.look_at(second.global_position + Vector3.UP * 0.45)
	for tick in range(85):
		await physics_frame
		scanner._physics_process(1.0 / 30.0)
		first.refresh(player, 2); second.refresh(player, 3)
		if tick == 0:
			_check(not scanner.known and scanner.ratio() < 0.02 and second.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Second ID inherited knowledge/progress/label")
			await _chapter("second-still-unknown", player, first, second)
		await _record("Second same-species nest / %d%% / fixture residents 3" % roundi(scanner.ratio() * 100))
	_check(scanner.known and progression.has_nest_scan("pair-two", owner.id, owner.seed), "Second independent scan failed")
	await _chapter("both-discovered", player, first, second)
	_check(saves.save_now(), "Both-known pair save failed")
	var both_restart: int = _restart_pair(slot, "both")
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "language": args[1] if args.size() > 1 else "de", "frames": frame, "restart_exits": [first_restart, both_restart], "observations": observations, "failures": failures, "limits": "Two same-species production landmarks in a staged legacy scene; supplied counts 4/2/3 are fixture inputs. Real generated resident counts and map checked in public sphere probe."}, "\t")); file.close()
	first.queue_free(); second.queue_free(); player.queue_free(); title.queue_free(); environment.queue_free(); light.queue_free()
	await _finish()

func _restart_pair(slot: String, stage: String) -> int:
	var child_output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--verify-pair-restart", slot, stage], child_output, true)
	_check(code == 0 and str(child_output).contains("R32_NEST_PAIR_RESTART") and not str(child_output).contains("ERROR"), "Fresh pair process failed: " + str(child_output))
	return code

func _chapter(name: String, player: Node3D, first: Node3D, second: Node3D) -> void:
	var scanner: Node = player.get_node("CreatureScanner")
	observations.append({"case": name, "target": str(scanner.target.colony.id) if scanner.target != null else "", "known": scanner.known, "progress": scanner.ratio(), "labels": [{"id": first.colony.id, "text": first.label.text, "visible": first.label.visible}, {"id": second.colony.id, "text": second.label.text, "visible": second.label.visible}]})
	await _record(name)
	_check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Pair chapter screenshot failed")
