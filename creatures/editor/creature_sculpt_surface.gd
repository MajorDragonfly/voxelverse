extends RefCounted
## Shared geometry for the editor, player and generated wildlife. One closed
## skin replaces the old independent voxel slices; attachments use world-space
## anatomy anchors exactly once.

const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
const RINGS: int = 64
const SIDES: int = 24


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
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	# Rounded end caps sit inside the existing attachment overlap. The seven
	# shape knots remain at the same anatomical stations as legacy designs.
	for ring in range(RINGS + 1):
		var t: float = float(ring) / float(RINGS)
		var cross: Dictionary = section(blueprint, t)
		var center: Vector3 = cross["center"]
		var radius: Vector2 = cross["radius"]
		var cap: float = sqrt(maxf(0.0, 1.0 - pow(absf(t * 2.0 - 1.0), 18.0)))
		for side in range(SIDES + 1):
			var angle: float = TAU * float(side) / float(SIDES)
			var radial := Vector3(cos(angle) * radius.x * cap, sin(angle) * radius.y * cap, 0.0)
			vertices.append(center + radial)
			normals.append(Vector3.ZERO)
			var color: Color = palette[0].lerp(palette[0].lightened(0.34), clampf(-sin(angle), 0.0, 1.0) * 0.7)
			var mask: float = 0.0
			match pattern:
				"spots": mask = smoothstep(0.60, 0.80, sin(t * 53.0 + cos(angle * 5.0)) * cos(angle * 7.0))
				"stripes": mask = smoothstep(0.25, 0.52, sin(t * 47.0 + sin(angle * 3.0)))
				"warning": mask = smoothstep(0.25, 0.45, sin(t * 36.0 + angle * 2.0))
				"crystal": mask = smoothstep(0.40, 0.72, cos(t * 50.0) * sin(angle * 8.0))
			mask *= smoothstep(-0.4, 0.35, sin(angle))
			shades.append(color.lerp(palette[1], mask * 0.86))
	for ring in range(RINGS):
		for side in range(SIDES):
			var a: int = ring * (SIDES + 1) + side
			var b: int = a + SIDES + 1
			for tri in [[a, b, a + 1], [a + 1, b, b + 1]]:
				indices.append_array(PackedInt32Array(tri))
				var normal: Vector3 = (vertices[tri[2]] - vertices[tri[0]]).cross(vertices[tri[1]] - vertices[tri[0]])
				for index: int in tri:
					normals[index] += normal
	for ring in range(RINGS + 1):
		var first: int = ring * (SIDES + 1)
		var seam: Vector3 = normals[first] + normals[first + SIDES]
		normals[first] = seam
		normals[first + SIDES] = seam
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = shades
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func material(color: Color, vertex_colors: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.vertex_color_use_as_albedo = vertex_colors
	result.vertex_color_is_srgb = true
	result.roughness = 0.68
	return result


static func ellipsoid(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.scale = size.max(Vector3.ONE * 0.001)
	node.material_override = material(color)
	parent.add_child(node)
	return node


static func bone(parent: Node3D, node_name: String, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = (start + end) * 0.5
	var mesh := CapsuleMesh.new()
	mesh.radius = width * 0.5
	mesh.height = maxf(start.distance_to(end) + width, width)
	mesh.radial_segments = 12
	mesh.rings = 4
	node.mesh = mesh
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	node.material_override = material(color)
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
		var cone := CylinderMesh.new()
		cone.bottom_radius = 0.5
		cone.top_radius = 0.035
		cone.height = 1.0
		cone.radial_segments = 12
		node.mesh = cone
		node.scale = size * Vector3(1.2, 1.2, 1.2)
		node.material_override = material(color)
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
