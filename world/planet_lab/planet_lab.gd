extends Node3D
class_name PlanetLab

const System = preload("res://world/space/celestial_system.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Tiles = preload("res://world/planet_lab/sphere_tiles.gd")
const Walker = preload("res://world/planet_lab/radial_walker.gd")
const LabSave = preload("res://world/planet_lab/planet_lab_save.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const MAIN_SCENE: String = "res://main/main.tscn"
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
	add_child(space)
	space.scale = Vector3.ONE * 0.01
	add_child(sky)
	add_child(space_camera)
	space_camera.far = 1000.0
	space_camera.near = 0.05
	space_camera.fov = 48.0
	_build_ui()
	var saved: Dictionary = LabSave.read()
	if not saved.is_empty():
		system = System.new(saved.binary)
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
				star.radius = body.radius
				star.height = body.radius * 2.0
				meshes[id] = star
			else:
				var builder := Tiles.new()
				builder.configure(body)
				meshes[id] = builder.orbital_mesh()
				builder.free()
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
				path.surface_add_vertex(Vector3(cos(angle), 0, sin(angle)) * float(body.orbit_radius))
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
			light.light_energy = 1.6 if id == "m1:sol" else 0.8
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 130.0
			add_child(light)
			lights[id] = light
	landing_marker = MeshInstance3D.new()
	var pin := SphereMesh.new()
	pin.radius = 3.0
	pin.height = 6.0
	landing_marker.mesh = pin
	var pin_material := StandardMaterial3D.new()
	pin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pin_material.albedo_color = Color("ffbe68")
	landing_marker.material_override = pin_material
	space.add_child(landing_marker)


func _body_visual(body: Dictionary, mesh: Mesh) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	if body.kind == "star":
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffdc9b") if body.id == "m1:sol" else Color("b8dcff")
	else:
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.95
	node.material_override = material
	if body.kind == "planet":
		var ocean := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = body.radius
		sphere.height = body.radius * 2.0
		sphere.radial_segments = 128
		sphere.rings = 64
		ocean.mesh = sphere
		var water_material := StandardMaterial3D.new()
		water_material.albedo_color = Color("247c9d")
		water_material.roughness = 0.26
		water_material.metallic = 0.15
		ocean.material_override = water_material
		node.add_child(ocean)
	return node


func _open_body(id: String, saved: Dictionary = {}) -> void:
	if is_instance_valid(walker):
		remove_child(walker)
		walker.queue_free()
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.queue_free()
	body_id = id
	terrain = Tiles.new()
	add_child(terrain)
	terrain.configure(system.bodies[id])
	walker = Walker.new()
	walker.terrain = terrain
	walker.creature_design = creature_design.duplicate(true)
	add_child(walker)
	var location: Dictionary = _coastal_spawn()
	var heading: Vector3 = Vector3.FORWARD
	if not saved.is_empty():
		location = saved.location
		heading = Cube.vector(saved.forward)
	walker.place(location, heading)
	set_view("surface")


func _coastal_spawn() -> Dictionary:
	var best: Dictionary = Cube.address(body_id, 4, 0.0, 0.3)
	var score: float = INF
	for face in range(6):
		for y in range(-4, 5):
			for x in range(-4, 5):
				var candidate: Dictionary = Cube.address(body_id, face, x * 0.2, y * 0.2)
				var d: Vector3 = Cube.vector(Cube.direction(face, candidate.u, candidate.v))
				var h: float = terrain.surface.height_at(d)
				var day: float = d.dot(system.sky_direction(body_id, "m1:sol"))
				var cost: float = absf(h - 2.8) + maxf(0.2 - day, 0.0) * 30.0 + absf(d.y)
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
	details.text = "%s  ·  %s  ·  Radius %d m\n%02d:%02d  ·  Zeit ×%.0f  ·  %d / %d Nahkacheln  ·  %d Ursprungswechsel" % [
		"Zwei Sonnen" if system.binary else "Eine Sonne", "Tag" if daylight > 0.0 else "Nacht", system.bodies[body_id].radius,
		int(system.elapsed) / 60, int(system.elapsed) % 60, time_speed, terrain.active.size(), Tiles.MAX_NEAR, terrain.rebases]
	help.text = "WASD  Bewegen     Maus  Umsehen     Leertaste  Springen     Esc  Maus lösen\nTab  Orbit / Landen     M  Nächster Körper     B  Zwei Sonnen     T  Zeit     F5 / F9  Sichern / Laden"


func _update_views() -> void:
	if not is_instance_valid(walker):
		return
	var body_position: Vector3 = system.position_at(body_id)
	var rotation: Basis = system.rotation_at(body_id)
	var address_value: Dictionary = walker.location()
	var local_point: Vector3 = Cube.vector(Cube.cartesian(address_value, system.bodies[body_id].radius))
	var up: Vector3 = local_point.normalized()
	var illumination: float = 0.0
	for id: String in system.bodies:
		var body: Dictionary = system.bodies[id]
		var body_rotation: Basis = system.rotation_at(id)
		space_bodies[id].position = system.position_at(id) - (body_position if view_mode == "orbit" else Vector3.ZERO)
		space_bodies[id].basis = body_rotation
		# System-map symbols are enlarged; their orbit centers/positions remain
		# physical. Orbit view always uses the real common radius and terrain.
		var symbol_radius: float = 550.0 if body.kind == "planet" else 250.0
		space_bodies[id].scale = Vector3.ONE * (maxf(1.0, symbol_radius / float(body.radius)) if view_mode == "system" else 1.0)
		body_labels[id].visible = view_mode == "system" and id != "m1:vesper"
		body_labels[id].text = "Solis + Vesper" if id == "m1:sol" and system.binary else body.name
		body_labels[id].position = space_bodies[id].position + Vector3(0, 200, symbol_radius + 240.0)
		if orbit_lines.has(id):
			orbit_lines[id].visible = view_mode == "system"
			orbit_lines[id].position = system.position_at(body.parent_id) if not str(body.parent_id).is_empty() else Vector3.ZERO
		sky_bodies[id].visible = id != body_id
		if id == body_id:
			continue
		var delta_position: Vector3 = rotation.inverse() * (system.position_at(id) - body_position) - local_point
		sky_bodies[id].position = walker.position + delta_position.normalized() * 900.0
		sky_bodies[id].basis = rotation.inverse() * body_rotation
		sky_bodies[id].scale = Vector3.ONE * (900.0 / delta_position.length())
		if lights.has(id):
			var direction: Vector3 = delta_position.normalized() if view_mode == "surface" else (system.position_at(id) - body_position).normalized()
			lights[id].basis = Basis.looking_at(-direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
			# A finite shadow map cannot represent the far side of the whole
			# planet. Its horizon must block a sun below the local surface too.
			var horizon: float = smoothstep(-0.03, 0.04, up.dot(delta_position.normalized())) if view_mode == "surface" else 1.0
			lights[id].light_energy = (1.6 if id == "m1:sol" else 0.8) * horizon
			illumination += maxf(0.0, up.dot(delta_position.normalized()))
	if view_mode == "surface":
		environment.background_color = Color("080e20").lerp(Color("6fa9c1"), clampf(illumination * 1.7, 0.0, 1.0))
		environment.ambient_light_energy = lerpf(0.12, 0.55, clampf(illumination, 0.0, 1.0))
		if system.bodies[body_id].atmosphere == "none":
			environment.background_color = Color("050913")
			environment.ambient_light_energy = 0.12
	else:
		environment.background_color = Color("080c18")
		environment.ambient_light_energy = 0.25
	var world_up: Vector3 = rotation * up
	landing_marker.position = (rotation * (local_point + up * 4.0)) + (Vector3.ZERO if view_mode == "orbit" else body_position)
	landing_marker.visible = view_mode == "orbit"
	if view_mode == "orbit":
		var distance: float = float(system.bodies[body_id].radius) * 0.053
		space_camera.position = world_up * distance + rotation * walker.forward * distance * 0.2
		space_camera.look_at(Vector3.ZERO, rotation * walker.forward)
	elif view_mode == "system":
		var minimum := Vector3(INF, 0, INF)
		var maximum := Vector3(-INF, 0, -INF)
		for id: String in system.bodies:
			var p: Vector3 = system.position_at(id) * 0.01
			minimum.x = minf(minimum.x, p.x)
			minimum.z = minf(minimum.z, p.z)
			maximum.x = maxf(maximum.x, p.x)
			maximum.z = maxf(maximum.z, p.z)
		var center: Vector3 = (minimum + maximum) * 0.5
		# Keep body centers in the free strip between the two HUD panels.
		space_camera.size = maxf(190.0, (maximum.z - minimum.z + 20.0) / 0.40)
		space_camera.size = maxf(space_camera.size, maximum.x - minimum.x + 40.0)
		space_camera.position = center + Vector3(0.0, 180.0, 0.01)
		space_camera.look_at(center, Vector3.FORWARD)
		for label in body_labels.values():
			label.pixel_size = 8.0 * space_camera.size / 190.0


func snapshot() -> Dictionary:
	return {"schema": 1, "surface_version": Cube.MODE, "body_id": body_id, "location": walker.location(),
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
	system = System.new(saved.binary)
	system.elapsed = saved.elapsed
	_build_system_view()
	_open_body(saved.body_id, saved)
	status.text = "Gesicherten Ort und Systemzeit wiederhergestellt."


func toggle_binary() -> void:
	var elapsed: float = system.elapsed
	system = System.new(not system.binary)
	system.elapsed = elapsed
	_build_system_view()
	_update_views()


func next_body() -> void:
	var index: int = System.LANDABLE.find(body_id)
	_open_body(System.LANDABLE[(index + 1) % System.LANDABLE.size()])
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


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)
