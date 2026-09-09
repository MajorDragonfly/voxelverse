extends RefCounted

## Complete, bounded snapshots. The live save is replaced only after capture.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const MAX_SNAPSHOTS: int = 8

static func directory(slot_path: String) -> String:
	return slot_path + ".history"

static func paths(slot_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: String = directory(slot_path)
	if not DirAccess.dir_exists_absolute(dir):
		return result
	for name in DirAccess.get_files_at(dir):
		if name.begins_with("snapshot_") and name.ends_with(".json"):
			result.append(dir.path_join(name))
	result.sort()
	result.reverse()
	return result

static func capture(slot_path: String, snapshot: Dictionary, reason: String) -> Error:
	var dir: String = directory(slot_path)
	var error: Error = DirAccess.make_dir_recursive_absolute(dir)
	if error != OK:
		return error
	var record: Dictionary = snapshot.duplicate(true)
	record["slot_history"] = {"version": 1, "reason": reason,
		"captured_unix_time": int(Time.get_unix_time_from_system())}
	# Monotonic sequence survives wall-clock changes and multiple saves per tick.
	var sequence: int = 1
	var previous := paths(slot_path)
	if not previous.is_empty():
		sequence = int(previous[0].get_file().trim_prefix("snapshot_").get_slice("_", 0)) + 1
	var filename: String = "snapshot_%016d_%s.json" % [sequence, Crypto.new().generate_random_bytes(4).hex_encode()]
	return Atomic.write(dir.path_join(filename), record, false)

static func trim(slot_path: String) -> void:
	var records := paths(slot_path)
	for index in range(MAX_SNAPSHOTS, records.size()):
		# A cleanup failure retains an extra backup; it never invalidates a save.
		DirAccess.remove_absolute(records[index])

static func is_source(slot_path: String, source_path: String) -> bool:
	return source_path == slot_path + ".bak" or source_path in paths(slot_path)
