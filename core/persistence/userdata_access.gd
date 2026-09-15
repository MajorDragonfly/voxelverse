extends RefCounted
## Process-owned lease shared with tools/userdata_access.py. Nested runtime
## owners retain one lease until the last reference ends, including unsaved roots.
const FORMAT: String = "voxelverse_userdata_access_v1"
const SUFFIX: String = ".voxelverse-access-v1"
static var _mutex := Mutex.new()
static var _users: int = 0
static var _owner: Dictionary = {}
static var _path: String = ""
var _active: bool = false

static func lock_path() -> String:
	var directory := DirAccess.open(OS.get_user_data_dir())
	if directory == null: return ""
	var source: String = directory.get_current_dir().trim_suffix("/")
	# Resolve a user directory that is itself a symlink. Ancestor aliases lead
	# to the same sibling on disk; a root alias otherwise changes the lock name.
	for _step in range(16):
		var parent := DirAccess.open(source.get_base_dir())
		if parent == null: return ""
		if not parent.is_link(source.get_file()): break
		var target: String = parent.read_link(source.get_file())
		if target.is_empty(): return ""
		source = (target if target.is_absolute_path() else source.get_base_dir().path_join(target)).simplify_path()
		if _step == 15: return ""
	return source.get_base_dir().path_join("." + source.get_file() + SUFFIX)

static func _host() -> String:
	var host: String = OS.get_environment("COMPUTERNAME")
	if host.is_empty(): host = OS.get_environment("HOSTNAME")
	if host.is_empty():
		for path: String in ["/etc/hostname", "/proc/sys/kernel/hostname"]:
			if FileAccess.file_exists(path):
				host = FileAccess.get_file_as_string(path).strip_edges()
				break
	return host

static func acquire() -> RefCounted:
	_mutex.lock()
	var result: RefCounted = null
	if _users > 0 or _begin():
		_users += 1
		result = load("res://core/persistence/userdata_access.gd").new()
		result._active = true
	_mutex.unlock()
	return result

static func _read_owner(path: String) -> Dictionary:
	var directory := DirAccess.open(path)
	if directory == null or directory.get_directories().size() != 0 or directory.get_files() != PackedStringArray(["owner.json"]): return {}
	if directory.is_link("owner.json"): return {}
	var file := FileAccess.open(path.path_join("owner.json"), FileAccess.READ)
	if file == null or file.get_length() > 4096: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or value.size() != 6 or value.get("schema") != 1 or value.get("format") != FORMAT: return {}
	if not value.get("pid") is float and not value.get("pid") is int: return {}
	if value.pid <= 0 or value.pid > 2147483647 or value.pid != int(value.pid) or not value.get("host") is String: return {}
	if not value.get("token") is String or value.token.length() != 64 or value.get("role") not in ["writer", "offline"]: return {}
	for c in value.token:
		if c not in "0123456789abcdef": return {}
	value.schema = int(value.schema)
	value.pid = int(value.pid)
	return value

static func _write_owner(path: String, owner: Dictionary) -> bool:
	var file := FileAccess.open(path.path_join("owner.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(owner))
	file.flush()
	var success: bool = file.get_error() == OK
	file.close()
	return success and _read_owner(path) == owner

static func _remove_owned(path: String, owner: Dictionary) -> void:
	if _read_owner(path) == owner:
		DirAccess.remove_absolute(path.path_join("owner.json"))
		DirAccess.remove_absolute(path)

static func _begin() -> bool:
	var gate: String = lock_path()
	if gate.is_empty(): return false
	# Never steal a gate from Godot: its Unix process-running API only tracks
	# child processes. Python tooling performs same-host dead-PID recovery.
	if DirAccess.make_dir_absolute(gate) != OK: return false
	_owner = {"schema": 1, "format": FORMAT, "pid": OS.get_process_id(), "host": _host(),
		"token": Crypto.new().generate_random_bytes(32).hex_encode(), "role": "writer"}
	var success: bool = _write_owner(gate, _owner)
	var writers: String = gate + ".writers"
	var parent := DirAccess.open(gate.get_base_dir())
	if success:
		if parent == null or parent.is_link(writers.get_file()):
			success = false
		elif not DirAccess.dir_exists_absolute(writers):
			success = DirAccess.make_dir_absolute(writers) == OK
	if success:
		_path = writers.path_join(_owner.token)
		success = DirAccess.make_dir_absolute(_path) == OK
		if success:
			success = _write_owner(_path, _owner)
			if not success:
				DirAccess.remove_absolute(_path.path_join("owner.json"))
				DirAccess.remove_absolute(_path)
	# The gate is short-lived for writers; the marker lasts through unsaved
	# roots and complete SaveGameService lifetime. Offline tools hold the gate
	# for the whole scan and reject any live/incomplete/foreign writer marker.
	DirAccess.remove_absolute(gate.path_join("owner.json"))
	DirAccess.remove_absolute(gate)
	if not success: _owner = {}
	return success

func release() -> void:
	if _active:
		_active = false
		_release_user()

static func _release_user() -> void:
	_mutex.lock()
	_users -= 1
	if _users == 0:
		_remove_owned(_path, _owner)
		_owner = {}
	_mutex.unlock()

func _notification(what: int) -> void:
	# RefCounted has already reached zero here: calling an instance method is
	# invalid in Godot. Static cleanup also covers owners dropped without release.
	if what == NOTIFICATION_PREDELETE and _active:
		_active = false
		_release_user()
