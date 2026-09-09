extends Node3D

const System = preload("res://world/space/celestial_system.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Terrain = preload("res://world/surface/surface_terrain.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Walker = preload("res://world/planet_lab/radial_walker.gd")
const SurfaceTree = preload("res://world/surface/surface_tree.gd")
const Creature = preload("res://world/surface/surface_creature.gd")
const Store = preload("res://world/surface/surface_lab_store.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const ACTIVE_RADIUS: float = 96.0
const UNLOAD_RADIUS: float = 128.0
var system: RefCounted = System.new(false, true)
var terrain: Node3D
var adapter: RefCounted
var walker: CharacterBody3D
var tree: StaticBody3D
var creature: CharacterBody3D
var body_id: String = "m1b:terra"
var records: Dictionary = {}
var store_path: String = Store.PATH
var save_backend: Script = Store
var read_only: bool = false
var object_loads: int = 0
var object_unloads: int = 0
var max_object_build_ms: float = 0.0
var initial_load_ms: float = 0.0
var hud: Label
var status: Label
var help_label: Label
var _old_autosave: bool = true
var _old_session_managed: bool = false
var _old_session_active: bool = false
var _ready_complete: bool = false
var _sun: DirectionalLight3D
var _stream_elapsed: float = 0.0
var paused: bool = false
var leave_without_saving: Button


func _ready() -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		_old_autosave = saves.autosave_enabled
		_old_session_managed = saves.session_managed
		_old_session_active = saves.session_active
		saves.session_managed = true
		saves.session_active = false
		saves.autosave_enabled = false
	_build_view()
	var saved: Dictionary = save_backend.read(store_path)
	read_only = saved.error != OK
	if not saved.data.is_empty():
		records = saved.data.bodies
		body_id = saved.data.body_id
	open_body(body_id)
	_ready_complete = true
	status.text = "Vorhandene M1d-Datei geschützt; Sitzung nur lesend." if read_only else "Klicke in die Landschaft, um loszulaufen."
	leave_without_saving.visible = read_only
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	if adapter != null:
		adapter.close()
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.session_managed = _old_session_managed
		saves.session_active = _old_session_active
		saves.autosave_enabled = _old_autosave
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _ready_complete:
		save_lab()


func open_body(id: String, capture: bool = true) -> bool:
	if id not in System.REAL_LANDABLE:
		return false
	if is_instance_valid(walker):
		if capture:
			_capture()
		_clear_body()
	body_id = id
	var started: int = Time.get_ticks_usec()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.configure(system.bodies[id])
	adapter = Adapter.new(terrain)
	if not records.has(id):
		records[id] = _new_record()
	var record: Dictionary = records[id]
	walker = Walker.new()
	walker.terrain = terrain
	walker.creature_design = Blueprint.create_default()
	add_child(walker)
	walker.collision_layer = 8
	walker.collision_mask = 1 | 2 | 4
	walker.place(record.player.location, Cube.vector(record.player.forward))
	adapter.bind(id + ":m1d:player", walker, record.player.location, Cube.vector(record.player.forward))
	walker.velocity = Cube.vector(record.player.velocity)
	walker.traveled = record.player.traveled
	walker.camera.far = 30000.0
	walker.camera.near = 0.2
	walker.camera.make_current()
	walker.enabled = not paused
	stream_objects()
	# Use one radial frame for both light orientation and its rotation axis.
	# A saved player heading must not rotate sunlight below the surface.
	var sun_frame: Basis = Cube.frame(walker.up_direction)
	_sun.basis = sun_frame.rotated(sun_frame.x, -0.65)
	initial_load_ms = (Time.get_ticks_usec() - started) / 1000.0
	return true


func _clear_body() -> void:
	adapter.close()
	for node in [tree, creature, walker, terrain]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	tree = null
	creature = null
	walker = null
	terrain = null


func _new_record() -> Dictionary:
	# Deterministic dry, gentle fixture near a cube edge; no campaign seed or
	# species data participates. All three reference bodies keep their true size.
	var spawn: Dictionary = {}
	for face in range(6):
		for v in [0.0, 0.2, -0.2, 0.6, -0.6]:
			var candidate: Dictionary = Cube.address(body_id, face, 1.0 - 96.0 / float(system.bodies[body_id].radius), v)
			var sample: Dictionary = adapter.sample(candidate)
			if sample.height > 5.0 and sample.normal.dot(adapter.up_at(candidate)) > 0.98:
				spawn = candidate
				break
		if not spawn.is_empty():
			break
	assert(not spawn.is_empty(), "No dry M1d reference fixture")
	spawn.height = adapter.sample(spawn).height + 1.1
	var frame: Basis = adapter.frame_at(spawn)
	var tree_pose: Dictionary = _pose(adapter.offset(spawn, -frame.z * 12.0), -frame.z)
	tree_pose.merge({"object_id": body_id + ":m1d:tree", "asset_id": SurfaceTree.ASSET_ID})
	var home: Dictionary = adapter.offset(spawn, frame.x * 6.0 - frame.z * 6.0, 1.1)
	var specimen: Dictionary = _pose(home, -frame.z)
	specimen.merge({"object_id": body_id + ":m1d:creature", "design_id": "default_v7_fixture1", "home": home.duplicate(true),
		"goal": adapter.offset(home, -frame.z * 8.0, 1.1), "returning": false})
	return {"radius": system.bodies[body_id].radius, "seed": system.bodies[body_id].seed, "terrain_revision": 3,
		"spawn": spawn, "player": _pose(spawn, -frame.z), "tree": tree_pose, "creature": specimen}


func _pose(address: Dictionary, heading: Vector3, velocity_value: Vector3 = Vector3.ZERO, distance_value: float = 0.0) -> Dictionary:
	return {"location": address.duplicate(true), "forward": [heading.x, heading.y, heading.z],
		"velocity": [velocity_value.x, velocity_value.y, velocity_value.z], "traveled": distance_value}


func _capture() -> void:
	var record: Dictionary = records[body_id]
	record.player = _pose(adapter.location(walker), walker.forward, walker.velocity, walker.traveled)
	if is_instance_valid(tree):
		record.tree.merge(_pose(adapter.location(tree), -tree.basis.z), true)
	if is_instance_valid(creature):
		record.creature.merge(_pose(adapter.location(creature), creature.forward, creature.velocity, creature.traveled), true)
		record.creature.returning = creature.returning


func stream_objects() -> void:
	var record: Dictionary = records[body_id]
	for kind in ["tree", "creature"]:
		var node: Node3D = tree if kind == "tree" else creature
		var state: Dictionary = record[kind]
		var here: Dictionary = adapter.location(node) if is_instance_valid(node) else state.location
		var distance: float = adapter.to_local(here).distance_to(walker.position)
		if is_instance_valid(node) and distance > UNLOAD_RADIUS:
			_capture()
			adapter.unbind(state.object_id)
			remove_child(node)
			node.queue_free()
			if kind == "tree":
				tree = null
			else:
				creature = null
			object_unloads += 1
		elif not is_instance_valid(node) and distance <= ACTIVE_RADIUS and adapter.collision_ready(here):
			var started: int = Time.get_ticks_usec()
			if kind == "tree":
				tree = SurfaceTree.new()
				node = tree
			else:
				creature = Creature.new()
				creature.adapter = adapter
				creature.home = state.home.duplicate(true)
				creature.goal = state.goal.duplicate(true)
				creature.returning = state.returning
				creature.forward = Cube.vector(state.forward)
				creature.velocity = Cube.vector(state.velocity)
				creature.traveled = state.traveled
				creature.enabled = not paused
				node = creature
			add_child(node)
			adapter.bind(state.object_id, node, state.location, Cube.vector(state.forward))
			object_loads += 1
			max_object_build_ms = maxf(max_object_build_ms, (Time.get_ticks_usec() - started) / 1000.0)


func snapshot() -> Dictionary:
	_capture()
	return {"schema": 1, "fixture_revision": 1, "surface_mode": Cube.MODE, "body_id": body_id, "bodies": records.duplicate(true)}


func save_lab() -> bool:
	var error: Error = ERR_UNAVAILABLE if read_only else save_backend.write(snapshot(), store_path)
	status.text = "Spieler, Baum und Kreatur gesichert." if error == OK else "Sicherung nicht möglich (%s). Vorhandene Datei bleibt erhalten." % error
	leave_without_saving.visible = error != OK
	return error == OK


func load_lab() -> bool:
	var saved: Dictionary = save_backend.read(store_path)
	if saved.error != OK or saved.data.is_empty():
		status.text = "Keine lesbare M1d-Sicherung gefunden."
		return false
	records = saved.data.bodies
	read_only = false
	open_body(saved.data.body_id, false)
	status.text = "Gesicherte Körper und Orte wiederhergestellt."
	return true


func next_body() -> void:
	if not save_lab():
		return
	open_body(System.REAL_LANDABLE[(System.REAL_LANDABLE.find(body_id) + 1) % 3])


func return_to_marker() -> void:
	_capture()
	# Unload first, so an intercontinental teleport never gives live physics
	# objects enormous float transforms. Their double addresses remain stored.
	for kind in ["tree", "creature"]:
		var node: Node3D = tree if kind == "tree" else creature
		if is_instance_valid(node):
			adapter.unbind(records[body_id][kind].object_id)
			remove_child(node)
			node.queue_free()
	tree = null
	creature = null
	walker.place(records[body_id].spawn)
	stream_objects()
	status.text = "Zum gespeicherten Startort zurückgekehrt."


func leave_lab() -> void:
	if save_lab():
		get_tree().change_scene_to_file("res://world/planet_lab/planet_lab.tscn")


func set_paused(value: bool) -> void:
	paused = value
	walker.enabled = not value
	if is_instance_valid(creature):
		creature.enabled = not value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not _ready_complete:
		return
	_stream_elapsed += delta
	if _stream_elapsed >= 0.2:
		_stream_elapsed = 0.0
		stream_objects()
	var pose: Dictionary = walker.location()
	hud.text = "VOXELVERSE · M1d Oberflächenprobe\n%s · Durchmesser %.0f km · Seite %d\nSpieler %.2f m · Kreatur %.2f m · Bodenkontakt %s\n%d Kacheln · %d/24 Kollisionen · %d Ursprungswechsel\nObjekte %d/2 · geladen %d / entladen %d · Aufbau max. %.1f ms\nUrsprungsfehler max. %.4f mm%s" % [
		system.bodies[body_id].name, system.bodies[body_id].radius * 0.002, pose.face,
		walker.traveled, creature.traveled if is_instance_valid(creature) else records[body_id].creature.traveled,
		"ja" if walker.is_on_floor() else ("Wasser" if walker.swimming else "nein"),
		terrain.tiles.size(), terrain.active.size(), terrain.rebases, int(is_instance_valid(tree)) + int(is_instance_valid(creature)),
		object_loads, object_unloads, max_object_build_ms, adapter.max_rebase_error_m * 1000.0,
		"\nNahgelände wird vorbereitet …" if walker.waiting_for_terrain else ""]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_paused(false)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.turn(event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE: set_paused(not paused)
			KEY_SPACE: walker.jump_requested = true
			KEY_F5: save_lab()
			KEY_F9: load_lab()
			KEY_M: next_body()
			KEY_R: return_to_marker()


func _build_view() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("83b4ce")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d8e4")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("83b4ce")
	environment.fog_depth_begin = 1500.0
	environment.fog_depth_end = 18000.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 0.8
	_sun.shadow_enabled = true
	add_child(_sun)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var top := PanelContainer.new()
	top.position = Vector2(16, 16)
	canvas.add_child(top)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 18)
	top.add_child(hud)
	var panel := PanelContainer.new()
	canvas.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	panel.offset_top = -132
	var bottom := VBoxContainer.new()
	panel.add_child(bottom)
	var buttons := HFlowContainer.new()
	bottom.add_child(buttons)
	for entry in [["Sichern · F5", save_lab], ["Laden · F9", load_lab], ["Körper wechseln · M", next_body],
		["Startort · R", return_to_marker], ["Planetenlabor", leave_lab]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	leave_without_saving = Button.new()
	leave_without_saving.text = "Ohne M1d-Sicherung zurück"
	leave_without_saving.pressed.connect(func(): get_tree().change_scene_to_file("res://world/planet_lab/planet_lab.tscn"))
	leave_without_saving.hide()
	buttons.add_child(leave_without_saving)
	help_label = Label.new()
	help_label.text = "WASD Bewegen · Maus Umsehen · Leertaste Springen · Esc Pause / Maus\nBegrenzte Oberflächenprobe mit eigener Sicherung. Die Kampagne bleibt erhalten."
	bottom.add_child(help_label)
	status = Label.new()
	bottom.add_child(status)
