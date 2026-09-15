extends RefCounted
## Read-only paged directory cursor. It retains one page, not whole designs.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const PAGE_SIZE: int = 12
const ENTRIES_PER_TICK: int = 32
const READS_PER_TICK: int = 2
const BUDGET_USEC: int = 3000
var entries: Array[Dictionary] = []
var done: bool = true
var may_have_more: bool = false
var next_offset: int = 0
var last_reads: int = 0
var last_scanned: int = 0
var _directory: DirAccess
var _query: String = ""
var _role: String = ""
var _skip: int = 0
var _root: String = ""

func start(path: String = Ship.DIRECTORY, query: String = "", role: String = "", offset: int = 0) -> void:
	cancel()
	entries.clear()
	next_offset = 0
	may_have_more = false
	_query = query.strip_edges().to_lower()
	_role = role
	_skip = maxi(offset, 0)
	_root = path
	_directory = DirAccess.open(path)
	done = _directory == null
	if not done: done = _directory.list_dir_begin() != OK

func cancel() -> void:
	if _directory != null: _directory.list_dir_end()
	_directory = null
	done = true

func advance() -> void:
	last_reads = 0
	last_scanned = 0
	if done: return
	var start_time: int = Time.get_ticks_usec()
	while last_scanned < ENTRIES_PER_TICK and last_reads < READS_PER_TICK:
		if last_scanned > 0 and Time.get_ticks_usec() - start_time >= BUDGET_USEC: return
		var filename: String = _directory.get_next()
		if filename.is_empty():
			cancel()
			return
		next_offset += 1
		last_scanned += 1
		if next_offset <= _skip or _directory.current_is_dir() or not filename.ends_with(".json"): continue
		last_reads += 1
		var loaded: Dictionary = Ship.load_design(_root.path_join(filename))
		var display_name: String = loaded.blueprint.name if loaded.ok else filename
		var role: String = loaded.blueprint.ship.role if loaded.ok else ""
		# Broken/newer entries remain visible in the general library, protected
		# by the real loader. A fit picker only shows readable opposite roles.
		if not _role.is_empty() and role != _role: continue
		if not _query.is_empty() and not display_name.to_lower().contains(_query): continue
		entries.append({"path": _root.path_join(filename), "name": display_name,
			"role": role, "revision": loaded.blueprint.revision if loaded.ok else 0,
			"ok": loaded.ok, "code": loaded.code})
		if entries.size() >= PAGE_SIZE:
			may_have_more = true
			cancel()
			return
