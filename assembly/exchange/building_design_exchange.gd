extends RefCounted
## File adapter/inbox only. Templates and editor adoption are separate owners.
## Imported immutable packages are outside campaign design/instance storage.
const Package = preload("res://assembly/exchange/building_blueprint_package.gd")
const DIRECTORY: String = "user://building_exchange"


static func key_of(package: Dictionary) -> String:
	return str(package.design_id) + "@" + str(int(package.revision))


static func path_for(package: Dictionary, directory: String = DIRECTORY) -> String:
	# Hash the exact identity, never interpolate an external name/ID into a path.
	return directory.path_join(key_of(package).sha256_text() + ".building.json")


static func export_file(blueprint: Dictionary, destination: String, metadata: Dictionary = {}) -> Dictionary:
	var exported: Dictionary = Package.export_blueprint(blueprint, metadata)
	if not exported.ok: return exported
	var written: Dictionary = Package.write_file(destination, exported.package)
	if written.ok:
		written["package"] = exported.package
		written["path"] = destination
	return written


static func import_file(source: String, directory: String = DIRECTORY) -> Dictionary:
	var decoded: Dictionary = Package.read_file(source)
	return import_package(decoded.package, directory) if decoded.ok else decoded


static func import_package(package: Variant, directory: String = DIRECTORY) -> Dictionary:
	var checked: Dictionary = Package.inspect(package)
	if not checked.ok: return checked
	var parent: String = ProjectSettings.globalize_path(directory).simplify_path()
	while not DirAccess.dir_exists_absolute(parent):
		if FileAccess.file_exists(parent): return {"ok": false, "code": "write_failed", "error": ERR_CANT_CREATE}
		var next: String = parent.get_base_dir()
		if next == parent or next.is_empty(): break
		parent = next
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return {"ok": false, "code": "write_failed", "error": error}
	var path: String = path_for(package, directory)
	var written: Dictionary = Package.write_file(path, package)
	if not written.ok: return written
	written["path"] = path
	written["key"] = key_of(package)
	written["package"] = package.duplicate(true)
	written["preview"] = checked.preview
	return written
