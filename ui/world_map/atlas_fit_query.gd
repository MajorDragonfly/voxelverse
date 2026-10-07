extends RefCounted
## Disposable, bounded read of the existing atlas. Four longitude cuts retain
## every visited cell while avoiding a giant rectangle across the chart seam.
## No new format, checkpoint, reveal, place, or persistent secondary index.
const Cube = preload("res://world/space/cube_sphere.gd")
const Chart = preload("res://ui/world_map/atlas_chart.gd")
const Store = preload("res://core/persistence/region_store.gd")
const WORK_PER_STEP: int = 64
const BUDGET_USEC: int = 2000
var active: bool = false
var failed: bool = false
var invalidated: bool = false
var bounds := Rect2(Vector2(INF, INF), Vector2.ZERO)
var work: int = 0
var _atlas: RefCounted
var _record: Dictionary
var _revision: int
var _store: RefCounted
var _pages: Array[Dictionary] = []
var _keys: Array = []
var _overlay: Dictionary
var _rows: Array = []
var _parts: PackedStringArray
var _row: int = 0
var _bits: int = 0
var _extents: Array[Rect2] = []

func begin(atlas: RefCounted) -> void:
	cancel()
	_atlas = atlas
	_record = atlas.data
	_revision = atlas.revision
	_overlay = atlas.data.tiles
	_keys = _overlay.keys()
	for i in range(4): _extents.append(Rect2(Vector2(INF, INF), Vector2.ZERO))
	_store = Store.new()
	_store.directory = atlas.store.directory
	if atlas.data.schema >= atlas.TILE_SCHEMA:
		if not _store.open(atlas.data.storage): failed = true; return
		if not _store.root.is_empty(): _pages.append({"hash":_store.root,"depth":0})
	active = true

func cancel() -> void:
	active = false
	failed = false
	invalidated = false
	work = 0
	bounds = Rect2(Vector2(INF, INF), Vector2.ZERO)
	_atlas = null
	_store = null
	_record = {}
	_overlay = {}
	_pages.clear()
	_keys.clear()
	_rows = []
	_extents.clear()
	_row = 0
	_bits = 0

func step() -> void:
	if not active: return
	if not is_same(_atlas.data, _record) or _atlas.revision != _revision:
		invalidated = true; active = false; return
	var started: int = Time.get_ticks_usec()
	for unused in range(WORK_PER_STEP):
		work += 1
		if _bits != 0:
			var column: int = roundi(log(float(_bits & -_bits)) / log(2.0))
			_include(Vector3i(int(_parts[0]), int(_parts[1]) * _atlas.TILE + column, int(_parts[2]) * _atlas.TILE + _row - 1))
			_bits &= _bits - 1
		elif not _rows.is_empty() and _row < _atlas.TILE:
			_bits = int(_rows[_row]); _row += 1
		elif not _keys.is_empty():
			var key: String = _keys.pop_back()
			_parts = key.split(":")
			if not _valid_tile_key(): failed = true; active = false; return
			_rows = _atlas._rows(key)
			_row = 0
			if not _atlas.last_error.is_empty(): failed = true; active = false; return
		elif not _pages.is_empty():
			# Reuse the authoritative trie reader and its validation/cache limits.
			# The separate reader never writes atlas roots or pending overlays.
			var entry: Dictionary = _pages.pop_back()
			if int(entry.depth) > 64: failed = true; active = false; return
			var page: Dictionary = _store._page(entry.hash)
			if page.is_empty(): failed = true; active = false; return
			if page.kind == "branch":
				for hash_value: String in page.children.values(): _pages.append({"hash":hash_value,"depth":int(entry.depth)+1})
			else:
				for key: String in page.entries:
					if not _overlay.has(key): _keys.append(key)
		else:
			active = false
			for extent: Rect2 in _extents:
				if extent.position.is_finite() and (not bounds.position.is_finite() or extent.size.x < bounds.size.x): bounds = extent
			return
		if Time.get_ticks_usec() - started >= BUDGET_USEC: break

func _include(cell: Vector3i) -> void:
	var address: Dictionary = _atlas.address_for(cell)
	var direction: Array = Cube.direction(address.face, address.u, address.v)
	var radius: float = _record.radius
	var longitude: float = atan2(float(direction[0]), float(direction[2]))
	var y: float = -asin(clampf(float(direction[1]), -1.0, 1.0)) * radius
	for i in range(4):
		var cut: float = i * PI * 0.5
		var point := Vector2((cut + Chart.wrap_exact(longitude - cut, PI)) * radius, y)
		_extents[i] = _extents[i].expand(point) if _extents[i].position.is_finite() else Rect2(point, Vector2.ZERO)

func _valid_tile_key() -> bool:
	if _parts.size() != 3: return false
	for part: String in _parts:
		if not part.is_valid_int(): return false
	var maximum: int = ceili(float(_record.divisions) / _atlas.TILE)
	return int(_parts[0]) in range(6) and int(_parts[1]) >= 0 and int(_parts[2]) >= 0 and int(_parts[1]) < maximum and int(_parts[2]) < maximum
