extends SceneTree

const Lab = preload("res://world/planet_lab/planet_lab.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Save = preload("res://world/planet_lab/planet_lab_save.gd")
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Visits = preload("res://world/space/galaxy_visits.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("SaveGameService").autosave_enabled = false
	var lab := Lab.new()
	root.add_child(lab)
	lab.time_speed = 0.0
	lab.walker.enabled = false
	if "--visit-restart-check" in OS.get_cmdline_user_args():
		var saved: Dictionary = Save.read()
		_expect(not saved.is_empty() and saved.schema == 4 and lab.system.catalog_id == saved.system_id and lab.body_id == saved.body_id, "Fresh process did not restore the catalog planet.")
		if not saved.is_empty():
			_expect(_distance(saved.location, lab.walker.location(), lab.system.bodies[lab.body_id].radius) < 0.001, "Fresh process lost the precise return point.")
			_expect(lab.system.elapsed == 123.25 and lab.walker.forward.dot(Cube.vector(saved.forward)) > 0.99999, "Restart lost the system clock or heading.")
	else:
		lab.open_galaxy_catalog()
		await process_frame
		await process_frame
		var panel: Node = lab.galaxy_panel
		var first_system: String = panel.selected_id
		var first_body: String = panel.body_list.get_item_metadata(panel.body_list.selected)
		for index in range(panel.body_list.item_count):
			var body: Dictionary = lab.catalog.body(panel.body_list.get_item_metadata(index))
			_expect(panel.body_list.is_item_disabled(index) == not body.landable, "Non-landable catalog body was offered as a surface destination.")
		_click(panel.visit_button)
		for frame in range(8):
			await process_frame
			if not is_instance_valid(lab.galaxy_panel):
				break
		lab.walker.enabled = false
		_expect(lab.body_id == first_body and lab.system.catalog_id == first_system and not is_instance_valid(lab.galaxy_panel), "A real catalog Visit click did not open its selected physical planet.")
		if lab.body_id != first_body:
			await _finish(lab)
			return
		var descriptor: Dictionary = lab.catalog.body(first_body)
		_expect(lab.terrain.surface.body == descriptor and lab.system.real_scale and descriptor.radius >= 50000.0, "Landing substituted a test body, radius, seed, or gravity.")
		var starting: Dictionary = lab.walker.location()
		lab.walker.orbit_axis = lab.walker.up_direction.cross(lab.walker.forward).normalized()
		lab.walker.automatic = true
		lab.walker.speed = 14.0
		lab.walker.enabled = true
		var contacts: int = 0
		for frame in range(150):
			await physics_frame
			contacts += int(lab.walker.is_on_floor() or lab.walker.swimming)
		lab.walker.enabled = false
		lab.walker.automatic = false
		lab.system.elapsed = 123.25
		_expect(contacts >= 125 and _distance(starting, lab.walker.location(), descriptor.radius) > 10.0, "Catalog planet did not support actual locomotion and floor contact.")
		var first_pose: Dictionary = lab.snapshot()
		_expect(lab.save_lab() and Save.valid(first_pose), "Catalog location did not save as schema 4.")
		var remote: Dictionary = lab.catalog.sector_at([1000, 0, -700])
		var second_system: String = remote.systems[0].id
		var second_body: String = ""
		var second_radius: float = 0.0
		for entry: Dictionary in remote.systems:
			for body: Dictionary in lab.catalog.system(entry.id).bodies.values():
				if body.landable and body.radius > second_radius:
					second_body = body.id
					second_system = entry.id
					second_radius = body.radius
		_expect(second_radius > 6371000.0, "Remote fixture must exercise a planet larger than Earth.")
		_expect(lab.visit_planet(second_system, second_body), "Visiting a different galactic sector failed.")
		lab.walker.enabled = false
		lab.system.elapsed = 456.5
		var second_pose: Dictionary = lab.snapshot()
		_expect(lab.terrain.layout.max_level >= 19 and lab.terrain.active.size() == 24, "Large catalog planet lost metre-scale ground or collision.")
		_expect(lab.meshes.size() == lab.system.bodies.size() and lab.meshes.size() <= 34 and lab.space_bodies.size() == lab.meshes.size(), "System travel retained the old system's meshes or nodes.")
		for mode in ["orbit", "system", "surface"]:
			lab.set_view(mode)
			lab.walker.enabled = false
			_expect(_distance(second_pose.location, lab.walker.location(), second_radius) < 0.001, "Catalog view switching moved the player.")
		_expect(lab.lights.has(lab.system.primary_star_id()), "Catalog lighting used a missing reference star.")
		_expect(not lab.visit_planet(second_system, lab.system.primary_star_id()) and lab.body_id == second_body, "A star visit changed the active surface.")
		_expect(lab.visit_planet(first_system, first_body), "Returning to the first planet failed.")
		lab.walker.enabled = false
		_expect(_distance(first_pose.location, lab.walker.location(), descriptor.radius) < 0.001 and lab.system.elapsed == 123.25, "Returning from another system lost the first planet's place or clock.")
		var other: Dictionary = lab.visits.read(second_system).record
		_expect(other.elapsed == 456.5 and _distance(second_pose.location, other.bodies[second_body].location, second_radius) < 0.001, "The departing planet's return point was not retained.")
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--visit-restart-check"], output, true)
		_expect(code == 0 and not str(output).contains("ERROR:"), "Fresh-process catalog visit restore failed: " + str(output))
		_storage_checks(lab.catalog, first_system, first_body, first_pose)
		print("GALAXY_VISITS ", JSON.stringify({"first_body": first_body, "first_radius_m": descriptor.radius, "second_body": second_body, "second_radius_m": second_radius, "walk_m": _distance(starting, first_pose.location, descriptor.radius), "contacts": contacts, "restart_exit": code, "loaded_orbit_meshes": lab.meshes.size()}))
	await _finish(lab)


func _storage_checks(catalog: RefCounted, system_id: String, body_id: String, saved: Dictionary) -> void:
	var store := Visits.new(catalog, "user://visit_contract")
	_expect(store.open() == OK, "Visit store did not open.")
	var record: Dictionary = store.read(system_id).record
	record.bodies[body_id] = {"terrain_revision": 3, "location": saved.location, "forward": saved.forward}
	_expect(store.write(record) == OK and store.write(record) == ERR_BUSY, "Visit storage did not detect a stale writer.")
	var latest: Dictionary = store.read(system_id).record
	var invalid: Dictionary = latest.duplicate(true)
	invalid.bodies[body_id].location.body_id = "m1b:terra"
	_expect(store.write(invalid) == ERR_INVALID_DATA, "Visit accepted a coordinate belonging to another body.")
	var path: String = store.record_path(system_id)
	Atomic.write(path + ".bak", latest, false)
	Atomic._write_text(path, "{broken")
	store.clear_cache()
	var recovered: Dictionary = store.read(system_id)
	_expect(recovered.error == OK and recovered.recovered and store.write(recovered.record) == OK, "A corrupt visit did not recover from its valid backup.")
	latest = store.read(system_id).record
	var future: Dictionary = latest.duplicate(true)
	future.bodies[body_id].terrain_revision = 4
	Atomic.write(path, future)
	var protected: String = FileAccess.get_file_as_string(path)
	store.clear_cache()
	_expect(store.read(system_id).error == ERR_UNAVAILABLE and store.write(latest) == ERR_UNAVAILABLE and FileAccess.get_file_as_string(path) == protected, "Future terrain visits were silently recovered or overwritten.")
	var foreign := Visits.new(Catalog.new("7"), "user://visit_contract")
	_expect(foreign.open() != OK, "Visit store accepted a different universe identity.")
	var checkpoint: String = "user://future_visit.json"
	future = saved.duplicate(true)
	future.catalog_version = "galaxy_catalog_v2"
	Atomic.write(checkpoint, future)
	_expect(Save.read(checkpoint).is_empty() and Save.write(saved, checkpoint) == ERR_UNAVAILABLE, "Future session checkpoint was overwritten.")


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)


func _distance(a: Dictionary, b: Dictionary, radius: float) -> float:
	return Cube.local_position(Cube.cartesian(a, radius), Cube.cartesian(b, radius)).length()


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)


func _finish(lab: Node) -> void:
	lab.queue_free()
	await process_frame
	await process_frame
	for message in failures:
		push_error(message)
	print("GALAXY_VISITS_PASSED ", failures.is_empty())
	quit(0 if failures.is_empty() else 1)
