extends RefCounted
## Device-local templates. The single atomic file never owns campaign state.
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const PATH: String = "user://creature_library.json"
const SCHEMA: int = 2
const MAX_ENTRIES: int = 128
const MAX_FAVORITES: int = 256
const MAX_BYTES: int = 16 * 1024 * 1024


static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": true, "code": "", "packages": [], "favorites": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return _fail("library_unreadable")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return _fail("library_unreadable")
	var data: Dictionary = parser.data
	var schema: Variant = data.get("schema")
	if not (schema is int or schema is float) or (schema != 1 and schema != SCHEMA) or data.size() != (2 if schema == 1 else 3) or not data.get("packages") is Array or data.packages.size() > MAX_ENTRIES:
		return _fail("library_unreadable")
	var keys: Dictionary = {}
	for package in data.packages:
		if not Package.inspect(package).ok: return _fail("library_unreadable")
		var key: String = key_of(package)
		if keys.has(key): return _fail("library_unreadable")
		keys[key] = true
	var favorites: Variant = data.get("favorites", [])
	if schema == SCHEMA and not data.has("favorites"): return _fail("library_unreadable")
	if not favorites is Array or favorites.size() > MAX_FAVORITES: return _fail("library_unreadable")
	var seen: Dictionary = {}
	for key in favorites:
		if not key is String or seen.has(key) or (not keys.has(key) and not _valid_builtin_key(key)):
			return _fail("library_unreadable")
		seen[key] = true
	return {"ok": true, "code": "", "packages": data.packages, "favorites": favorites}


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
			return {"ok": true, "code": "already_present", "key": key} if Package.same_content(existing, canonical) else _fail("revision_conflict")
	if stored.packages.size() >= MAX_ENTRIES: return _fail("library_full")
	stored.packages.append(canonical)
	var written: Dictionary = _write(path, stored.packages, stored.favorites)
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
			stored.favorites.erase(key)
			return _write(path, stored.packages, stored.favorites)
	return _fail("template_missing")


## Favorite identity includes the exact revision and the built-in namespace.
## Metadata stays device-local and is never added to an exported package.
static func set_favorite(key: String, enabled: bool, path: String = PATH) -> Dictionary:
	var stored: Dictionary = read(path)
	if not stored.ok: return stored
	var present: bool = false
	if key.begins_with("builtin/"):
		for package: Dictionary in Starter.packages():
			if "builtin/" + key_of(package) == key: present = true; break
	else:
		for package: Dictionary in stored.packages:
			if key_of(package) == key: present = true; break
	if not present: return _fail("template_missing")
	if stored.favorites.has(key) == enabled:
		return {"ok": true, "code": "", "favorites": stored.favorites}
	if enabled:
		if stored.favorites.size() >= MAX_FAVORITES: return _fail("favorites_full")
		stored.favorites.append(key)
	else:
		stored.favorites.erase(key)
	var result: Dictionary = _write(path, stored.packages, stored.favorites)
	if result.ok: result["favorites"] = stored.favorites
	return result


static func _valid_builtin_key(key: String) -> bool:
	if not key.begins_with("builtin/starter_") or key.length() > 100: return false
	var pieces: PackedStringArray = key.trim_prefix("builtin/starter_").split("@")
	if pieces.size() != 2 or not pieces[0] in Starter.IDS: return false
	# Keep old built-in revision bookmarks if templates gain new revisions.
	if not pieces[1].is_valid_int(): return false
	var revision: int = pieces[1].to_int()
	return revision >= 1 and revision <= int(Package.Schema.REVISION[2]) and str(revision) == pieces[1]


static func _write(path: String, packages: Array, favorites: Array) -> Dictionary:
	var data: Dictionary = {"schema": SCHEMA, "packages": packages, "favorites": favorites}
	if JSON.stringify(data, "\t").to_utf8_buffer().size() > MAX_BYTES: return _fail("library_full")
	var error: Error = Atomic.write(path, data)
	return {"ok": error == OK, "code": "" if error == OK else "write_failed"}


static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": code}
