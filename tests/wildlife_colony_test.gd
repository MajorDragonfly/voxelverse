extends "res://tests/population_register_test.gd"
const Colonies = preload("res://world/surface/wildlife_colony.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
class TerrainFixture:
	extends Node3D
	signal origin_changed(previous: Array, current: Array)
	var surface: RefCounted
	var origin: Array
var terrain: TerrainFixture
var colony_key: String

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	progression = root.get_node("ProgressionService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://wildlife_colony.json"
	if "--colony-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process failed to load colonies")
		_bind()
		colony_key = FileAccess.get_file_as_string("user://colony-key.txt")
		_check_colony()
		await _finish()
		return
	state.start_world_with_seed(15838, Cube.MODE)
	saves._pending_player_state = {"surface_address": state.get_current_body_record().surface_context.spawn.duplicate(true), "surface_forward": [0.0, 0.0, 1.0], "surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": -0.18, "health": 100.0, "hunger": 100.0, "thirst": 100.0}
	_bind()
	terrain = TerrainFixture.new()
	terrain.surface = Factory.create(host.descriptor)
	var start: Dictionary = state.get_current_body_record().surface_context.spawn
	terrain.origin = Cube.cartesian(start, host.descriptor.radius)
	root.add_child(terrain)
	host.adapter = Adapter.new(terrain)
	var nearby: Dictionary = Model.Cells.nearby(host.descriptor, start)
	for cell: Dictionary in nearby.values():
		host.storage.pin([cell.id])
		host._generate(cell)
		var region: Dictionary = host.storage.region(cell.id)
		if region.has("colony") and region.colony.members.size() >= 3:
			colony_key = cell.id
			break
	_expect(not colony_key.is_empty(), "Real planet produced no populated nest")
	if not colony_key.is_empty():
		var region: Dictionary = host.storage.region(colony_key)
		var first: Dictionary = host.storage.record(region.colony.members[0])
		# A legacy upgrade must preserve the original resident exactly except
		# for its additive colony membership, even if its encounter is wounded.
		var saved: Dictionary = first.duplicate(true)
		var ids: Array = region.colony.members.duplicate()
		var original_blueprint: Dictionary = first.blueprint.duplicate(true)
		region.erase("colony")
		first.erase("colony_id")
		Colonies.ensure(host, region, first)
		_expect(first == saved and region.colony.members == ids, "Upgrade replaced resident data or duplicated family members")
		for id: String in ids:
			var resident: Dictionary = host.storage.record(id)
			_expect(resident.identity.species_id == first.identity.species_id and resident.blueprint == original_blueprint, "Nest residents have unrelated species/bodies")
		var moved: Dictionary = host.storage.record(ids[1])
		var far: Dictionary = host.adapter.offset(start, host.adapter.frame_at(start).x * 180.0)
		far.radius = host.descriptor.radius
		_expect(host.storage.move(moved, far), "Could not move a resident across regions")
		region.erase("colony")
		Colonies.ensure(host, region, first)
		_expect(host.storage.record(ids[1]).location == far and not region.objects.has(ids[1]), "Colony upgrade cloned or teleported a migrated resident")
		var future: Dictionary = region.colony.duplicate(true)
		future.schema = 99
		_expect(not Colonies.problem(future, host.descriptor).is_empty(), "Future nest schema accepted")
		_expect(Model.validate_region(region, host.descriptor).is_empty(), "Production colony validation failed")
		var file := FileAccess.open("user://colony-key.txt", FileAccess.WRITE)
		file.store_string(colony_key)
		file.close()
		_expect(saves.save_now(), "Colony snapshot failed: " + saves.last_error)
		_check_colony()
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--colony-restart"], output, true)
		_expect(code == 0 and not str(output).contains("ERROR"), "Fresh-process colony check failed: " + str(output).right(1800))
	host.adapter.close()
	terrain.free()
	await _finish()

func _check_colony() -> void:
	var region: Dictionary = host.storage.region(colony_key)
	_expect(region.has("colony"), "Saved nest is missing")
	if not region.has("colony"): return
	_expect(region.colony.members.size() >= 3 and region.colony.members.size() <= Colonies.MAX_MEMBERS, "Population changed across save/reload")
	for id: String in region.colony.members:
		var resident: Dictionary = host.storage.record(id)
		_expect(not resident.is_empty() and resident.colony_id == region.colony.id, "Nest membership missing after restart")

func _finish() -> void:
	if host != null: host.free()
	print(JSON.stringify({"test": "wildlife_colony", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
