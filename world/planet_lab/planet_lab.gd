extends Node3D
class_name PlanetLab

const System = preload("res://world/space/celestial_system.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Tiles = preload("res://world/planet_lab/sphere_tiles.gd")
const AdaptiveTiles = preload("res://world/planet_lab/adaptive_sphere_tiles.gd")
const OrbitMesh = preload("res://world/planet_lab/planet_orbit_mesh.gd")
const Walker = preload("res://world/planet_lab/radial_walker.gd")
const LabSave = preload("res://world/planet_lab/planet_lab_save.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const MAIN_SCENE: String = "res://main/main.tscn"
const PRIMARY_LIGHT_ENERGY: float = 1.0
const SECONDARY_LIGHT_ENERGY: float = 0.45
var system: RefCounted = System.new()
var body_id: String = "m1:haven"
var terrain: Node3D
var walker: CharacterBody3D
var view_mode: String = "surface"
var time_speed: float = 1.0
var space := Node3D.new()
var sky := Node3D.new()
var space_camera := Camera3D.new()
var space_bodies: Dictionary = {}
var sky_bodies: Dictionary = {}
var body_labels: Dictionary = {}
var orbit_lines: Dictionary = {}
var meshes: Dictionary = {}
var lights: Dictionary = {}
var landing_marker: MeshInstance3D
var environment := Environment.new()
var headline: Label
var details: Label
var status: Label
var help: Label
var _old_autosave: bool = true
var _ready_complete: bool = false
var _save_read_only: bool = false
var creature_design: Dictionary = {}
var leave_without_saving: Button
var underwater: UnderwaterView
const SPACE_SCALE: float = 0.001
var _space_scale: float = SPACE_SCALE
var _opening_large: bool = false


func _ready() -> void:
	creature_design = Blueprint.load_best_available()
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		_old_autosave = saves.autosave_enabled
		saves.autosave_enabled = false
	var world_environment := WorldEnvironment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aacc6")
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	underwater = preload("res://world/visuals/underwater_view.gd").new()
	underwater.sample_water = _sample_camera_water
	add_child(underwater)
	add_child(space)
	space.scale = Vector3.ONE
	add_child(sky)
	add_child(space_camera)
	space_camera.far = 1000.0
	space_camera.near = 0.05
	space_camera.fov = 48.0
	_build_ui()
	var saved: Dictionary = LabSave.read()
	if not saved.is_empty():
		system = System.new(saved.binary, saved.get("scale_mode", "test") == "real")
		system.elapsed = saved.elapsed
		body_id = saved.body_id
	elif FileAccess.file_exists(LabSave.PATH) or FileAccess.file_exists(LabSave.PATH + ".bak"):
		_save_read_only = true
	_build_system_view()
	_open_body(body_id, saved)
	_ready_complete = true
	if "--planet-lab" in OS.get_cmdline_user_args():
		print("PLANET_LAB_READY ", body_id)
	if _save_read_only:
		status.text = "Laborsicherung nicht lesbar. Sie wird nicht überschrieben."
	else:
		status.text = "Klicke in die Landschaft, um loszulaufen."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.autosave_enabled = _old_autosave
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _ready_complete:
		save_lab()


func _build_system_view() -> void:
	for child in space.get_children():
		space.remove_child(child)
		child.queue_free()
	for child in sky.get_children():
		sky.remove_child(child)
		child.queue_free()
	for light in lights.values():
		remove_child(light)
		light.queue_free()
	space_bodies.clear()
	sky_bodies.clear()
	body_labels.clear()
	orbit_lines.clear()
	lights.clear()
	for id: String in system.bodies:
		var body: Dictionary = system.bodies[id]
		if not meshes.has(id):
			if body.kind == "star":
				var star := SphereMesh.new()
				star.radius = 1.0
				star.height = 2.0
				meshes[id] = {"land": star}
			else:
				meshes[id] = OrbitMesh.build(body)
		var node := _body_visual(body, meshes[id])
		space.add_child(node)
		space_bodies[id] = node
		var label := Label3D.new()
		label.text = body.name
		label.font_size = 48
		label.pixel_size = 8.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		space.add_child(label)
		body_labels[id] = label
		if body.orbit_radius > 0.0:
			var orbit := MeshInstance3D.new()
			var path := ImmediateMesh.new()
			var path_material := StandardMaterial3D.new()
			path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			path_material.albedo_color = Color("304153")
			path.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, path_material)
			for step in range(129):
				var angle: float = step * TAU / 128.0
				path.surface_add_vertex(Vector3(cos(angle), 0, sin(angle)))
			path.surface_end()
			orbit.mesh = path
			space.add_child(orbit)
			orbit_lines[id] = orbit
		var sky_node := _body_visual(body, meshes[id])
		sky.add_child(sky_node)
		sky_bodies[id] = sky_node
		if body.kind == "star":
			var light := DirectionalLight3D.new()
			light.light_color = Color("ffe2b2") if id == "m1:sol" else Color("b8d6ff")
			light.light_energy = PRIMARY_LIGHT_ENERGY if id == "m1:sol" else SECONDARY_LIGHT_ENERGY
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 130.0
			add_child(light)
			lights[id] = light
	landing_marker = MeshInstance3D.new()
	var pin := SphereMesh.new()
	pin.radius = 16.0
	pin.height = 32.0
	landing_marker.mesh = pin
	var pin_material := StandardMaterial3D.new()
	pin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin_material.albedo_color = Color("ffbe68")
	landing_marker.material_override = pin_material
	space.add_child(landing_marker)


func _body_visual(body: Dictionary, model: Dictionary) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = model.land
	var material := StandardMaterial3D.new()
	if body.kind == "star":
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffdc9b") if body.id == "m1:sol" else Color("b8dcff")
	else:
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.95
	node.material_override = material
	if body.kind == "planet" and model.water != null:
		var ocean := MeshInstance3D.new()
		ocean.mesh = model.water
		var water_material := StandardMaterial3D.new()
		water_material.albedo_color = Color("247c9d")
		water_material.roughness = 0.26
		water_material.metallic = 0.15
		ocean.material_override = water_material
		node.add_child(ocean)
	return node


func _open_body(id: String, saved: Dictionary = {}) -> void:
	var full_size: bool = id in System.REAL_LANDABLE
	if full_size != system.real_scale:
		var time: float = system.elapsed
		system = System.new(system.binary, full_size)
		system.elapsed = time
		_build_system_view()
	if is_instance_valid(walker):
		remove_child(walker)
		walker.queue_free()
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.queue_free()
	body_id = id
	terrain = AdaptiveTiles.new() if system.bodies[id].get("adaptive_tiles", false) else Tiles.new()
	add_child(terrain)
	terrain.configure(system.bodies[id])
	walker = Walker.new()
	walker.terrain = terrain
	walker.creature_design = creature_design.duplicate(true)
	add_child(walker)
	walker.camera.far = 50000.0 if system.real_scale else maxf(1800.0, float(system.bodies[id].radius) * 2.0)
	walker.camera.near = 0.2 if system.real_scale else 0.05
	var location: Dictionary = _coastal_spawn()
	var heading: Vector3 = Vector3.FORWARD
	if not saved.is_empty():
		location = saved.location
		if int(saved.get("terrain_revision", 1)) < System.TERRAIN_REVISION:
			location = _migrate_location(location)
		heading = Cube.vector(saved.forward)
	walker.place(location, heading)
	set_view("surface")


func _migrate_location(location: Dictionary) -> Dictionary:
	var migrated: Dictionary = location.duplicate(true)
	var old_body: Dictionary = system.bodies[body_id].duplicate(true)
	old_body.radius = System.PREVIOUS_RADII[body_id]
	old_body.terrain_revision = 1
	var previous := preload("res://world/space/planet_surface.gd").new(old_body)
	var old_height: float = previous.sample(location).height
	var new_height: float = terrain.surface.sample(location).height
	if not (old_height < 0.0 and new_height < 0.0 and system.bodies[body_id].kind == "planet" and location.height > old_height + 1.5):
		migrated.height = new_height + maxf(float(location.height) - old_height, 1.05)
	return migrated


func _sample_camera_water(point: Vector3) -> Dictionary:
	if view_mode != "surface" or not is_instance_valid(terrain) or system.bodies[body_id].kind != "planet":
		return {}
	var address: Dictionary = Cube.from_cartesian(body_id, Cube.global_position(point, terrain.origin), system.bodies[body_id].radius)
	if address.height >= 0.0:
		return {}
	return {"water": terrain.surface.sample(address).water, "depth": -float(address.height), "color": Color("12546a")}


func _coastal_spawn() -> Dictionary:
	var best: Dictionary = Cube.address(body_id, 4, 0.0, 0.3)
	var score: float = INF
	for face in range(6):
		for y in range(-4, 5):
			for x in range(-4, 5):
				var candidate: Dictionary = Cube.address(body_id, face, x * 0.2, y * 0.2)
				var d: Vector3 = Cube.vector(Cube.direction(face, candidate.u, candidate.v))
				var h: float = terrain.surface.height_precise(Cube.direction(face, candidate.u, candidate.v))
				var day: float = d.dot(system.sky_direction(body_id, "m1:sol"))
				var cost: float = absf(h - 2.8) + maxf(0.2 - day, 0.0) * (10000.0 if system.real_scale else 30.0) + absf(d.y)
				if cost < score:
					score = cost
					best = candidate
	best.height = terrain.surface.sample(best).height + 1.5
	return best


func set_view(mode: String) -> void:
	view_mode = mode
	var on_surface: bool = mode == "surface"
	terrain.visible = on_surface
	walker.visible = on_surface
	walker.enabled = on_surface
	sky.visible = on_surface
	space.visible = not on_surface
	if on_surface:
		walker.camera.make_current()
	else:
		space_camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	space_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if mode == "system" else Camera3D.PROJECTION_PERSPECTIVE
	space_camera.size = 190.0
	_update_views()


func _process(delta: float) -> void:
	if not _ready_complete:
		return
	system.elapsed += delta * time_speed
	_update_views()
	var address_value: Dictionary = walker.location()
	var up: Vector3 = Cube.vector(Cube.direction(address_value.face, address_value.u, address_value.v))
	var daylight: float = up.dot(system.sky_direction(body_id, "m1:sol"))
	headline.text = "%s  /  %s" % [system.bodies[body_id].name, {"surface": "Oberfläche", "orbit": "Orbit", "system": "Sternsystem"}[view_mode]]
	details.text = "%s  ·  %s  ·  Durchmesser %.2f km\n%02d:%02d  ·  Zeit ×%.0f  ·  %d / %d Nahkacheln  ·  %d Ursprungswechsel" % [
		"Zwei Sonnen" if system.binary else "Eine Sonne", "Tag" if daylight > 0.0 else "Nacht", float(system.bodies[body_id].radius) * 0.002,
		int(system.elapsed) / 60, int(system.elapsed) % 60, time_speed, terrain.active.size(), Tiles.MAX_NEAR, terrain.rebases]
	if terrain is AdaptiveSphereTiles:
		details.text += "\n%d Kacheln · Detailstufen %d–%d · %s" % [terrain.tiles.size(), terrain.layout.root_level, terrain.layout.max_level,
			"Gelände wird berechnet" if terrain.pending_count() < 0 else "%d Kacheln vorbereitet" % terrain.pending_count()]
	if view_mode == "system" and system.real_scale:
		details.text += "\nKartenansicht mit vergrößerten Körpersymbolen"
	if walker.waiting_for_terrain:
		details.text += "\nNahgelände wird nachgeladen – einen Moment …"
	help.text = "WASD  Bewegen     Maus  Umsehen     Leertaste  Springen     Esc  Einstellungen\nTab  Orbit / Landen     M  Nächster Körper     B  Zwei Sonnen     T  Zeit     F5 / F9  Sichern / Laden"


func _update_views() -> void:
	if not is_instance_valid(walker):
		return
	var body_position: Array = system.position_precise(body_id)
	var rotation: Basis = system.rotation_at(body_id)
	var address_value: Dictionary = walker.location()
	var local_point: Vector3 = Cube.vector(Cube.cartesian(address_value, system.bodies[body_id].radius))
	var up: Vector3 = Cube.vector(Cube.direction(address_value.face, address_value.u, address_value.v))
	var origin: Array = body_position if view_mode == "orbit" else [0.0, 0.0, 0.0]
	_space_scale = SPACE_SCALE
	if system.real_scale:
		_space_scale = 8.0 / float(system.bodies[body_id].radius) if view_mode == "orbit" else 300.0 / 240000000000.0
	var illumination: float = 0.0
	var minimum := Vector3(INF, 0, INF)
	var maximum := Vector3(-INF, 0, -INF)
	for id: String in system.bodies:
		var body: Dictionary = system.bodies[id]
		var p: Vector3 = Cube.scaled_offset(system.position_precise(id), origin, _space_scale)
		space_bodies[id].position = p
		space_bodies[id].basis = system.rotation_at(id)
		var real_radius: float = float(body.radius) * _space_scale
		var symbol_radius: float = real_radius
		if view_mode == "system":
			symbol_radius = maxf(real_radius, 4.0 if body.kind == "star" else (1.5 if body.kind == "planet" else 0.7))
		space_bodies[id].scale = Vector3.ONE * symbol_radius
		minimum.x = minf(minimum.x, p.x)
		minimum.z = minf(minimum.z, p.z)
		maximum.x = maxf(maximum.x, p.x)
		maximum.z = maxf(maximum.z, p.z)
		body_labels[id].visible = view_mode == "system"
		body_labels[id].text = "%s · %.1f km" % [body.name, float(body.radius) * 0.002]
		body_labels[id].position = p + Vector3(0, 0.2, symbol_radius + 2.5)
		if orbit_lines.has(id):
			orbit_lines[id].visible = view_mode == "system"
			var parent: Array = system.position_precise(body.parent_id) if not str(body.parent_id).is_empty() else [0.0, 0.0, 0.0]
			orbit_lines[id].position = Cube.scaled_offset(parent, origin, _space_scale)
			orbit_lines[id].scale = Vector3.ONE * float(body.orbit_radius) * _space_scale
		sky_bodies[id].visible = id != body_id
		if id == body_id:
			continue
		var delta_position: Vector3 = rotation.inverse() * Cube.scaled_offset(system.position_precise(id), body_position, 1.0) - local_point
		sky_bodies[id].position = walker.position + delta_position.normalized() * 900.0
		sky_bodies[id].basis = rotation.inverse() * system.rotation_at(id)
		sky_bodies[id].scale = Vector3.ONE * (float(body.radius) * 900.0 / delta_position.length())
		if lights.has(id):
			var direction: Vector3 = delta_position.normalized() if view_mode == "surface" else Cube.scaled_offset(system.position_precise(id), body_position, 1.0).normalized()
			lights[id].basis = Basis.looking_at(-direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
			var horizon: float = smoothstep(-0.03, 0.04, up.dot(delta_position.normalized())) if view_mode == "surface" else 1.0
			lights[id].light_energy = (PRIMARY_LIGHT_ENERGY if id == "m1:sol" else SECONDARY_LIGHT_ENERGY) * horizon
			illumination += maxf(0.0, up.dot(delta_position.normalized()))
	if view_mode == "surface":
		environment.background_color = Color("080e20").lerp(Color("6fa9c1"), clampf(illumination * 1.7, 0.0, 1.0))
		environment.ambient_light_energy = lerpf(0.12, 0.35, clampf(illumination, 0.0, 1.0))
		if system.bodies[body_id].atmosphere == "none":
			environment.background_color = Color("050913")
			environment.ambient_light_energy = 0.12
	else:
		environment.background_color = Color("080c18")
		environment.ambient_light_energy = 0.25
	environment.fog_enabled = system.real_scale and view_mode == "surface"
	if environment.fog_enabled:
		environment.fog_mode = Environment.FOG_MODE_DEPTH
		environment.fog_light_color = environment.background_color
		environment.fog_depth_begin = 1200.0
		environment.fog_depth_end = 25000.0
		environment.fog_sky_affect = 0.0
	var world_up: Vector3 = rotation * up
	landing_marker.position = (rotation * (local_point + up * 4.0)) * _space_scale
	landing_marker.scale = Vector3.ONE * maxf(float(system.bodies[body_id].radius) * _space_scale * 0.003 / 16.0, 0.0001)
	landing_marker.visible = view_mode == "orbit"
	if view_mode == "orbit":
		var distance: float = float(system.bodies[body_id].radius) * _space_scale * 5.3
		space_camera.position = world_up * distance + rotation * walker.forward * distance * 0.2
		space_camera.look_at(Vector3.ZERO, rotation * walker.forward)
	elif view_mode == "system":
		var center: Vector3 = (minimum + maximum) * 0.5
		space_camera.size = maxf(190.0, (maximum.z - minimum.z + 20.0) / 0.40)
		space_camera.size = maxf(space_camera.size, maximum.x - minimum.x + 40.0)
		if system.real_scale:
			# Include complete paths, not just the planets' current positions.
			center = Vector3.ZERO
			var extent: float = 0.0
			for id: String in orbit_lines:
				extent = maxf(extent, orbit_lines[id].position.length() + float(system.bodies[id].orbit_radius) * _space_scale)
			space_camera.size = maxf(190.0, extent * 2.0 / 0.40)
			for id: String in space_bodies:
				var symbol_size: float = space_camera.size * (0.006 if system.bodies[id].kind == "star" else 0.003)
				space_bodies[id].scale = Vector3.ONE * symbol_size
		space_camera.position = center + Vector3(0.0, 180.0, 0.01)
		space_camera.look_at(center, Vector3.FORWARD)
		for id: String in body_labels:
			var label: Label3D = body_labels[id]
			label.pixel_size = 0.08 * space_camera.size / 190.0
			var body: Dictionary = system.bodies[id]
			if not str(body.parent_id).is_empty() and system.bodies[body.parent_id].kind == "planet":
				label.position.z -= space_camera.size * 0.08
			elif body.kind == "star":
				var star_offset: float = (-0.13 if system.real_scale else -0.07) if id == "m1:vesper" else 0.045
				label.position.z += space_camera.size * star_offset


func snapshot() -> Dictionary:
	return {"schema": 3 if system.real_scale else 2, "scale_mode": "real" if system.real_scale else "test", "terrain_revision": 3 if system.real_scale else System.TERRAIN_REVISION, "surface_version": Cube.MODE, "body_id": body_id, "location": walker.location(),
		"forward": [walker.forward.x, walker.forward.y, walker.forward.z], "elapsed": system.elapsed, "binary": system.binary}


func save_lab() -> bool:
	if _save_read_only:
		status.text = "Vorhandene Laborsicherung geschützt; Speichern nicht möglich."
		return false
	var error: Error = LabSave.write(snapshot())
	status.text = "Ort und Systemzeit gesichert." if error == OK else "Sichern fehlgeschlagen (%s)." % error
	return error == OK


func load_lab() -> void:
	var saved: Dictionary = LabSave.read()
	if saved.is_empty():
		status.text = "Keine gültige Laborsicherung gefunden."
		return
	_save_read_only = false
	system = System.new(saved.binary, saved.get("scale_mode", "test") == "real")
	system.elapsed = saved.elapsed
	_build_system_view()
	_open_body(saved.body_id, saved)
	status.text = "Gesicherten Ort und Systemzeit wiederhergestellt."


func toggle_binary() -> void:
	var elapsed: float = system.elapsed
	system = System.new(not system.binary, system.real_scale)
	system.elapsed = elapsed
	_build_system_view()
	_update_views()


func next_body() -> void:
	var index: int = system.landable_ids().find(body_id)
	_open_body(system.landable_ids()[(index + 1) % system.landable_ids().size()])
	status.text = "Technikreise: %s. Tab öffnet den Orbit." % system.bodies[body_id].name


func cycle_time() -> void:
	var speeds: Array = [0.0, 1.0, 4.0, 20.0]
	time_speed = speeds[(speeds.find(time_speed) + 1) % speeds.size()]


func return_to_game() -> void:
	if not save_lab():
		leave_without_saving.show()
		return
	_leave_lab()


func _leave_lab() -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.load_now()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and view_mode == "surface":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.turn(event.relative)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		KEY_TAB: set_view("orbit" if view_mode == "surface" else "surface")
		KEY_SPACE: walker.jump_requested = true
		KEY_M: next_body()
		KEY_B: toggle_binary()
		KEY_T: cycle_time()
		KEY_F5: save_lab()
		KEY_F9: load_lab()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(28, 28)
	top.custom_minimum_size = Vector2(520, 164)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _panel())
	root.add_child(top)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	top.add_child(stack)
	var eyebrow := Label.new()
	eyebrow.text = "V O X E L V E R S E   /   P L A N E T E N L A B O R"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("80d4c1"))
	stack.add_child(eyebrow)
	headline = Label.new()
	headline.add_theme_font_size_override("font_size", 29)
	stack.add_child(headline)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 16)
	details.add_theme_color_override("font_color", Color("c3cdd7"))
	stack.add_child(details)
	var badge := Label.new()
	badge.text = "M1  /  TECHNIKPROTOTYP"
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-280, 38)
	badge.add_theme_color_override("font_color", Color("a4bccb"))
	root.add_child(badge)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -192
	bottom.offset_bottom = -28
	bottom.add_theme_stylebox_override("panel", _panel())
	root.add_child(bottom)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	bottom.add_child(column)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_button(buttons, "Oberfläche", func(): set_view("surface"))
	_button(buttons, "Orbit", func(): set_view("orbit"))
	_button(buttons, "Sternsystem", func(): set_view("system"))
	_button(buttons, "Körper wechseln", next_body)
	var large_button: Button = _button(buttons, "Terra · 12.742 km", _open_large_reference)
	large_button.name = "OpenTerra"
	_button(buttons, "Aster · 8 km", func(): _open_body("m1:aster"))
	_button(buttons, "Sonnen wechseln", toggle_binary)
	_button(buttons, "Zeit", cycle_time)
	_button(buttons, "Sichern", save_lab)
	_button(buttons, "Zurück zum Spiel", return_to_game)
	leave_without_saving = Button.new()
	leave_without_saving.text = "Zurück ohne Laborsicherung"
	leave_without_saving.pressed.connect(_leave_lab)
	buttons.add_child(leave_without_saving)
	leave_without_saving.hide()
	help = Label.new()
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color("9caec0"))
	column.add_child(help)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color("e2bf87"))
	column.add_child(status)


func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.92)
	style.border_color = Color(0.3, 0.55, 0.6, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _open_large_reference() -> void:
	if _opening_large:
		return
	_opening_large = true
	status.text = "Terra wird geladen …"
	await get_tree().process_frame
	await get_tree().process_frame
	_open_body("m1b:terra")
	_opening_large = false
	status.text = "Originalgröße: 12.742 km Durchmesser."


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
