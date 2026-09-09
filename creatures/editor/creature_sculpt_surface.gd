extends RefCounted
## Shared geometry for the editor, player and generated wildlife. One closed
## voxel skin follows the editable spine; attachments use world-space anatomy
## anchors exactly once. All visible pieces have hard cubic faces.

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
const BODY_CELL_SIZE: float = 0.035
const MAX_BODY_AXIS_CELLS: float = 128.0


static func colors(blueprint: Dictionary) -> Array[Color]:
	var body: Dictionary = Parts.get_part(Blueprint.get_body_part_id(blueprint))
	var paint: Dictionary = Parts.get_part(Blueprint.get_paint_part_id(blueprint))
	var base: Color = body.get("color", Color("73b696")) * paint.get("base_tint", Color.WHITE)
	var accent: Color = paint.get("accent", Color("254d48"))
	var appearance: Dictionary = blueprint.get("appearance", {})
	if appearance.has("base_color"):
		base = Color.from_string(str(appearance["base_color"]), base)
	if appearance.has("accent_color"):
		accent = Color.from_string(str(appearance["accent_color"]), accent)
	return [base, accent]


static func section(blueprint: Dictionary, t: float) -> Dictionary:
	var shape: Vector3 = Blueprint.get_body_shape(blueprint) * Blueprint.get_body_scale(blueprint)
	shape.z *= Spine.get_body_length_scale(blueprint)
	var profile: Dictionary = Spine.sample(blueprint, t)
	var taper: float = absf(t - 0.5) * 0.46
	return {
		"center": Vector3(0.0, float(profile["y_offset"]) * Blueprint.get_body_scale(blueprint), (t - 0.5) * shape.z),
		"radius": Vector2(shape.x * (1.0 - taper) * float(profile["width_scale"]) * 0.5,
			shape.y * (1.0 - taper * 0.52) * float(profile["height_scale"]) * 0.5),
	}


static func build_skin(blueprint: Dictionary) -> ArrayMesh:
	var palette: Array[Color] = colors(blueprint)
	var pattern: String = str(Parts.get_part(Blueprint.get_paint_part_id(blueprint)).get("pattern", "plain"))
	var scale: float = Blueprint.get_body_scale(blueprint)
	var shape: Vector3 = Blueprint.get_body_shape(blueprint) * scale
	var length: float = shape.z * Spine.get_body_length_scale(blueprint)
	var width: float = 0.0
	var bottom: float = INF
	var top: float = -INF
	for segment: Dictionary in Spine.get_segments(blueprint):
		width = maxf(width, shape.x * float(segment["width_scale"]))
		var center: float = float(segment["y_offset"]) * scale
		var height: float = shape.y * float(segment["height_scale"]) * 0.5
		bottom = minf(bottom, center - height)
		top = maxf(top, center + height)
	# Equal-sized cubes in all three axes. Extreme designs coarsen within a
	# bounded grid rather than stretching the cells into rectangular slices.
	var step: float = maxf(BODY_CELL_SIZE * scale, maxf(length, maxf(width, top - bottom)) / MAX_BODY_AXIS_CELLS)
	# An elliptical cross-section consists of symmetric, solid X rows. Their
	# extents reveal the boundary without six lookups for every interior cell.
	var rows: Dictionary = {}
	var sections: Dictionary = {}
	for z in range(floori(-length * 0.5 / step), ceili(length * 0.5 / step)):
		var t: float = (float(z) + 0.5) * step / length + 0.5
		if t <= 0.0 or t >= 1.0:
			continue
		var cross: Dictionary = section(blueprint, t)
		var center: Vector3 = cross["center"]
		var cap: float = sqrt(maxf(0.0, 1.0 - pow(absf(t * 2.0 - 1.0), 18.0)))
		var radius: Vector2 = cross["radius"] * cap
		# Keep thin sculpted necks represented on the symmetric cubic lattice.
		radius = radius.max(Vector2.ONE * step * 0.76)
		sections[z] = {"t": t, "center_y": center.y, "radius": radius}
		for y in range(floori((center.y - radius.y) / step), ceili((center.y + radius.y) / step)):
			var radial_y: float = ((float(y) + 0.5) * step - center.y) / radius.y
			if absf(radial_y) > 1.0:
				continue
			var extent: int = floori(radius.x * sqrt(maxf(0.0, 1.0 - radial_y * radial_y)) / step + 0.5)
			if extent > 0:
				rows[Vector2i(y, z)] = extent
	var cells: Dictionary = {}
	var surface_cells: Array[Vector3i] = []
	for row: Vector2i in rows:
		var extent: int = rows[row]
		var interior: int = extent - 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			interior = mini(interior, int(rows.get(row + offset, 0)))
		var cross: Dictionary = sections[row.y]
		var t: float = cross["t"]
		var radius: Vector2 = cross["radius"]
		var radial_y: float = ((float(row.x) + 0.5) * step - float(cross["center_y"])) / radius.y
		var belly: float = floorf(clampf(-radial_y, 0.0, 1.0) * 3.0) / 3.0
		var row_color: Color = palette[0].lerp(palette[0].lightened(0.26), belly * 0.7)
		for x in range(-extent, extent):
			var cell := Vector3i(x, row.x, row.y)
			if x >= -interior and x < interior:
				cells[cell] = Color.WHITE # Occupancy only: never a visible face.
				continue
			surface_cells.append(cell)
			var color: Color = row_color
			var angle: float = atan2(radial_y, absf((float(x) + 0.5) * step / radius.x))
			var mask: bool = false
			match pattern:
				"spots": mask = sin(t * 53.0 + cos(angle * 5.0)) * cos(angle * 7.0) > 0.60
				"stripes": mask = sin(t * 47.0 + sin(angle * 3.0)) > 0.30
				"warning": mask = sin(t * 36.0 + angle * 2.0) > 0.30
				"crystal": mask = cos(t * 50.0) * sin(angle * 8.0) > 0.45
			if mask and radial_y > -0.25:
				color = color.lerp(palette[1], 0.86)
			var variation: float = Voxels.shade(cell)
			cells[cell] = color.lightened(variation) if variation > 0.0 else color.darkened(-variation)
	return Voxels.from_cells(cells, step, true, surface_cells)


static func material(color: Color, vertex_colors: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.vertex_color_use_as_albedo = vertex_colors
	result.vertex_color_is_srgb = true
	result.roughness = 1.0
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return result


static func ellipsoid(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position
	node.mesh = Voxels.primitive(size)
	node.material_override = material(color, true)
	parent.add_child(node)
	return node


static func bone(parent: Node3D, node_name: String, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = (start + end) * 0.5
	node.mesh = Voxels.primitive(Vector3(width, maxf(start.distance_to(end) + width, width), width), "capsule")
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	node.material_override = material(color, true)
	parent.add_child(node)
	return node


static func make_part_piece(parent: Node3D, node_name: String, position: Vector3, size: Vector3, authored: Color, blueprint: Dictionary) -> void:
	var category: String = str(parent.get_meta("creature_part_category", ""))
	var skin: Color = colors(blueprint)[0]
	var color: Color = authored
	if category in ["legs", "arms", "tail", "mouth"] and authored.get_luminance() > 0.08:
		color = skin.lerp(authored, 0.32)
	if category == "eyes" and authored.get_luminance() < 0.12:
		var orb_size: Vector3 = size * 1.35
		ellipsoid(parent, node_name, position, orb_size, Color("f7eedb"))
		ellipsoid(parent, node_name + "Iris", position + Vector3(0.0, 0.0, -orb_size.z * 0.44), orb_size * Vector3(0.63, 0.67, 0.35), colors(blueprint)[1].lightened(0.15))
		ellipsoid(parent, node_name + "Pupil", position + Vector3(0.0, 0.0, -orb_size.z * 0.57), orb_size * Vector3(0.34, 0.44, 0.15), Color("101f28"))
		ellipsoid(parent, node_name + "Glint", position + Vector3(-orb_size.x * 0.09, orb_size.y * 0.13, -orb_size.z * 0.62), orb_size * 0.15, Color.WHITE)
	elif category == "eyes" and authored.b > 0.7:
		pass # The old bright pupil voxel is represented by the iris/glint above.
	elif category in ["horns", "spikes"]:
		var node := MeshInstance3D.new()
		node.name = node_name
		node.position = position
		node.mesh = Voxels.primitive(size * 1.2, "cone")
		node.material_override = material(color, true)
		parent.add_child(node)
	elif category in ["legs", "arms"] and size.y > size.x * 1.8:
		# Two overlapping segments give the adaptive knee rig real upper/lower
		# geometry, unlike one long mesh spanning the whole limb.
		var top: Vector3 = position + Vector3.UP * size.y * 0.43
		var knee: Vector3 = position + Vector3(0.0, 0.0, size.y * 0.12)
		var foot: Vector3 = position + Vector3.DOWN * size.y * 0.43
		bone(parent, node_name + "Upper", top, knee, size.x * 1.12, color)
		bone(parent, node_name + "Lower", knee, foot, size.x * 0.88, color.darkened(0.06))
		ellipsoid(parent, node_name + "Joint", knee, Vector3.ONE * size.x * 1.26, color)
	else:
		ellipsoid(parent, node_name, position, size * 1.08, color)
