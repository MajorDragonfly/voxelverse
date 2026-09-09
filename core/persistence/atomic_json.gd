extends RefCounted
class_name AtomicJson

## Stage and verify before replacing. Never remove the live file first.
## DirAccess.rename_absolute overwrites an existing writable file.
static func write(path: String, data: Dictionary, keep_backup: bool = true) -> Error:
	var text: String = JSON.stringify(data, "\t")
	var temporary: String = path + ".tmp"
	var error: Error = _write_text(temporary, text)
	if error != OK:
		return error
	if FileAccess.get_file_as_string(temporary) != text:
		return ERR_FILE_CORRUPT
	if keep_backup and FileAccess.file_exists(path):
		var old_text: String = FileAccess.get_file_as_string(path)
		if not parse_dictionary(old_text).is_empty():
			error = _write_text(path + ".bak.tmp", old_text)
			if error != OK:
				return error
			error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
			if error != OK:
				return error
	return DirAccess.rename_absolute(temporary, path)


static func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error



static func parse_dictionary(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	return parser.data
