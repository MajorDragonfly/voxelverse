extends Node3D
class_name PlanetLab

const System = preload("res://world/space/celestial_system.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Tiles = preload("res://world/planet_lab/sphere_tiles.gd")
const AdaptiveTiles = preload("res://world/planet_lab/adaptive_sphere_tiles.gd")
const OrbitMesh = preload("res://world/planet_lab/planet_orbit_mesh.gd")
const Walker = preload("res://world/planet_lab/radial_walker.gd")
const LabSave = preload("res://world/planet_lab/planet_lab_save.gd")
const GalaxyPanel = preload("res://world/planet_lab/galaxy_catalog_panel.gd")
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Visits = preload("res://world/space/galaxy_visits.gd")
var catalog: RefCounted = Catalog.new()
var visits: RefCounted
var visit_record: Dictionary = {}
var _visits_error: Error = OK
var _system_extent: float = 1.0
var _system_legend: PanelContainer
var _legend_entries: VBoxContainer
var galaxy_panel: CanvasLayer
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
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
var map_atlases: Dictionary = {}
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
	map_atlases = saved.get("map_atlases", {}).duplicate(true)
	if not saved.is_empty():
		_restore_system(saved)
		body_id = saved.body_id
	elif FileAccess.file_exists(LabSave.PATH) or FileAccess.file_exists(LabSave.PATH + ".bak"):
		_save_read_only = true
	_build_system_view()
	_open_body(body_id, saved)
	_ready_complete = true
	var minimap := preload("res://ui/minimap/minimap_hud.gd").new()
	minimap.lab = self
	add_child(minimap)
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
	# Keep orbital resources bounded to the one currently open system.
	meshes.clear()
	_system_extent = system.extent_meters()
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
		# Camera-relative sky models must not cast camera-relative shadows.
		sky_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child in sky_node.get_children():
			if child is GeometryInstance3D:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sky.add_child(sky_node)
		sky_bodies[id] = sky_node
		if body.kind == "star":
			var light := DirectionalLight3D.new()
			light.light_color = Color("ffe2b2") if id == system.primary_star_id() else Color("b8d6ff")
			light.light_energy = PRIMARY_LIGHT_ENERGY if id == system.primary_star_id() else SECONDARY_LIGHT_ENERGY
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
	_refresh_system_legend()


func _body_visual(body: Dictionary, model: Dictionary) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = model.land
	var material := StandardMaterial3D.new()
	if body.kind == "star":
		# This mesh depicts the light source; it must not eclipse its own light.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffdc9b") if body.id == system.primary_star_id() else Color("b8dcff")
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
	var leaving_catalog: bool = not system.catalog_id.is_empty() and id in System.LANDABLE + System.REAL_LANDABLE
	if leaving_catalog and is_instance_valid(walker) and not save_lab():
		return
	var full_size: bool = id in System.REAL_LANDABLE or (not leaving_catalog and not system.catalog_id.is_empty())
	if full_size != system.real_scale or leaving_catalog:
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
	var location: Dictionary = _coastal_spawn() if saved.is_empty() else saved.location
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
	var dry: Dictionary = {}
	var dry_score: float = INF
	for face in range(6):
		for y in range(-4, 5):
			for x in range(-4, 5):
				var candidate: Dictionary = Cube.address(body_id, face, x * 0.2, y * 0.2)
				var d: Vector3 = Cube.vector(Cube.direction(face, candidate.u, candidate.v))
				var h: float = terrain.surface.height_precise(Cube.direction(face, candidate.u, candidate.v))
				var day: float = d.dot(system.sky_direction(body_id, system.primary_star_id()))
				var cost: float = absf(h - 2.8) + maxf(0.2 - day, 0.0) * (10000.0 if system.real_scale else 30.0) + absf(d.y)
				if cost < score:
					score = cost
					best = candidate
				if not system.catalog_id.is_empty() and h >= 4.0 and cost < dry_score:
					if terrain.surface.sample(candidate).normal.dot(d) > 0.94:
						dry = candidate
						dry_score = cost
	# An unknown catalog coast can have shallow water at the best height score.
	# Prefer a dry, walkable landing even when another hemisphere scores better.
	if not dry.is_empty():
		best = dry
	best.height = terrain.surface.sample(best).height + 1.5
	if not system.catalog_id.is_empty() and system.bodies[body_id].kind == "planet":
		best.height = maxf(best.height, 0.6)
	return best


func set_view(mode: String) -> void:
	view_mode = mode
	var on_surface: bool = mode == "surface"
	terrain.visible = on_surface
	walker.visible = on_surface
	walker.enabled = on_surface
	sky.visible = on_surface
	space.visible = not on_surface
	_system_legend.visible = mode == "system" and not system.catalog_id.is_empty()
	if on_surface:
		walker.camera.make_current()
	else:
		space_camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	space_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if mode == "system" else Camera3D.PROJECTION_PERSPECTIVE
	space_camera.size = 190.0
	_update_views()


func _process(delta: float) -> void:
	if is_instance_valid(galaxy_panel) or _opening_large:
		return
	if not _ready_complete:
		return
	system.elapsed += delta * time_speed
	_update_views()
	var address_value: Dictionary = walker.location()
	var up: Vector3 = Cube.vector(Cube.direction(address_value.face, address_value.u, address_value.v))
	var daylight: float = up.dot(system.sky_direction(body_id, system.primary_star_id()))
	headline.text = "%s  /  %s" % [system.bodies[body_id].name, {"surface": "Oberfläche", "orbit": "Orbit", "system": "Sternsystem"}[view_mode]]
	details.text = "%s  ·  %s  ·  Durchmesser %.2f km\n%02d:%02d  ·  Zeit ×%.0f  ·  %d / %d Nahkacheln  ·  %d Ursprungswechsel" % [
		"Zwei Sonnen" if system.binary else "Eine Sonne", "Tag" if daylight > 0.0 else "Nacht", float(system.bodies[body_id].radius) * 0.002,
		int(system.elapsed) / 60, int(system.elapsed) % 60, time_speed, terrain.active.size(), Tiles.MAX_NEAR, terrain.rebases]
	if terrain is AdaptiveSphereTiles:
		details.text += "\n%d Kacheln · Detailstufen %d–%d · %s" % [terrain.tiles.size(), terrain.layout.root_level, terrain.layout.max_level,
			"Gelände wird berechnet" if terrain.pending_count() < 0 else "%d Kacheln vorbereitet" % terrain.pending_count()]
	if view_mode == "system" and system.real_scale:
		details.text += "\nKartenansicht mit vergrößerten Körpersymbolen"
	if not system.catalog_id.is_empty():
		details.text += "\n" + system.catalog_name + " · Rückkehrpunkt je Planet"
	if walker.waiting_for_terrain:
		details.text += "\nNahgelände wird nachgeladen – einen Moment …"
	help.text = "WASD  Bewegen     Maus  Umsehen     Leertaste  Springen     Esc  Einstellungen\nTab  Orbit / Landen     M  Nächster Körper     B  Zwei Sonnen     T  Zeit     F5 / F9  Sichern / Laden"
	if not system.catalog_id.is_empty():
		help.text = help.text.replace("B  Zwei Sonnen     ", "")


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
		_space_scale = 8.0 / float(system.bodies[body_id].radius) if view_mode == "orbit" else 300.0 / _system_extent
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
		body_labels[id].visible = view_mode == "system" and (system.catalog_id.is_empty() or id == body_id)
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
			lights[id].light_energy = (PRIMARY_LIGHT_ENERGY if id == system.primary_star_id() else SECONDARY_LIGHT_ENERGY) * horizon
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
	environment.fog_enabled = system.real_scale and view_mode == "surface" and system.bodies[body_id].atmosphere != "none"
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
				var star_offset: float = (-0.13 if system.real_scale else -0.07) if id != system.primary_star_id() else 0.045
				label.position.z += space_camera.size * star_offset


func snapshot() -> Dictionary:
	var result: Dictionary = {"schema": 3 if system.real_scale else 2, "scale_mode": "real" if system.real_scale else "test", "terrain_revision": 3 if system.real_scale else System.TERRAIN_REVISION, "surface_version": Cube.MODE, "body_id": body_id, "location": walker.location(),
		"forward": [walker.forward.x, walker.forward.y, walker.forward.z], "elapsed": system.elapsed, "binary": system.binary}
	if not system.catalog_id.is_empty():
		result.merge({"schema": 4, "catalog_version": Catalog.VERSION, "system_id": system.catalog_id}, true)
	result["map_atlases"] = map_atlases.duplicate(true)
	return result


func save_lab() -> bool:
	if _save_read_only:
		status.text = "Vorhandene Laborsicherung geschützt; Speichern nicht möglich."
		return false
	for tracker: Node in get_tree().get_nodes_in_group(&"exploration_tracker"):
		if tracker.lab == self: tracker.update_exploration(true)
	var data: Dictionary = snapshot()
	var error: Error = _save_visit(data) if not system.catalog_id.is_empty() else OK
	if error == OK:
		error = LabSave.write(data)
	status.text = "Ort und Systemzeit gesichert." if error == OK else "Sichern fehlgeschlagen (%s)." % error
	return error == OK


func load_lab() -> void:
	var saved: Dictionary = LabSave.read()
	if saved.is_empty():
		status.text = "Keine gültige Laborsicherung gefunden."
		return
	_save_read_only = false
	map_atlases = saved.get("map_atlases", {}).duplicate(true)
	for tracker: Node in get_tree().get_nodes_in_group(&"exploration_tracker"):
		if tracker.lab == self: tracker.invalidate()
	_restore_system(saved)
	_build_system_view()
	_open_body(saved.body_id, saved)
	status.text = "Gesicherten Ort und Systemzeit wiederhergestellt."


func toggle_binary() -> void:
	if not system.catalog_id.is_empty():
		status.text = "Dieses Katalogsystem hat dauerhaft %d Sonne(n)." % lights.size()
		return
	var elapsed: float = system.elapsed
	system = System.new(not system.binary, system.real_scale)
	system.elapsed = elapsed
	_build_system_view()
	_update_views()


func next_body() -> void:
	var index: int = system.landable_ids().find(body_id)
	var next: String = system.landable_ids()[(index + 1) % system.landable_ids().size()]
	if not system.catalog_id.is_empty():
		visit_planet(system.catalog_id, next)
		return
	_open_body(next)
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
	get_node("/root/SessionFlow").return_from_planet_lab()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(galaxy_panel) or _opening_large:
		return
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
	_system_legend = PanelContainer.new()
	_system_legend.name = "SystemLegend"
	_system_legend.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_system_legend.offset_left = -360
	_system_legend.offset_right = -28
	_system_legend.offset_top = 28
	_system_legend.offset_bottom = -216
	_system_legend.add_theme_stylebox_override("panel", _panel())
	_system_legend.hide()
	root.add_child(_system_legend)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_system_legend.add_child(scroll)
	_legend_entries = VBoxContainer.new()
	_legend_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend_entries.add_theme_constant_override("separation", 10)
	scroll.add_child(_legend_entries)
	var bottom := PanelContainer.new()
	bottom.name = "PlanetLabBottom"
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
	_button(buttons, "Galaxiekatalog", open_galaxy_catalog).name = "OpenGalaxy"
	_button(buttons, "Körper wechseln", next_body)
	var large_button: Button = _button(buttons, "Terra · 12.742 km", _open_large_reference)
	large_button.name = "OpenTerra"
	_button(buttons, "M1d · Spieler, Baum, Kreatur", func():
		if save_lab():
			get_tree().change_scene_to_file("res://world/planet_lab/surface_adapter_lab.tscn")
	).name = "OpenSurfaceAdapter"
	_button(buttons, "Belebter Voxelplanet", func():
		if save_lab():
			get_tree().change_scene_to_file("res://world/planet_lab/living_planet.tscn")
	).name = "OpenLivingPlanet"
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


func _refresh_system_legend() -> void:
	if _legend_entries == null:
		return
	for child in _legend_entries.get_children():
		_legend_entries.remove_child(child)
		child.queue_free()
	if system.catalog_id.is_empty():
		return
	var title := Label.new()
	title.text = system.catalog_name + " · Körper"
	title.add_theme_color_override("font_color", Color("80d4c1"))
	_legend_entries.add_child(title)
	var kinds: Dictionary = {"star": "Stern", "planet": "Gesteinsplanet", "gas_giant": "Gasriese", "moon": "Mond"}
	for body: Dictionary in system.bodies.values():
		var label := Label.new()
		label.text = "%s\n%s · Ø %.1f km" % [body.name, kinds[body.kind], float(body.radius) * 0.002]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		_legend_entries.add_child(label)


func open_galaxy_catalog() -> void:
	if is_instance_valid(galaxy_panel):
		return
	var previous_enabled: bool = walker.enabled
	walker.enabled = false
	galaxy_panel = GalaxyPanel.new()
	galaxy_panel.catalog = catalog
	galaxy_panel.initial_system_id = system.catalog_id
	galaxy_panel.visit_requested.connect(_on_visit_requested)
	galaxy_panel.closed.connect(func():
		walker.enabled = previous_enabled
		galaxy_panel = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	add_child(galaxy_panel)


func _on_visit_requested(system_id: String, target_id: String) -> void:
	if _opening_large:
		return
	_opening_large = true
	galaxy_panel.travel_in_progress = true
	galaxy_panel.message.text = "Oberfläche wird vorbereitet …"
	galaxy_panel.visit_button.disabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	var succeeded: bool = visit_planet(system_id, target_id)
	_opening_large = false
	if is_instance_valid(galaxy_panel):
		galaxy_panel.travel_in_progress = false
		if succeeded:
			galaxy_panel.close()
		else:
			galaxy_panel.message.text = status.text
			galaxy_panel.visit_button.disabled = false
	if succeeded:
		walker.enabled = true


func _open_visits() -> void:
	var directory: String = "user://galaxy_visits_m1c/" + str(catalog.identity().galaxy_id).sha256_text()
	visits = Visits.new(catalog, directory)
	_visits_error = visits.open()
	visit_record = {}


func _restore_system(saved: Dictionary) -> void:
	if saved.get("schema") == 4:
		var address: Dictionary = Catalog.Address.parse(saved.system_id)
		catalog = Catalog.new(address.universe_seed, address.galaxy_index)
		system = System.from_catalog(catalog.system(saved.system_id))
		_open_visits()
		if _visits_error == OK:
			var loaded: Dictionary = visits.read(saved.system_id)
			_visits_error = loaded.error
			visit_record = loaded.get("record", {})
	else:
		system = System.new(saved.binary, saved.get("scale_mode", "test") == "real")
	system.elapsed = saved.elapsed


func _save_visit(data: Dictionary) -> Error:
	if _visits_error != OK:
		return _visits_error
	if visit_record.is_empty() or visit_record.system_id != system.catalog_id:
		return ERR_UNCONFIGURED
	var edited: Dictionary = visit_record.duplicate(true)
	edited.elapsed = system.elapsed
	edited.bodies[body_id] = {"terrain_revision": 3, "location": data.location, "forward": data.forward}
	var error: Error = visits.write(edited)
	if error == OK:
		visit_record = visits.read(system.catalog_id).record
	return error


func visit_planet(system_id: String, target_id: String) -> bool:
	var entry: Dictionary = catalog.system(system_id)
	if entry.is_empty() or not entry.bodies.has(target_id) or not entry.bodies[target_id].get("landable", false):
		status.text = "Für diesen Körper ist keine begehbare Oberfläche verfügbar."
		return false
	if not save_lab():
		return false
	if visits == null:
		_open_visits()
	if _visits_error != OK:
		status.text = "Rückkehrpunkte können nicht geöffnet werden: " + error_string(_visits_error)
		return false
	var loaded: Dictionary = visits.read(system_id)
	if loaded.error != OK:
		status.text = "Rückkehrpunkt nicht lesbar: " + error_string(loaded.error)
		return false
	visit_record = loaded.record
	var saved: Dictionary = visit_record.bodies.get(target_id, {})
	system = System.from_catalog(entry)
	system.elapsed = visit_record.elapsed
	_build_system_view()
	_open_body(target_id, saved)
	var persisted: bool = save_lab()
	if persisted:
		status.text = ("Rückkehr zu " if not saved.is_empty() else "Gelandet auf ") + system.bodies[body_id].name + ". Ort gespeichert; zum Laufen in die Landschaft klicken."
	return persisted


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
	button.pressed.connect(func():
		if not _opening_large:
			action.call())
	parent.add_child(button)
	return button
