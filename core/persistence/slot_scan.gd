extends RefCounted
## Read-only cooperative scan. Each advance discovers at most 64 directory
## entries OR validates one slot/history source. A single validation is atomic;
## the time budget cannot interrupt JSON parsing or filesystem calls.
const MAX_ENTRIES: int = 64
const SLICE_USECS: int = 2000
var pending: bool = true
var discovering: bool = true
var result: Array[Dictionary] = []
var paths: Array[String] = []
var inspected: int = 0
var last_entries: int = 0
var last_inspections: int = 0
var _service: Node
var _history_mode: bool
var _history_path: String
var _directory: DirAccess
var _path_set: Dictionary = {}
var _identities: Dictionary = {}

func _init(service: Node, history_path: String = "", history_mode: bool = false) -> void:
	_service = service
	_history_path = history_path
	_history_mode = history_mode
	if _history_mode:
		if not service.is_slot_path(history_path):
			pending = false
			discovering = false
			return
		_directory = DirAccess.open(service.History.directory(history_path))
	else:
		var previous: String = service.DEFAULT_SAVE_PATH
		if FileAccess.file_exists(previous) or FileAccess.file_exists(previous + ".bak") or DirAccess.dir_exists_absolute(service.History.directory(previous)):
			_add(previous)
		_directory = DirAccess.open(service.SLOT_DIRECTORY)
	if _directory != null and _directory.list_dir_begin() != OK:
		_directory = null

func advance() -> bool:
	last_entries = 0
	last_inspections = 0
	if not pending: return true
	if not is_instance_valid(_service):
		cancel()
		return true
	if discovering:
		var started := Time.get_ticks_usec()
		while _directory != null and last_entries < MAX_ENTRIES:
			var filename := _directory.get_next()
			if filename.is_empty():
				_directory.list_dir_end()
				_directory = null
				break
			last_entries += 1
			var is_directory := _directory.current_is_dir()
			if _history_mode:
				if not is_directory and filename.begins_with("snapshot_") and filename.ends_with(".json"):
					_add(_service.History.directory(_history_path).path_join(filename))
			else:
				var candidate := filename.trim_suffix(".history") if is_directory else filename.trim_suffix(".bak")
				var path: String = _service.SLOT_DIRECTORY.path_join(candidate)
				if (not is_directory or filename.ends_with(".history")) and _service.is_slot_path(path): _add(path)
			if Time.get_ticks_usec() - started >= SLICE_USECS: break
		if _directory == null:
			discovering = false
			paths.sort()
			if _history_mode:
				paths.reverse()
				if FileAccess.file_exists(_history_path + ".bak"): _add(_history_path + ".bak")
			if paths.is_empty(): pending = false
		return not pending
	last_inspections = 1
	var path: String = paths[inspected]
	if not _history_mode:
		result.append(_service.inspect_slot(path))
	else:
		var record: Dictionary = _service.inspect_history_source(_history_path, path)
		if not _identities.has(record.identity):
			_identities[record.identity] = true
			result.append(record.entry)
	inspected += 1
	if inspected == paths.size():
		pending = false
		if not _history_mode:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.path) > str(b.path) if int(a.saved_time) == int(b.saved_time) else int(a.saved_time) > int(b.saved_time))
	return not pending

func _add(path: String) -> void:
	if _path_set.has(path): return
	_path_set[path] = true
	paths.append(path)

func cancel() -> void:
	if _directory != null: _directory.list_dir_end()
	_directory = null
	pending = false
	discovering = false
	result = []
	paths = []
	_path_set = {}
	_identities = {}
	_service = null
