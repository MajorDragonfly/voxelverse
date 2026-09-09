extends RefCounted
## Body-owned, JSON-safe exploration. 32x32 bit tiles retain visited ground;
## no creature catalog, rewards or world generation are stored here.
const MapProjection = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const SCHEMA: int = 1
const CELL_M: float = 16.0
const TILE: int = 32
const MAX_TILES: int = 8192
const MAX_PLACES: int = 2048
var data: Dictionary = {}
var revision: int = 0
var full: bool = false

static func create(body_id: String, mode: String, radius: float = 0.0) -> Dictionary:
	var divisions: int = 0 if mode != Cube.MODE else int(pow(2, ceili(log(maxf(2.0 * radius / CELL_M, 1.0)) / log(2.0))))
	return {"schema": SCHEMA, "body_id": body_id, "mode": mode, "radius": radius,
		"divisions": divisions, "tiles": {}, "places": {}}

func bind(record: Dictionary) -> bool:
	if not validate(record, str(record.get("body_id", ""))).is_empty(): return false
	data = record
	# JSON numbers reload as floats. Canonical integer rows keep bit masks and
	# equality stable across saving and fresh processes.
	for rows: Array in data.tiles.values():
		for index in range(TILE): rows[index] = int(rows[index])
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
	var rows: Array = data.tiles.get(_key(cell), [])
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
	var key := _key(cell)
	if not data.tiles.has(key):
		if data.tiles.size() >= MAX_TILES:
			full = true
			return false
		var empty: Array = []
		empty.resize(TILE)
		empty.fill(0)
		data.tiles[key] = empty
	var row: int = posmod(cell.z, TILE)
	var before: int = int(data.tiles[key][row])
	var after: int = before | (1 << posmod(cell.y, TILE))
	data.tiles[key][row] = after
	return before != after

func remember(place: Dictionary) -> bool:
	if not _valid_place(place, data.body_id, data.mode): return false
	if not data.places.has(place.id) and data.places.size() >= MAX_PLACES: return false
	if data.places.get(place.id) == place: return false
	data.places[place.id] = place.duplicate(true)
	revision += 1
	return true

static func _key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, floori(float(cell.y) / TILE), floori(float(cell.z) / TILE)]

static func newer(value: Variant) -> bool:
	return value is Dictionary and _number(value.get("schema")) and float(value.schema) > SCHEMA

static func validate(record: Variant, body_id: String) -> String:
	if not record is Dictionary or record.get("schema") != SCHEMA: return "Nicht unterstützte Version der Erkundungskarte."
	if record.get("body_id") != body_id or body_id.is_empty() or record.get("mode") not in ["legacy_plane_v9", Cube.MODE]: return "Karte und Himmelskörper passen nicht zusammen."
	if not _number(record.get("radius")) or float(record.radius) < 0 or float(record.radius) > 1.0e10: return "Ungültiger Kartenradius."
	if record.mode == Cube.MODE and float(record.radius) <= 0: return "Kugelkarte ohne Radius."
	if record.mode == "legacy_plane_v9" and float(record.radius) != 0: return "Ungültiger Radius einer Flächenkarte."
	if record.get("divisions") != create(body_id, record.mode, float(record.radius)).divisions: return "Ungültige Kartenauflösung."
	if not record.get("tiles") is Dictionary or record.tiles.size() > MAX_TILES or not record.get("places") is Dictionary or record.places.size() > MAX_PLACES: return "Ungültige Kartensammlung."
	for key in record.tiles:
		if not key is String or key.length() > 72: return "Ungültige Kartenkachel."
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 3: return "Ungültiger Kartenort."
		for part in parts:
			if not part.is_valid_int() or str(int(part)) != part or abs(int(part)) > 2147483647: return "Ungültige Kartenkoordinate."
		if (int(parts[0]) != -1 if record.mode == "legacy_plane_v9" else int(parts[0]) not in range(6)): return "Ungültige Kartenfläche."
		var rows: Variant = record.tiles[key]
		if not rows is Array or rows.size() != TILE: return "Ungültige Erkundungsmaske."
		for row in rows:
			if not _number(row) or float(row) != floor(float(row)) or float(row) < 0 or float(row) > 4294967295.0: return "Ungültige Erkundungsbits."
	for key in record.places:
		var place: Variant = record.places[key]
		if not _valid_place(place, body_id, record.mode) or key != place.id: return "Ungültiger gespeicherter Kartenmarker."
	return ""

static func _valid_place(place: Variant, body_id: String, mode: String) -> bool:
	if not place is Dictionary: return false
	for field in ["id", "name", "kind", "species_id", "object_id"]:
		if not place.get(field) is String or place[field].length() > 256: return false
	return not place.id.is_empty() and place.kind in ["nest", "home", "friend_habitat", "friend_nest"] and place.get("own") is bool and MapProjection.valid(place.get("address", {})) and place.address.body_id == body_id and place.address.mode == mode

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
