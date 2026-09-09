extends RefCounted
## Probe-only persistence. Production integration must use SaveGameService's
## joint campaign snapshot, not introduce a parallel campaign save file.
const Fixture = preload("res://world/domestication/lab/lab_fixture.gd")
var path: String = "user://d2_lab/snapshot.json"
var error: String = ""
var blocked: bool = false
var recovered: bool = false

func load_snapshot() -> Dictionary:
	error = ""
	blocked = false
	recovered = false
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var value: Variant = _parse(FileAccess.get_file_as_string(candidate))
		if _newer(value):
			blocked = true
			error = "Neueres Prüfstandformat; Laden und Überschreiben gesperrt."
			return {}
		if Fixture.validate(value).is_empty():
			recovered = candidate != path
			return value
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		blocked = true
		error = "Prüfstand beschädigt; Originaldateien bleiben erhalten."
	return {}

func write_snapshot(value: Dictionary) -> bool:
	error = Fixture.validate(value)
	if blocked or not error.is_empty(): return false
	# Protect newer formats even when the caller did not load first.
	if FileAccess.file_exists(path) and _newer(_parse(FileAccess.get_file_as_string(path))):
		blocked = true
		error = "Neueres Prüfstandformat; Überschreiben gesperrt."
		return false
	var directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		error = "Speicherordner nicht verfügbar."
		return false
	var encoded: String = JSON.stringify(value, "\t", true, true)
	if not _write_verified(path + ".tmp", encoded): return false
	if FileAccess.file_exists(path):
		var previous: String = FileAccess.get_file_as_string(path)
		if Fixture.validate(_parse(previous)).is_empty():
			if not _write_verified(path + ".bak.tmp", previous): return false
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"), ProjectSettings.globalize_path(path + ".bak")) != OK:
				error = "Sicherung konnte nicht ersetzt werden."
				return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		error = "Prüfstand konnte nicht ersetzt werden."
		return false
	return true

func _write_verified(target: String, content: String) -> bool:
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		error = "Prüfstand konnte nicht geschrieben werden."
		return false
	file.store_string(content)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result != OK or FileAccess.get_file_as_string(target) != content:
		error = "Geschriebener Prüfstand konnte nicht bestätigt werden."
		return false
	return true

func _newer(value: Variant) -> bool:
	if not value is Dictionary: return false
	var schema: Variant = value.get("schema")
	if (schema is float or schema is int) and schema > 1: return true
	if not value.get("registry") is Dictionary: return false
	schema = value["registry"].get("schema")
	return (schema is float or schema is int) and schema > 1

func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
