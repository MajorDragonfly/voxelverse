extends SceneTree

const Tracker = preload("res://core/discovery/scan_tracker.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var timer := Tracker.new()
	timer.advance(1, 100.0)
	_expect(timer.ratio() < 0.05, "A stalled frame completed the scan.")
	timer.advance(1, NAN)
	timer.advance(0, 0.1)
	_expect(timer.ratio() == 0.0, "Missing target retained progress.")
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	saves.session_managed = true
	saves.autosave_enabled = false
	var path: String = saves.create_slot("Scantest", 15838)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 100, 0)
	player.fall_acceleration = 0.0
	player.velocity = Vector3.ZERO
	var creature: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	creature.configure(2771337, 911227, Vector2i.ZERO, "forager")
	root.add_child(creature)
	creature.set_physics_process(false)
	creature.global_position = player.global_position + Vector3(0, 0, -4)
	var scanner: Node = player.get_node("CreatureScanner")
	# Drive the real scanner with deterministic deltas; raycasts still query
	# the actual physics world, real camera and real wildlife colliders.
	scanner.set_physics_process(false)
	await _frames()
	player._gameplay_camera.look_at(creature.global_position + Vector3(0, 0.56, 0))
	await _frames()
	player.toggle_inspection_mode()
	_expect(player.get_scan_target() == creature, "Center ray did not hit the aimed creature.")
	creature.interact(player)
	player.perform_bite_on_target(creature)
	_expect(progression.get_discovered_species_count() == 0, "Interaction/attack bypassed scanning.")
	for frame in range(12):
		scanner._physics_process(0.1)
	_expect(scanner.ratio() > 0.4 and not scanner.known and progression.get_discovered_species_count() == 0, "Partial scan disclosed/discovered the species.")
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 4, 0.5)
	collision.shape = box
	blocker.add_child(collision)
	root.add_child(blocker)
	blocker.global_position = player.global_position + Vector3(0, 1, -2)
	await _frames()
	scanner._physics_process(0.1)
	_expect(scanner.target == null and scanner.ratio() == 0, "Scan continued through a wall.")
	blocker.queue_free()
	await _frames()
	scanner._physics_process(0.1)
	player._gameplay_camera.rotate_y(0.8)
	scanner._physics_process(0.1)
	_expect(scanner.target == null and scanner.ratio() == 0, "Off-center nearby creature retained scan progress.")
	player._gameplay_camera.look_at(creature.global_position + Vector3(0, 0.56, 0))
	scanner._physics_process(0.1)
	paused = true
	scanner._physics_process(0.1)
	_expect(scanner.ratio() == 0, "Pause retained partial scan.")
	paused = false
	scanner._physics_process(0.1)
	player.toggle_inspection_mode()
	player.toggle_inspection_mode()
	_expect(scanner.ratio() == 0, "Toggling mode retained partial scan.")
	var second: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	second.configure(2771337, 911228, Vector2i.ZERO, "forager")
	root.add_child(second)
	second.set_physics_process(false)
	second.global_position = creature.global_position + Vector3(4, 0, 0)
	await _frames()
	for frame in range(12):
		scanner._physics_process(0.1)
	player._gameplay_camera.look_at(second.global_position + Vector3(0, 0.56, 0))
	scanner._physics_process(0.1)
	_expect(scanner.target == second and scanner.ratio() < 0.05, "Switching individuals of the same species retained partial progress.")
	var points: int = progression.discovery_points
	for frame in range(26):
		scanner._physics_process(0.1)
	var key := "%d:%d" % [state.get_world_seed(), second.species_seed]
	_expect(scanner.known and progression.get_discovered_species_count() == 1, "Full aimed scan did not discover the species.")
	_expect(progression.discovery_points == points + progression.SPECIES_DISCOVERY_POINTS, "Scan reward was missing or duplicated.")
	var entry: Dictionary = progression.discovered_species.get(key, {})
	_expect(not Records.visual_for(entry).is_empty(), "Scan did not save anatomy for the journal.")
	player._gameplay_camera.look_at(creature.global_position + Vector3(0, 0.56, 0))
	scanner._physics_process(0.01)
	_expect(scanner.target == creature and scanner.known and scanner.ratio() == 1, "Known species required another scan on a different individual.")
	_expect(progression.discovery_points == points + progression.SPECIES_DISCOVERY_POINTS, "Known species granted a second reward.")
	_expect(saves.save_now() and saves.load_now() and progression.has_species_scan(creature.species_seed), "Save/load lost the scan.")
	saves.session_active = false
	var copied: String = saves.duplicate_slot(path)
	_expect(saves.select_slot(copied) and progression.has_species_scan(creature.species_seed), "Independent save copy lost the scan.")
	var legacy: Dictionary = progression.export_state()
	legacy.discovered_species[key].erase("scan")
	legacy.discovered_species[key].erase("journal")
	progression.import_state(legacy)
	_expect(progression.has_species_scan(creature.species_seed), "Legacy discovered species was made unknown.")
	scanner.reset()
	scanner._physics_process(0.01)
	_expect(scanner.known and not Records.visual_for(progression.discovered_species[key]).is_empty(), "Legacy known species did not receive a journal preview on sight.")
	saves.create_slot("Neuer Scantest", 15838)
	scanner._physics_process(0.1)
	_expect(not scanner.known and scanner.ratio() < 0.05 and progression.get_discovered_species_count() == 0, "New campaign inherited old scans.")
	player.inspection_radius = 0.1
	scanner._physics_process(0.1)
	_expect(scanner.target == null, "Out-of-range creature could be scanned.")
	player.inspection_radius = 20
	creature.is_dead = true
	scanner._physics_process(0.1)
	_expect(scanner.target == null, "Dead creature could be scanned.")
	creature.queue_free()
	second.queue_free()
	player.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("CREATURE_SCAN_PASSED: exact camera ray, occlusion, lost aim, range, death, pause, toggle, individual change, delayed discovery/reward, journal anatomy, instant known stats, save/load/copy, legacy and new campaign isolation.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _frames() -> void:
	for frame in range(3):
		await physics_frame
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
