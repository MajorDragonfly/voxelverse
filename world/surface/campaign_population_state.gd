extends RefCounted
## Regional placement and frozen bodies. Health, friendship, needs and ownership
## remain in their existing campaign services, keyed by the same object IDs.
const Cube = preload("res://world/space/cube_sphere.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Values = preload("res://world/fauna/domestication/domestication_contract.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Cells = preload("res://world/surface/surface_population_job.gd")
const SCHEMA: int = 1
const PAGED_SCHEMA: int = 2
const MAX_REGIONS: int = 32768
const MAX_OBJECTS_PER_REGION: int = 128

static func create(body_id: String) -> Dictionary:
	return {"schema": SCHEMA, "body_id": body_id, "regions": {}}

static func cell(body: Dictionary, point: Dictionary) -> Dictionary:
	var level: int = Cells.level_for(float(body.radius))
	var count: int = 1 << level
	var step: float = 2.0 / count
	var x: int = clampi(floori((point.u + 1.0) / step), 0, count - 1)
	var y: int = clampi(floori((point.v + 1.0) / step), 0, count - 1)
	return {"id": "%s:land1:%d:%d:%d:%d" % [body.id, level, int(point.face), x, y],
		"level": level, "face": int(point.face), "x": x, "y": y, "step": step}

static func nearest_cell(body: Dictionary, observer: Dictionary, candidates: Array[Dictionary]) -> Dictionary:
	var surface_point: Dictionary = observer.duplicate()
	surface_point.height = 0.0
	var origin: Array = Cube.cartesian(surface_point, body.radius)
	var nearest: Dictionary = {}
	var distance: float = INF
	for candidate: Dictionary in candidates:
		var center: Dictionary = Cube.address(body.id, candidate.face,
			-1.0 + (candidate.x + 0.5) * candidate.step, -1.0 + (candidate.y + 0.5) * candidate.step)
		var squared: float = Cube.local_position(Cube.cartesian(center, body.radius), origin).length_squared()
		if squared < distance:
			distance = squared
			nearest = candidate
	return nearest

static func ensure_region(data: Dictionary, key: String) -> Dictionary:
	if not data.regions.has(key):
		if data.regions.size() >= MAX_REGIONS: return {}
		data.regions[key] = {"schema": 1, "key": key, "objects": {}, "plants": {}, "generated": false}
	return data.regions[key]

static func put(data: Dictionary, body: Dictionary, record: Dictionary, plant: bool = false) -> bool:
	var region: Dictionary = ensure_region(data, cell(body, record.location).id)
	if region.is_empty(): return false
	var collection: Dictionary = region.plants if plant else region.objects
	if not collection.has(record.id) and collection.size() >= MAX_OBJECTS_PER_REGION: return false
	collection[record.id] = record
	return true

static func validate(value: Variant, body: Dictionary) -> String:
	if value is Dictionary and value.get("schema") == PAGED_SCHEMA:
		if value.get("body_id") != body.id: return "Körperfremder Regionsspeicher."
		return preload("res://core/persistence/region_store.gd").manifest_problem(value.get("storage"))
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("body_id") != body.id or not value.get("regions") is Dictionary or value.regions.size() > MAX_REGIONS:
		return "Ungültiger regionaler Kugelbestand."
	var seen: Dictionary = {}
	for key in value.regions:
		var region: Variant = value.regions[key]
		if not region is Dictionary or region.get("schema") != 1 or region.get("key") != key or not region.get("generated") is bool: return "Ungültige Kugelregion."
		if region.has("colony"):
			var colony_problem: String = preload("res://world/surface/wildlife_colony.gd").problem(region.colony, body)
			if not colony_problem.is_empty(): return colony_problem
		for section in ["objects", "plants"]:
			if not region.get(section) is Dictionary or region[section].size() > MAX_OBJECTS_PER_REGION: return "Kugelregion überschreitet ihr Objektbudget."
			for id in region[section]:
				var entry: Variant = region[section][id]
				if not entry is Dictionary or entry.get("id") != id or seen.has(id) or not Home.place_valid(entry.get("location"), Cube.MODE, body.id) or entry.location.radius != body.radius:
					return "Ungültiges, doppeltes oder körperfremdes Oberflächenobjekt."
				seen[id] = true
				if section == "plants":
					if not entry.get("food_key") is String or entry.food_key.is_empty(): return "Nahrungsquelle ohne stabile Identität."
					continue
				var identity: Variant = entry.get("identity")
				if not identity is Dictionary or identity.get("object_id") != id or identity.get("body_id") != body.id or not identity.get("species_id") is String or identity.species_id.is_empty() or not identity.get("region_id") is String or identity.region_id.is_empty(): return "Ungültige Individuenidentität."
				if not Values.integer(entry.get("species_seed"), 1, 9007199254740991) or not Values.integer(entry.get("individual_seed"), 0, 2147483647): return "Ungültiger Individuenseed."
				if entry.get("role") not in ["grazer", "forager", "climber", "predator", "scavenger", "swimmer"] or not entry.get("blueprint") is Dictionary or not Catalog.snapshot_value(entry.blueprint): return "Ungültiger eingefrorener Tierkörper."
	return ""

static func validate_region(region: Dictionary, body: Dictionary) -> String:
	var envelope: Dictionary = create(body.id)
	envelope.regions[region.get("key", "")] = region
	return validate(envelope, body)


class SkinBuild extends RefCounted:
	## One unpublished, resumable copy of the canonical sculpt/voxel algorithm.
	## No scene nodes, server handles, records or static cache until completion.
	const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
	const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
	const Parts = preload("res://creatures/editor/creature_part_library.gd")
	const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
	const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
	const Style = preload("res://creatures/editor/creature_skin_style.gd")
	var design: Dictionary
	var mesh: ArrayMesh
	var cancelled: bool = false
	var last_units: int = 0
	var _stage: int = 0
	var _palette: Array[Color]
	var _belly: Color
	var _pattern: String
	var _intensity: float
	var _length: float
	var _step: float
	var _rows: Dictionary = {}
	var _sections: Dictionary = {}
	var _keys: Array = []
	var _cells: Dictionary = {}
	var _shell: Array[Vector3i] = []
	var _z: int
	var _z_end: int
	var _y: int
	var _y_end: int
	var _row: Vector2i
	var _extent: int
	var _interior: int
	var _x: int
	var _t: float
	var _radius: Vector2
	var _radial_y: float
	var _row_color: Color
	var _at: int = 0
	var _masks := PackedByteArray()
	var _face_count: int = 0
	var _vertices := PackedVector3Array()
	var _normals := PackedVector3Array()
	var _colors := PackedColorArray()
	var _indices := PackedInt32Array()
	var _corners: Array[PackedVector3Array] = []
	var _face: int = 0

	func _init(blueprint: Dictionary) -> void:
		design = blueprint.duplicate(true)
		_palette = Surface.colors(design)
		_pattern = str(Parts.get_part(Blueprint.get_paint_part_id(design)).get("pattern", "plain"))
		_belly = Style.color(design, "belly_color", _palette[0].lightened(0.26))
		_intensity = Blueprint.get_paint_intensity(design)
		var scale: float = Blueprint.get_body_scale(design)
		var shape: Vector3 = Blueprint.get_body_shape(design) * scale
		_length = shape.z * Spine.get_body_length_scale(design)
		var width: float = 0.0
		var bottom: float = INF
		var top: float = -INF
		for segment: Dictionary in Spine.get_segments(design):
			width = maxf(width, shape.x * float(segment.width_scale))
			var center: float = float(segment.y_offset) * scale
			var height: float = shape.y * float(segment.height_scale) * 0.5
			bottom = minf(bottom, center - height)
			top = maxf(top, center + height)
		_step = maxf(Surface.BODY_CELL_SIZE * scale, maxf(_length, maxf(width, top - bottom)) / Surface.MAX_BODY_AXIS_CELLS)
		_z = floori(-_length * 0.5 / _step)
		_z_end = ceili(_length * 0.5 / _step)

	func advance(budget_usec: int, max_units: int = 4096) -> bool:
		last_units = 0
		if cancelled or mesh != null: return mesh != null
		var deadline: int = Time.get_ticks_usec() + maxi(0, budget_usec)
		while last_units < maxi(0, max_units) and Time.get_ticks_usec() < deadline and mesh == null:
			_unit()
			last_units += 1
		return mesh != null

	func cancel() -> void:
		cancelled = true
		mesh = null
		design.clear()
		_rows.clear()
		_sections.clear()
		_keys.clear()
		_cells.clear()
		_shell.clear()
		_masks.clear()
		_vertices.clear()
		_normals.clear()
		_colors.clear()
		_indices.clear()
		_corners.clear()

	func _unit() -> void:
		match _stage:
			0:
				if _z >= _z_end:
					_keys = _rows.keys()
					_at = 0
					_stage = 2
					return
				_t = (float(_z) + 0.5) * _step / _length + 0.5
				if _t <= 0.0 or _t >= 1.0:
					_z += 1
					return
				var cross: Dictionary = Surface.section(design, _t)
				var center: Vector3 = cross.center
				var cap: float = sqrt(maxf(0.0, 1.0 - pow(absf(_t * 2.0 - 1.0), 18.0)))
				_radius = (cross.radius * cap).max(Vector2.ONE * _step * 0.76)
				_sections[_z] = {"t": _t, "center_y": center.y, "radius": _radius}
				_y = floori((center.y - _radius.y) / _step)
				_y_end = ceili((center.y + _radius.y) / _step)
				_stage = 1
			1:
				if _y >= _y_end:
					_z += 1
					_stage = 0
					return
				var radial: float = ((float(_y) + 0.5) * _step - float(_sections[_z].center_y)) / _radius.y
				if absf(radial) <= 1.0:
					var extent: int = floori(_radius.x * sqrt(maxf(0.0, 1.0 - radial * radial)) / _step + 0.5)
					if extent > 0: _rows[Vector2i(_y, _z)] = extent
				_y += 1
			2:
				if _at >= _keys.size():
					_masks.resize(_shell.size())
					_at = 0
					_stage = 4
					return
				_row = _keys[_at]
				_extent = _rows[_row]
				_interior = _extent - 1
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					_interior = mini(_interior, int(_rows.get(_row + offset, 0)))
				var cross: Dictionary = _sections[_row.y]
				_t = cross.t
				_radius = cross.radius
				_radial_y = ((float(_row.x) + 0.5) * _step - float(cross.center_y)) / _radius.y
				var belly: float = floorf(clampf(-_radial_y, 0.0, 1.0) * 3.0) / 3.0
				_row_color = _palette[0].lerp(_belly, belly * 0.7)
				_x = -_extent
				_stage = 3
			3:
				# A fixed small batch avoids per-cell dispatch/clock overhead.
				# The budget is checked again before the next 64-cell batch.
				var cells: Dictionary = _cells
				for index in range(mini(64, _extent - _x)):
					var cell := Vector3i(_x, _row.x, _row.y)
					if _x >= -_interior and _x < _interior:
						cells[cell] = Color.WHITE
					else:
						_shell.append(cell)
						var color: Color = _row_color
						var angle: float = atan2(_radial_y, absf((float(_x) + 0.5) * _step / _radius.x))
						var mask: bool = false
						match _pattern:
							"spots": mask = sin(_t * 53.0 + cos(angle * 5.0)) * cos(angle * 7.0) > 0.60
							"stripes": mask = sin(_t * 47.0 + sin(angle * 3.0)) > 0.30
							"warning": mask = sin(_t * 36.0 + angle * 2.0) > 0.30
							"crystal": mask = cos(_t * 50.0) * sin(angle * 8.0) > 0.45
						if mask and _radial_y > -0.25: color = color.lerp(_palette[1], 0.86 * _intensity)
						var variation: float = Voxels.shade(cell)
						cells[cell] = color.lightened(variation) if variation > 0.0 else color.darkened(-variation)
					_x += 1
				if _x >= _extent:
					_at += 1
					_stage = 2
			4:
				if _at >= _shell.size():
					_stage = 5
					return
				var mask: int = 0
				for side in range(6):
					if not _cells.has(_shell[_at] + Voxels.NEIGHBORS[side]):
						mask |= 1 << side
						_face_count += 1
				_masks[_at] = mask
				_at += 1
			5:
				_vertices.resize(_face_count * 4)
				_normals.resize(_face_count * 4)
				_colors.resize(_face_count * 4)
				_indices.resize(_face_count * 6)
				for neighbor: Vector3i in Voxels.NEIGHBORS:
					var normal := Vector3(neighbor)
					var tangent: Vector3 = Vector3.UP.cross(normal) if neighbor.y == 0 else Vector3.RIGHT
					var bitangent: Vector3 = tangent.cross(normal)
					var points := PackedVector3Array()
					for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
						points.append((Vector3.ONE + normal + tangent * corner.x + bitangent * corner.y) * _step * 0.5)
					_corners.append(points)
				_at = 0
				_stage = 6
			6:
				# Move packed arrays into locals during a bounded batch. Keeping a
				# member alias while writing would trigger packed-array COW copies.
				var vertices: PackedVector3Array = _vertices
				var normals: PackedVector3Array = _normals
				var colors: PackedColorArray = _colors
				var indices: PackedInt32Array = _indices
				_vertices = PackedVector3Array()
				_normals = PackedVector3Array()
				_colors = PackedColorArray()
				_indices = PackedInt32Array()
				for index in range(mini(16, _shell.size() - _at)):
					var mask: int = _masks[_at]
					var cell: Vector3i = _shell[_at]
					var color: Color = _cells[cell]
					var origin: Vector3 = Vector3(cell) * _step
					for side in range(6):
						if (mask & (1 << side)) == 0: continue
						var normal := Vector3(Voxels.NEIGHBORS[side])
						var first: int = _face * 4
						for corner in range(4):
							vertices[first + corner] = origin + _corners[side][corner]
							normals[first + corner] = normal
							colors[first + corner] = color
						var offset: int = _face * 6
						indices[offset] = first
						indices[offset + 1] = first + 1
						indices[offset + 2] = first + 2
						indices[offset + 3] = first
						indices[offset + 4] = first + 2
						indices[offset + 5] = first + 3
						_face += 1
					_at += 1
				_vertices = vertices
				_normals = normals
				_colors = colors
				_indices = indices
				if _at >= _shell.size(): _stage = 7
			7:
				var result := ArrayMesh.new()
				if not _vertices.is_empty():
					var arrays: Array = []
					arrays.resize(Mesh.ARRAY_MAX)
					arrays[Mesh.ARRAY_VERTEX] = _vertices
					arrays[Mesh.ARRAY_NORMAL] = _normals
					arrays[Mesh.ARRAY_COLOR] = _colors
					arrays[Mesh.ARRAY_INDEX] = _indices
					result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				result.set_meta("voxel_size", _step)
				result.set_meta("voxel_count", _cells.size())
				result.set_meta("voxel_cells", _cells)
				mesh = result
