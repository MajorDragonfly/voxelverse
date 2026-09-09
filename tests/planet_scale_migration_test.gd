extends SceneTree

const Lab = preload("res://world/planet_lab/planet_lab.gd")
const System = preload("res://world/space/celestial_system.gd")
const Surface = preload("res://world/space/planet_surface.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Save = preload("res://world/planet_lab/planet_lab_save.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var lab := Lab.new()
	root.add_child(lab)
	lab.time_speed = 0.0
	for id: String in System.LANDABLE:
		var body: Dictionary = lab.system.bodies[id]
		_expect(body.radius >= 512.0 and body.radius <= 4096.0 and body.adaptive_tiles, "Playable planet/moon scale or bounded terrain mode is wrong.")
		if body.kind == "moon":
			_expect(body.radius < lab.system.bodies[body.parent_id].radius * 0.5, "Moon is not smaller than its planet.")
		_expect(body.radius < lab.system.bodies["m1:sol"].radius, "A planet exceeds the primary star's physical size.")
		var old_body: Dictionary = body.duplicate(true)
		old_body.radius = System.PREVIOUS_RADII[id]
		old_body.terrain_revision = 1
		var previous := Surface.new(old_body)
		var location: Dictionary = Cube.address(id, 0, 0.1, 0.2)
		location.height = previous.sample(location).height + 1.1
		var old: Dictionary = {"schema": 1, "surface_version": Cube.MODE, "body_id": id, "location": location,
			"forward": [0.0, 0.0, -1.0], "elapsed": 42.0, "binary": false}
		_expect(Save.write(old) == OK, "Cannot write the old lab fixture.")
		lab.load_lab()
		lab.walker.enabled = false
		var migrated: Dictionary = lab.walker.location()
		_expect(absf(migrated.u - location.u) < 0.00001 and absf(migrated.v - location.v) < 0.00001 and migrated.face == location.face,
			"Migration changed the saved angular location.")
		_expect(absf(migrated.height - lab.terrain.surface.sample(migrated).height - 1.1) < 0.02, "Resized planet left the old saved player inside the terrain or in the air.")
		_expect(lab.save_lab() and Save.read().schema == 2, "Migration did not persist the new terrain revision.")
		lab.load_lab()
		lab.walker.enabled = false
		_expect(absf(lab.walker.location().height - migrated.height) < 0.02, "Second load applied migration twice.")
	lab.queue_free()
	await process_frame
	await process_frame
	for message in failures:
		push_error(message)
	print("PLANET_SCALE_MIGRATION playable sizes, star/moon ratios and four old body saves: ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
