extends RefCounted

## Canonical, reversible IDs. Integer components are decimal strings on disk;
## galactic distances never enter a local physics Vector3.
const VERSION: int = 1
const SECTOR_SIZE_LY: float = 16.0
const MAX_SECTOR: int = 1_000_000_000
const MAX_GALAXY: int = 1_000_000
const MAX_SYSTEMS: int = 8
const MAX_BODIES: int = 64

static func canonical_integer(value: Variant) -> bool:
	if not (value is String or value is int):
		return false
	var text: String = str(value)
	return not text.is_empty() and text.length() <= 20 and text.is_valid_int() and str(text.to_int()) == text

static func galaxy_id(seed_value: String, index: int = 0) -> String:
	if not canonical_integer(seed_value) or index < 0 or index > MAX_GALAXY:
		return ""
	return "vx1/u%s/g%d" % [seed_value, index]

static func sector_id(seed_value: String, galaxy: int, coordinates: Array) -> String:
	var identity: String = galaxy_id(seed_value, galaxy)
	if identity.is_empty() or coordinates.size() != 3:
		return ""
	for axis in coordinates:
		if not canonical_integer(axis) or int(axis) < -MAX_SECTOR or int(axis) > MAX_SECTOR:
			return ""
	return identity + "/s%s,%s,%s" % [str(coordinates[0]), str(coordinates[1]), str(coordinates[2])]

static func system_id(sector: String, slot: int) -> String:
	if parse(sector).get("kind") != "sector" or slot < 0 or slot >= MAX_SYSTEMS:
		return ""
	return sector + "/t%d" % slot

static func body_id(system: String, slot: int) -> String:
	if parse(system).get("kind") != "system" or slot < 0 or slot >= MAX_BODIES:
		return ""
	return system + "/b%d" % slot

static func parse(value: Variant) -> Dictionary:
	if not value is String or value.length() > 160:
		return {}
	var parts: PackedStringArray = value.split("/", true)
	if parts.size() < 3 or parts.size() > 6 or parts[0] != "vx1" or not parts[1].begins_with("u") or not parts[2].begins_with("g"):
		return {}
	var seed_value: String = parts[1].substr(1)
	var galaxy: String = parts[2].substr(1)
	if not canonical_integer(seed_value) or not canonical_integer(galaxy) or int(galaxy) < 0 or int(galaxy) > MAX_GALAXY:
		return {}
	var data: Dictionary = {"version": VERSION, "kind": "galaxy", "universe_seed": seed_value, "galaxy_index": int(galaxy), "galaxy_id": "/".join(parts.slice(0, 3))}
	if parts.size() == 3:
		return data
	if not parts[3].begins_with("s"):
		return {}
	var axes: PackedStringArray = parts[3].substr(1).split(",", true)
	if axes.size() != 3:
		return {}
	for axis in axes:
		if not canonical_integer(axis) or int(axis) < -MAX_SECTOR or int(axis) > MAX_SECTOR:
			return {}
	data.merge({"kind": "sector", "sector": Array(axes), "sector_id": "/".join(parts.slice(0, 4))}, true)
	if parts.size() == 4:
		return data
	var slot: String = parts[4].substr(1)
	if not parts[4].begins_with("t") or not canonical_integer(slot) or int(slot) < 0 or int(slot) >= MAX_SYSTEMS:
		return {}
	data.merge({"kind": "system", "system_slot": int(slot), "system_id": "/".join(parts.slice(0, 5))}, true)
	if parts.size() == 5:
		return data
	var body: String = parts[5].substr(1)
	if not parts[5].begins_with("b") or not canonical_integer(body) or int(body) < 0 or int(body) >= MAX_BODIES:
		return {}
	data.merge({"kind": "body", "body_slot": int(body), "body_id": value}, true)
	return data

static func normalize_position(sector: Array, offset_ly: Array) -> Dictionary:
	if sector_id("0", 0, sector).is_empty() or offset_ly.size() != 3:
		return {}
	var axes: Array[String] = []
	var offsets: Array[float] = []
	for index in range(3):
		var offset: Variant = offset_ly[index]
		if not (offset is float or offset is int) or not is_finite(float(offset)) or absf(float(offset)) > MAX_SECTOR * SECTOR_SIZE_LY:
			return {}
		var carry: int = floori(float(offset) / SECTOR_SIZE_LY)
		var coordinate: int = int(sector[index]) + carry
		if coordinate < -MAX_SECTOR or coordinate > MAX_SECTOR:
			return {}
		axes.append(str(coordinate))
		offsets.append(float(offset) - carry * SECTOR_SIZE_LY)
	return {"sector": axes, "offset_ly": offsets}

static func relative_ly(point: Dictionary, origin: Dictionary) -> Array:
	var a: Dictionary = normalize_position(point.get("sector", []), point.get("offset_ly", []))
	var b: Dictionary = normalize_position(origin.get("sector", []), origin.get("offset_ly", []))
	if a.is_empty() or b.is_empty():
		return []
	var result: Array[float] = []
	for axis in range(3):
		result.append((int(a.sector[axis]) - int(b.sector[axis])) * SECTOR_SIZE_LY + (a.offset_ly[axis] - b.offset_ly[axis]))
	return result
