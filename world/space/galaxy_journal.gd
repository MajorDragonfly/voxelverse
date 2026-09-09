extends RefCounted

## Sparse per-system changes, independent of the disposable catalogue caches.
## The campaign save stays on its existing contract until explicit migration.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Address = preload("res://world/space/galaxy_address.gd")
const SCHEMA: int = 1
const CACHE_LIMIT: int = 16
const MAX_FILE_BYTES: int = 131072
var directory: String
var catalog: RefCounted
var _cache: Dictionary = {}
var _opened: bool = false

func _init(source: RefCounted, path: String = "user://galaxy_m1c") -> void:
	catalog = source
	directory = path

func open() -> Error:
	var header: Dictionary = _header()
	if str(header.galaxy_id).is_empty():
		return ERR_INVALID_PARAMETER
	var path: String = directory.path_join("manifest.json")
	if FileAccess.file_exists(path):
		var error: Error = _check_manifest()
		_opened = error == OK
		return error
	# A missing primary with a surviving backup is not a new universe.
	if FileAccess.file_exists(path + ".bak"):
		return ERR_FILE_CORRUPT
	var error: Error = DirAccess.make_dir_recursive_absolute(directory.path_join("systems"))
	if error == OK:
		error = Atomic.write(path, header)
	_opened = error == OK
	return error

func read(id: String) -> Dictionary:
	if not _opened:
		return {"error": ERR_UNCONFIGURED}
	if _cache.has(id):
		var cached: Dictionary = _cache[id]
		_cache.erase(id)
		_cache[id] = cached
		return cached.duplicate(true)
	var result: Dictionary = _read_disk(id)
	if result.error == OK:
		_remember(id, result)
	return result.duplicate(true)

func write(record: Dictionary) -> Error:
	if not _opened:
		return ERR_UNCONFIGURED
	var error: Error = _check_manifest()
	if error != OK:
		return error
	var id: String = str(record.get("system_id", ""))
	if not _valid(record, id):
		return ERR_INVALID_DATA
	# Read the actual file again: a second writer or a newer format must not be
	# overwritten merely because this process still holds an older cached value.
	var latest: Dictionary = _read_disk(id)
	if latest.error != OK:
		return latest.error
	if int(record.revision) != int(latest.record.revision):
		_cache.erase(id)
		return ERR_BUSY
	var next: Dictionary = record.duplicate(true)
	next.revision = int(record.revision) + 1
	if not _valid(next, id):
		return ERR_INVALID_DATA
	# If recovery used the backup, preserve that good backup while replacing
	# the damaged primary. AtomicJson otherwise backs up the current live file.
	error = Atomic.write(record_path(id), next, not bool(latest.get("recovered", false)))
	if error == OK:
		_remember(id, {"error": OK, "record": next, "recovered": false})
	return error

func record_path(id: String) -> String:
	return directory.path_join("systems").path_join(id.sha256_text() + ".json") if catalog.owns(id, "system") else ""

func clear_cache() -> void:
	_cache.clear()

func stats() -> Dictionary:
	return {"loaded_records": _cache.size(), "record_limit": CACHE_LIMIT, "opened": _opened}

func _header() -> Dictionary:
	var identity: Dictionary = catalog.identity()
	return {"schema": SCHEMA, "catalog_version": identity.catalog_version, "address_version": Address.VERSION, "universe_seed": identity.universe_seed, "galaxy_index": identity.galaxy_index, "galaxy_id": identity.galaxy_id}

func _check_manifest() -> Error:
	var data: Dictionary = _load_file(directory.path_join("manifest.json"))
	if data.is_empty():
		return ERR_FILE_CORRUPT
	if data.get("schema") != SCHEMA or data.get("catalog_version") != catalog.VERSION or data.get("address_version") != Address.VERSION:
		return ERR_UNAVAILABLE
	var expected: Dictionary = _header()
	if data.size() != expected.size():
		return ERR_INVALID_DATA
	for key: String in expected:
		var value: Variant = data.get(key)
		if key in ["schema", "address_version", "galaxy_index"]:
			# JSON decodes numbers as floats; Dictionary equality is type-sensitive.
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(expected[key]):
				return ERR_INVALID_DATA
		elif not value is String or value != expected[key]:
			return ERR_INVALID_DATA
	return OK

func _empty_record(id: String) -> Dictionary:
	return {"schema": SCHEMA, "catalog_version": catalog.VERSION, "system_id": id, "revision": 0, "discovered": false, "name": "", "note": "", "bodies": {}}

func _read_disk(id: String) -> Dictionary:
	if not catalog.owns(id, "system") or catalog.system(id).is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	var path: String = record_path(id)
	var existed: bool = false
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		existed = true
		var data: Dictionary = _load_file(candidate)
		if not data.is_empty() and (data.get("schema") != SCHEMA or data.get("catalog_version") != catalog.VERSION):
			return {"error": ERR_UNAVAILABLE}
		if _valid(data, id):
			return {"error": OK, "record": data, "recovered": candidate != path}
	if existed:
		return {"error": ERR_FILE_CORRUPT}
	return {"error": OK, "record": _empty_record(id), "recovered": false}

func _valid(data: Dictionary, id: String) -> bool:
	if data.size() != 8 or data.get("schema") != SCHEMA or data.get("catalog_version") != catalog.VERSION or data.get("system_id") != id or not catalog.owns(id, "system"):
		return false
	var revision: Variant = data.get("revision")
	if not (revision is int or revision is float) or not is_finite(float(revision)) or revision < 0 or revision >= 1_000_000_000 or float(revision) != floorf(float(revision)):
		return false
	if not _valid_observation(data) or not data.get("bodies") is Dictionary or data.bodies.size() > Address.MAX_BODIES:
		return false
	var bodies: Dictionary = catalog.system(id).get("bodies", {})
	for body_id: Variant in data.bodies:
		var observation: Variant = data.bodies[body_id]
		if not body_id is String or not bodies.has(body_id) or not observation is Dictionary or observation.size() != 3 or not _valid_observation(observation):
			return false
	return JSON.stringify(data).to_utf8_buffer().size() <= MAX_FILE_BYTES

static func _valid_observation(data: Dictionary) -> bool:
	return data.get("discovered") is bool and data.get("name") is String and data.name.length() <= 80 and data.get("note") is String and data.note.length() <= 1024

static func _load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return {}
	return Atomic.parse_dictionary(file.get_as_text())

func _remember(id: String, result: Dictionary) -> void:
	_cache.erase(id)
	_cache[id] = result.duplicate(true)
	while _cache.size() > CACHE_LIMIT:
		_cache.erase(_cache.keys()[0])
