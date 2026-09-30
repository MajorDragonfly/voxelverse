extends RefCounted
## Imports into the existing local ship authoring directory. No second fleet/store.
const Package = preload("res://assembly/exchange/ship_blueprint_package.gd")
const Ship = Package.Ship
const MAX_FILES: int = 256
static var _import_mutex := Mutex.new()


static func export_file(design_path: String, destination: String, metadata: Dictionary = {}) -> Dictionary:
	var loaded: Dictionary = Ship.load_design(design_path)
	if not loaded.ok: return loaded
	var exported: Dictionary = Package.export_blueprint(loaded.blueprint, metadata)
	return Package.write_file(destination, exported.package) if exported.ok else exported


static func import_file(source: String, directory: String = Ship.DIRECTORY) -> Dictionary:
	var read: Dictionary = Package.read_file(source)
	return import_package(read.package, directory) if read.ok else read


static func destination_for(package: Dictionary, directory: String = Ship.DIRECTORY) -> String:
	# Only a hash of the identity reaches the path, never payload paths/names.
	return directory.path_join("import_" + Package.Atomic.stringify([package.design_id, int(package.revision)], "").sha256_text() + ".json")


static func import_package(package: Variant, directory: String = Ship.DIRECTORY) -> Dictionary:
	var prepared: Dictionary = Package.prepare_import(package)
	if not prepared.ok: return prepared
	_import_mutex.lock()
	var result: Dictionary = _import_owned(package, prepared, directory)
	_import_mutex.unlock()
	return result


static func _import_owned(package: Dictionary, prepared: Dictionary, directory: String) -> Dictionary:
	var destination: String = destination_for(package, directory)
	var root := DirAccess.open(directory)
	if root != null:
		# Scan once, with fixed work/size bounds. An unreadable original prevents
		# asserting uniqueness; it is never silently ignored or repaired.
		root.list_dir_begin()
		var scanned: int = 0
		var filename: String = root.get_next()
		var existing_path: String = ""
		while not filename.is_empty():
			scanned += 1
			if scanned > MAX_FILES:
				root.list_dir_end()
				return Package._fail("ship_exchange.library_limit")
			if root.is_link(filename):
				root.list_dir_end()
				return Package._fail("ship_exchange.protected_library")
			if filename.ends_with(".json"):
				var path: String = directory.path_join(filename)
				var loaded: Dictionary = Ship.load_design(path)
				if not loaded.ok:
					root.list_dir_end()
					return Package._fail("ship_exchange.protected_library")
				if loaded.blueprint.design_id == package.design_id and int(loaded.blueprint.revision) == int(package.revision):
					var exported: Dictionary = Package.export_blueprint(loaded.blueprint)
					if not exported.ok or not Package.same_content(exported.package, package):
						root.list_dir_end()
						return Package._fail("ship_exchange.revision_conflict")
					existing_path = path
			filename = root.get_next()
		root.list_dir_end()
		if not existing_path.is_empty():
			return {"ok": true, "code": "already_present", "path": existing_path,
				"blueprint": prepared.blueprint, "ready": prepared.ready}
		if scanned >= MAX_FILES: return Package._fail("ship_exchange.library_limit")
	elif DirAccess.dir_exists_absolute(directory) or FileAccess.file_exists(directory):
		return Package._fail("ship_exchange.protected_library")
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination):
		return Package._fail("ship_exchange.destination_conflict")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error == OK:
		# Preserve the source revision; normal editor saving/copying owns later
		# revisions. Store supplies the existing atomic writer/original guard.
		error = Ship.Store.write(destination, Ship.Assembly.serialize(prepared.blueprint))
	if error != OK: return {"ok": false, "code": "ship_exchange.write_failed", "error": error}
	return {"ok": true, "code": "", "path": destination,
		"blueprint": prepared.blueprint, "ready": prepared.ready}
