extends RefCounted
## Device-local templates. The single atomic file never owns campaign state.
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const PATH: String = "user://creature_library.json"
const MAX_ENTRIES: int = 128
const MAX_BYTES: int = 16 * 1024 * 1024


static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": true, "code": "", "packages": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return _fail("library_unreadable")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return _fail("library_unreadable")
	var data: Dictionary = parser.data
	if data.size() != 2 or data.get("schema") != 1 or not data.get("packages") is Array or data.packages.size() > MAX_ENTRIES:
		return _fail("library_unreadable")
	var keys: Dictionary = {}
	for package in data.packages:
		if not Package.inspect(package).ok: return _fail("library_unreadable")
		var key: String = key_of(package)
		if keys.has(key): return _fail("library_unreadable")
		keys[key] = true
	return {"ok": true, "code": "", "packages": data.packages}


static func key_of(package: Dictionary) -> String:
	return str(package.design_id) + "@" + str(int(package.revision))


static func add(package: Dictionary, path: String = PATH) -> Dictionary:
	var checked: Dictionary = Package.inspect(package)
	if not checked.ok: return checked
	var stored: Dictionary = read(path)
	if not stored.ok: return stored
	var canonical: Dictionary = JSON.parse_string(JSON.stringify(package))
	var key: String = key_of(package)
	for existing: Dictionary in stored.packages:
		if key_of(existing) == key:
			return {"ok": true, "code": "already_present", "key": key} if existing == canonical else _fail("revision_conflict")
	if stored.packages.size() >= MAX_ENTRIES: return _fail("library_full")
	stored.packages.append(canonical)
	var written: Dictionary = _write(path, stored.packages)
	if written.ok: written["key"] = key
	return written


static func import_file(source: String, path: String = PATH) -> Dictionary:
	var result: Dictionary = Package.read_file(source)
	return add(result.package, path) if result.ok else result


static func get_package(key: String, path: String = PATH) -> Dictionary:
	var stored: Dictionary = read(path)
	if not stored.ok: return stored
	for package: Dictionary in stored.packages:
		if key_of(package) == key: return {"ok": true, "code": "", "package": package}
	return _fail("template_missing")


## Every saved working copy is a new immutable variant, never a republished
## revision of the live campaign design. Source provenance is retained.
static func save_variant(blueprint: Dictionary, title: String, path: String = PATH) -> Dictionary:
	var exported: Dictionary = Package.export_blueprint(blueprint, {"title": title})
	if not exported.ok: return exported
	var package: Dictionary = exported.package
	var source: Dictionary = {"design_id": package.design_id, "revision": package.revision, "author": package.author}
	if not source in package.provenance: package.provenance.append(source)
	if package.provenance.size() > 8: return _fail("provenance_limit")
	package.design_id = Ids.create("design")
	package.revision = 1
	package.blueprint.name = title
	return add(package, path)


static func remove(key: String, path: String = PATH) -> Dictionary:
	var stored: Dictionary = read(path)
	if not stored.ok: return stored
	for index in range(stored.packages.size()):
		if key_of(stored.packages[index]) == key:
			stored.packages.remove_at(index)
			return _write(path, stored.packages)
	return _fail("template_missing")


static func _write(path: String, packages: Array) -> Dictionary:
	var data: Dictionary = {"schema": 1, "packages": packages}
	if JSON.stringify(data, "\t").to_utf8_buffer().size() > MAX_BYTES: return _fail("library_full")
	var error: Error = Atomic.write(path, data)
	return {"ok": error == OK, "code": "" if error == OK else "write_failed"}


static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": code}
