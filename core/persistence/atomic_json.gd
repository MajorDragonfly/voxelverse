extends RefCounted
class_name AtomicJson

## Persistent scalar doubles must survive JSON unchanged. This also applies
## to tiny Cube-Sphere face offsets, not just astronomical Cartesian values.
## Keep ordinary JSON numbers and sorted keys; existing readers still work.
static func stringify(value: Variant, indent: String = "\t") -> String:
	var frozen: Dictionary = {}
	_collect_frozen_blueprints(value, frozen)
	if frozen.is_empty(): return JSON.stringify(value, indent, true, true)
	# Schema-1 body evidence hashes the released shortened JSON representation
	# of frozen local anatomy. Preserve those exact subtrees, not new global
	# coordinates. Escaped design/source strings cannot match object text.
	var text: String = JSON.stringify(value, "", true, true)
	var encoded: Array = frozen.keys()
	encoded.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for precise: String in encoded: text = text.replace(precise, frozen[precise])
	return text

static func _collect_frozen_blueprints(value: Variant, frozen: Dictionary) -> void:
	if value is Dictionary:
		var proof: Variant = value.get("body_evidence")
		var blueprint: Variant = value.get("blueprint")
		if proof is Dictionary and proof.get("schema") == 1 and proof.get("source_sha256") is String \
			and blueprint is Dictionary and blueprint.get("body") is Dictionary and blueprint.get("parts") is Array:
			var precise: String = JSON.stringify(blueprint, "", true, true)
			frozen[precise] = JSON.stringify(blueprint, "", true, false)
		for child in value.values(): _collect_frozen_blueprints(child, frozen)
	elif value is Array:
		for child in value: _collect_frozen_blueprints(child, frozen)


## Stage and verify before replacing. Never remove the live file first.
## DirAccess.rename_absolute overwrites an existing writable file.
static func write(path: String, data: Dictionary, keep_backup: bool = true) -> Error:
	var text: String = stringify(data)
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
