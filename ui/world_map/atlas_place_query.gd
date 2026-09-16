extends RefCounted
## Disposable read-only search over the authoritative atlas ordinal index.
## Keep one result page; never materialize the register or persist search state.
const PAGE_SIZE: int = 64
const RECORDS_PER_STEP: int = 8
const STEP_BUDGET_USEC: int = 2000
var results: Array[Dictionary] = []
var active: bool = false
var has_next: bool = false
var failed: bool = false
var invalidated: bool = false
var scanned: int = 0
var total: int = 0
var offset: int = 0
var matched: int = 0
var _atlas: RefCounted
var _record: Dictionary
var _term: String
var _own: bool
var _friends: bool
var _visible: Callable
var _name: Callable

func begin(atlas: RefCounted, term: String, own: bool, friends: bool, start: int, visible: Callable, display_name: Callable) -> void:
	cancel()
	_atlas = atlas
	_record = atlas.data
	_term = term.strip_edges().to_lower()
	_own = own
	_friends = friends
	_visible = visible
	_name = display_name
	offset = maxi(0, start / PAGE_SIZE) * PAGE_SIZE
	total = atlas.places.count()
	active = own or friends
	if not atlas.last_error.is_empty(): failed = true; active = false

func cancel() -> void:
	active = false
	results.clear()
	has_next = false
	failed = false
	invalidated = false
	scanned = 0
	matched = 0
	total = 0
	offset = 0
	_atlas = null
	_record = {}
	_visible = Callable()
	_name = Callable()

func step() -> void:
	if not active: return
	if not is_same(_atlas.data, _record) or _atlas.places.count() != total:
		invalidated = true
		active = false
		results.clear()
		return
	var started: int = Time.get_ticks_usec()
	for unused in range(RECORDS_PER_STEP):
		if scanned >= total:
			active = false
			return
		var page: Dictionary = _atlas.place_page(scanned, 1)
		if page.is_empty() or page.places.size() != 1:
			failed = true
			active = false
			results.clear()
			return
		scanned += 1
		var place: Dictionary = page.places[0]
		if _matches(place):
			matched += 1
			if matched > offset:
				if results.size() == PAGE_SIZE:
					has_next = true
					active = false
					return
				results.append(place)
		if Time.get_ticks_usec() - started >= STEP_BUDGET_USEC: break
	if scanned >= total: active = false

func _matches(place: Dictionary) -> bool:
	if not (_own if place.own else _friends): return false
	# Do not query friendship for a name that cannot match. Unknown places are
	# never in this index; dead/lost allies still need the encounter owner's gate.
	if not _term.is_empty() and not str(place.name).to_lower().contains(_term) and not str(_name.call(place)).to_lower().contains(_term): return false
	return bool(_visible.call(place))
