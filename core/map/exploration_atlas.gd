extends RefCounted
## Body-owned, JSON-safe exploration. 32x32 bit tiles retain visited ground;
## no creature catalog, rewards or world generation are stored here.
const MapProjection = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Store = preload("res://core/persistence/region_store.gd")
const SCHEMA: int = 2
const INLINE_SCHEMA: int = 1
const CELL_M: float = 16.0
const TILE: int = 32
const MAX_TILES: int = 8192
const PENDING_LIMIT: int = 96
const MAX_PLACES: int = 2048
var data: Dictionary = {}
var revision: int = 0
var full: bool = false
var last_error: String = ""
var store := Store.new()
signal storage_failed(message: String)

static func create(body_id: String, mode: String, radius: float = 0.0) -> Dictionary:
	var divisions: int = 0 if mode != Cube.MODE else int(pow(2, ceili(log(maxf(2.0 * radius / CELL_M, 1.0)) / log(2.0))))
	# Small maps remain portable inline records. Paging upgrades them only when
	# needed; a paged record retains a bounded, save-safe write overlay in tiles.
	return {"schema": INLINE_SCHEMA, "body_id": body_id, "mode": mode, "radius": radius,
		"divisions": divisions, "tiles": {}, "places": {}}

func bind(record: Dictionary, directory: String = Store.DIRECTORY) -> bool:
	data = {}
	last_error = ""
	full = false
	store = Store.new()
	store.directory = directory
	var problem: String = validate(record, str(record.get("body_id", "")), directory)
	if not problem.is_empty(): return _fail(problem)
	if record.schema == SCHEMA and not store.open(record.storage): return _fail(store.last_error)
	data = record
	# JSON numbers reload as floats. Canonical integer rows keep bit masks and
	# equality stable across saving and fresh processes.
	for rows: Array in data.tiles.values():
		for index in range(TILE): rows[index] = int(rows[index])
	if data.tiles.size() > PENDING_LIMIT and not checkpoint(): return false
	revision += 1
	return true

func cell_for(address: Dictionary) -> Vector3i:
	if data.is_empty() or not MapProjection.valid(address) or address.body_id != data.body_id or address.mode != data.mode:
		return Vector3i(-2, 0, 0)
	if address.mode == Cube.MODE:
		var n: int = int(data.divisions)
		return Vector3i(int(address.face), clampi(floori((float(address.u) + 1.0) * 0.5 * n), 0, n - 1), clampi(floori((float(address.v) + 1.0) * 0.5 * n), 0, n - 1))
	return Vector3i(-1, floori(float(address.position[0]) / CELL_M), floori(float(address.position[2]) / CELL_M))

func address_for(cell: Vector3i) -> Dictionary:
	if cell.x == -1:
		return {"body_id": data.body_id, "mode": data.mode, "position": [(cell.y + 0.5) * CELL_M, 0.0, (cell.z + 0.5) * CELL_M]}
	return Cube.address(data.body_id, cell.x, (cell.y + 0.5) / float(data.divisions) * 2.0 - 1.0, (cell.z + 0.5) / float(data.divisions) * 2.0 - 1.0)

func known(address: Dictionary) -> bool:
	var cell := cell_for(address)
	if cell.x == -2: return false
	var rows: Array = _rows(_key(cell))
	return not rows.is_empty() and (int(rows[posmod(cell.z, TILE)]) & (1 << posmod(cell.y, TILE))) != 0

func reveal(address: Dictionary, radius: float = 36.0) -> bool:
	if cell_for(address).x == -2: return false
	var projection := MapProjection.new()
	if not projection.configure(address, float(data.radius)): return false
	var changed: bool = _mark(cell_for(address))
	# Half-cell probes cover adjacent cube faces as well as plane tile edges.
	var spacing: float = CELL_M * 0.25 if data.mode == Cube.MODE else CELL_M * 0.5
	var count: int = ceili(clampf(radius, 8.0, 64.0) / spacing)
	var visited := {}
	for y in range(-count, count + 1):
		for x in range(-count, count + 1):
			var offset := Vector2(x, y) * spacing
			if offset.length() > radius: continue
			var cell: Vector3i = cell_for(projection.address_at(offset))
			if visited.has(cell): continue
			visited[cell] = true
			if projection.project(address_for(cell)).length() <= radius:
				changed = _mark(cell) or changed
	if changed: revision += 1
	return changed

func _mark(cell: Vector3i) -> bool:
	if not last_error.is_empty() or cell.x == -2: return false
	var key := _key(cell)
	var rows: Array = _rows(key)
	if not last_error.is_empty(): return false
	var row: int = posmod(cell.z, TILE)
	var before: int = 0 if rows.is_empty() else int(rows[row])
	var after: int = before | (1 << posmod(cell.y, TILE))
	if before == after: return false
	if not data.tiles.has(key):
		if data.tiles.size() >= PENDING_LIMIT and not _spill(1): return false
		# Never mutate the committed cache through its shared Array reference.
		rows = rows.duplicate()
		if rows.is_empty(): rows.resize(TILE); rows.fill(0)
		data.tiles[key] = rows
	data.tiles[key][row] = after
	if data.schema == SCHEMA: _include_cell(data.extent, cell)
	return true

func _rows(key: String) -> Array:
	if data.tiles.has(key): return data.tiles[key]
	if data.schema == INLINE_SCHEMA or not last_error.is_empty(): return []
	var value: Dictionary = store.get_value(key)
	if not store.last_error.is_empty(): _fail(store.last_error); return []
	if value.is_empty():
		if store.cache.has(key): _fail("Leere Kartenkachel: " + key)
		return []
	if value.get("schema") != 1 or value.get("body_id") != data.body_id or value.get("mode") != data.mode or value.get("divisions") != data.divisions or not _valid_rows(value.get("rows")):
		_fail("Beschädigte oder unbekannte Kartenkachel: " + key)
		return []
	return value.rows

func checkpoint() -> bool:
	return _spill(data.get("tiles", {}).size())

func _spill(limit: int) -> bool:
	if not last_error.is_empty(): return false
	if data.is_empty() or data.tiles.is_empty(): return true
	# Publish the root and clear the overlay only after every blob is durable.
	# If a write fails, both the old root and all pending rows remain in data.
	var extent: Array = explored_extent()
	var keys: Array = data.tiles.keys().slice(0, limit)
	for key: String in keys:
		if not store.put(key, {"schema": 1, "body_id": data.body_id, "mode": data.mode,
				"divisions": data.divisions, "rows": data.tiles[key].duplicate()}): return _fail(store.last_error)
	var manifest: Dictionary = store.checkpoint()
	if manifest.is_empty(): return _fail(store.last_error)
	data.schema = SCHEMA
	data.storage = manifest
	data.extent = extent
	for key: String in keys: data.tiles.erase(key)
	return true

func explored_extent() -> Array:
	# Global plane coordinates or canonical longitude/latitude arc lengths.
	# A fixed-size extent lets "Erkundetes" fit even evicted tiles without I/O.
	if data.is_empty(): return []
	if data.schema == SCHEMA: return data.extent.duplicate()
	var extent: Array = []
	for key: String in data.tiles:
		var parts: PackedStringArray = key.split(":")
		var rows: Array = data.tiles[key]
		for row in range(TILE):
			var bits: int = int(rows[row])
			while bits != 0:
				var column: int = roundi(log(float(bits & -bits)) / log(2.0))
				_include_cell(extent, Vector3i(int(parts[0]), int(parts[1]) * TILE + column, int(parts[2]) * TILE + row))
				bits &= bits - 1
	return extent

func _include_cell(extent: Array, cell: Vector3i) -> void:
	var x: float = (cell.y + 0.5) * CELL_M
	var y: float = (cell.z + 0.5) * CELL_M
	if data.mode == Cube.MODE:
		var address: Dictionary = address_for(cell)
		var direction: Array = Cube.direction(address.face, address.u, address.v)
		x = atan2(float(direction[0]), float(direction[2])) * float(data.radius)
		y = -asin(clampf(float(direction[1]), -1.0, 1.0)) * float(data.radius)
	if extent.is_empty(): extent.assign([x, y, x, y]); return
	extent[0] = minf(extent[0], x)
	extent[1] = minf(extent[1], y)
	extent[2] = maxf(extent[2], x)
	extent[3] = maxf(extent[3], y)

func _fail(message: String) -> bool:
	if last_error.is_empty():
		last_error = "Erkundungskarte: " + message
		storage_failed.emit(last_error)
	return false

func remember(place: Dictionary) -> bool:
	if not last_error.is_empty(): return false
	if not _valid_place(place, data.body_id, data.mode): return false
	if not data.places.has(place.id) and data.places.size() >= MAX_PLACES: full = true; return false
	if data.places.get(place.id) == place: return false
	data.places[place.id] = place.duplicate(true)
	revision += 1
	return true

static func _key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, floori(float(cell.y) / TILE), floori(float(cell.z) / TILE)]

static func newer(value: Variant) -> bool:
	if not value is Dictionary: return false
	if _number(value.get("schema")) and float(value.schema) > SCHEMA: return true
	if value.get("schema") == SCHEMA and value.get("storage") is Dictionary:
		var probe := Store.new()
		probe.open(value.storage)
		return probe.unsupported
	return false

static func validate(record: Variant, body_id: String, directory: String = Store.DIRECTORY) -> String:
	# JSON decodes numbers as floats; Array membership compares Variant types.
	if not record is Dictionary or (record.get("schema") != INLINE_SCHEMA and record.get("schema") != SCHEMA): return "Nicht unterstützte Version der Erkundungskarte."
	if record.get("body_id") != body_id or body_id.is_empty() or record.get("mode") not in ["legacy_plane_v9", Cube.MODE]: return "Karte und Himmelskörper passen nicht zusammen."
	if not _number(record.get("radius")) or float(record.radius) < 0 or float(record.radius) > 1.0e10: return "Ungültiger Kartenradius."
	if record.mode == Cube.MODE and float(record.radius) <= 0: return "Kugelkarte ohne Radius."
	if record.mode == "legacy_plane_v9" and float(record.radius) != 0: return "Ungültiger Radius einer Flächenkarte."
	if record.get("divisions") != create(body_id, record.mode, float(record.radius)).divisions: return "Ungültige Kartenauflösung."
	var limit: int = MAX_TILES if record.schema == INLINE_SCHEMA else PENDING_LIMIT
	if not record.get("tiles") is Dictionary or record.tiles.size() > limit or not record.get("places") is Dictionary or record.places.size() > MAX_PLACES: return "Ungültige Kartensammlung."
	if record.schema == SCHEMA:
		var storage_problem: String = Store.manifest_problem(record.get("storage"))
		if not storage_problem.is_empty(): return storage_problem
		if not _valid_extent(record.get("extent")): return "Ungültige Kartenausdehnung."
		var probe := Store.new()
		probe.directory = directory
		if not probe.open(record.storage): return probe.last_error
	for key in record.tiles:
		if not key is String or key.length() > 72: return "Ungültige Kartenkachel."
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 3: return "Ungültiger Kartenort."
		for part in parts:
			if not part.is_valid_int() or str(int(part)) != part or abs(int(part)) > 2147483647: return "Ungültige Kartenkoordinate."
		if (int(parts[0]) != -1 if record.mode == "legacy_plane_v9" else int(parts[0]) not in range(6)): return "Ungültige Kartenfläche."
		if not _valid_rows(record.tiles[key]): return "Ungültige Erkundungsbits."
	for key in record.places:
		var place: Variant = record.places[key]
		if not _valid_place(place, body_id, record.mode) or key != place.id: return "Ungültiger gespeicherter Kartenmarker."
	return ""

static func _valid_rows(rows: Variant) -> bool:
	if not rows is Array or rows.size() != TILE: return false
	for row in rows:
		if not _number(row) or float(row) != floor(float(row)) or float(row) < 0 or float(row) > 4294967295.0: return false
	return true

static func _valid_extent(extent: Variant) -> bool:
	if not extent is Array: return false
	if extent.is_empty(): return true
	if extent.size() != 4: return false
	for value in extent:
		if not _number(value): return false
	return extent[0] <= extent[2] and extent[1] <= extent[3]

static func _valid_place(place: Variant, body_id: String, mode: String) -> bool:
	if not place is Dictionary: return false
	for field in ["id", "name", "kind", "species_id", "object_id"]:
		if not place.get(field) is String or place[field].length() > 256: return false
	return not place.id.is_empty() and place.kind in ["nest", "home", "friend_habitat", "friend_nest"] and place.get("own") is bool and MapProjection.valid(place.get("address", {})) and place.address.body_id == body_id and place.address.mode == mode

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
