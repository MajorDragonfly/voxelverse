extends SceneTree

const Nest = preload("res://world/resources/nests/wildlife_nest.gd")
const Text = preload("res://core/localization/ui_text.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--nest-restart" in OS.get_cmdline_user_args():
		var args: PackedStringArray = OS.get_cmdline_user_args()
		saves.save_path = args[args.find("--nest-restart") + 1]
		_expect(saves.load_now(), "Fresh process lost the nest save: " + saves.last_error)
		var owner: Dictionary = state.get_current_body_record()
		_expect(progression.has_nest_scan("nest-one", owner.id, owner.seed), "Fresh process lost the first nest discovery")
		_expect(not progression.has_nest_scan("nest-two", owner.id, owner.seed), "Fresh process discovered a second nest")
		await _finish()
		return
	var slot: String = saves.create_slot("Nesttest", 15838, "legacy_plane_v9")
	var owner: Dictionary = state.get_current_body_record()
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 100, 0)
	player.fall_acceleration = 0.0
	player.velocity = Vector3.ZERO
	var scanner: Node = player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	var first: Node3D = _nest("nest-one", player.global_position + Vector3(0, 0, -4))
	await _frames()
	player._gameplay_camera.look_at(first.global_position + Vector3(0, 0.45, 0))
	await _frames()
	player.toggle_inspection_mode()
	_expect(player.get_scan_target() == first, "Center ray missed the physical nest")
	scanner._physics_process(0.1)
	first.refresh(player, 4)
	_expect(first.label.visible and first.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Unscanned nest revealed its species or residents")
	_expect(progression.discovered_species.is_empty(), "Looking at a nest discovered its species")
	for frame in range(12): scanner._physics_process(0.1)
	_expect(not scanner.known and scanner.ratio() > 0.4, "Nest scan did not share the scan circle")
	player._gameplay_camera.rotate_y(0.7)
	scanner._physics_process(0.1)
	_expect(scanner.target == null and scanner.ratio() == 0.0, "Lost aim retained nest progress")
	player._gameplay_camera.look_at(first.global_position + Vector3(0, 0.45, 0))
	for frame in range(26): scanner._physics_process(0.1)
	_expect(scanner.known and progression.has_nest_scan("nest-one", owner.id, owner.seed), "Full scan did not discover the nest")
	_expect(progression.discovered_nests.size() == 1 and not progression.register_nest_scan("nest-one", "other-body", owner.seed), "Nest discovery duplicated or crossed body identity")
	first.refresh(player, 4)
	_expect(first.label.text == Text.format_text("LIVING_NEST", {"species": "Kieselrücken", "count": 4}), "Scanned nest label has wrong species/count")
	for role: String in ["Grazer", "Predator", "Scavenger", "Forager", "Herbivore", "Carnivore", "Pflanzenfresser", "Fleischfresser", "Aggressiv"]:
		first.colony.name = "Kieselrücken · " + role
		first.refresh(player, 4)
		_expect(first.label.text == Text.format_text("LIVING_NEST", {"species": "Kieselrücken", "count": 4}) and first.colony.name == "Kieselrücken · " + role, "Nest presentation retained a role suffix or rewrote colony data: " + role)
		first.colony.name = role
		first.refresh(player, 4)
		_expect(first.label.text == Text.format_text("LIVING_NEST", {"species": Text.text("LIVING_NEST_SPECIES_UNKNOWN"), "count": 4}), "Role-only legacy name became an invented species: " + role)
	first.colony.name = "Kiesel · rücken"
	first.refresh(player, 4)
	_expect(first.label.text == Text.format_text("LIVING_NEST", {"species": "Kiesel · rücken", "count": 4}), "A legitimate compound species name was truncated")
	first.colony.name = "Kieselrücken"
	first.refresh(player, 2)
	_expect(first.label.text.contains("2") and first.living_members == 2, "Member changes did not update the count")
	_expect(progression.discovered_species.is_empty(), "Nest scan replaced species scan")
	first.queue_free()
	await _frames()
	var second: Node3D = _nest("nest-two", player.global_position + Vector3(0, 0, -4))
	await _frames()
	player._gameplay_camera.look_at(second.global_position + Vector3(0, 0.45, 0))
	scanner._physics_process(0.1)
	second.refresh(player, 3)
	_expect(not scanner.known and second.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Same-species nest inherited discovery")
	_expect(progression.discovered_nests.size() == 1, "A second nest changed the discovery index before scanning")
	_expect(saves.save_now(), "Nest snapshot failed: " + saves.last_error)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--nest-restart", slot], output, true)
	_expect(code == 0 and not str(output).contains("ERROR"), "Fresh-process nest save failed: " + str(output).right(1200))
	_expect(saves.load_now() and progression.has_nest_scan("nest-one", owner.id, owner.seed), "Save/reload lost nest identity")
	_expect(not progression.has_nest_scan("nest-two", owner.id, owner.seed), "Save/reload invented nest discovery")
	var old: Dictionary = progression.export_state()
	old.erase("discovered_nests")
	_expect(progression.import_state(old) and progression.discovered_nests.is_empty(), "Old progression invented nests")
	_expect(not progression.has_nest_scan("nest-one", owner.id, owner.seed), "Legacy save inherited a nest discovery")
	var invalid: Dictionary = progression.export_state()
	invalid.discovered_nests = {"bad": {"id": "nest-one", "body_id": owner.id, "world_seed": owner.seed}}
	_expect(not progression.validate_state(invalid).is_empty(), "Malformed nest index was accepted")
	second.queue_free()
	player.queue_free()
	await _finish()

func _nest(id: String, position: Vector3) -> Node3D:
	var nest: Node3D = Nest.new()
	root.add_child(nest)
	nest.global_position = position
	nest.setup({"id": id, "name": "Kieselrücken", "seed": 17}, {}, "grassland")
	return nest

func _frames() -> void:
	for frame in range(3):
		await physics_frame
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print(JSON.stringify({"test": "nest_discovery", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
