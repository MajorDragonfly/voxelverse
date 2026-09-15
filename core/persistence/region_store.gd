extends RefCounted
## Immutable blobs under a copy-on-write hash trie. A save commits one root.
## An old root remains readable after eviction, interrupted writes or rollback.
const FORMAT: String = "sha256_trie_v1"
const DIRECTORY: String = "user://regions/blobs"
const CACHE_LIMIT: int = 96
const PAGE_LIMIT: int = 128
const LEAF_LIMIT: int = 32
const MAX_BYTES: int = 2 * 1024 * 1024
const Atomic = preload("res://core/persistence/atomic_json.gd")
var directory: String = DIRECTORY
var root: String = ""
var last_error: String = ""
var unsupported: bool = false
var validate_value: Callable
var cache: Dictionary = {}
var pages: Dictionary = {}
var dirty: Dictionary = {}
var pinned: Dictionary = {}
var reads: int = 0
var writes: int = 0
var peak_cache: int = 0
var max_io_usec: int = 0

static func valid_hash(value: Variant, empty: bool = false) -> bool:
	if not value is String: return false
	if empty and value.is_empty(): return true
	if value.length() != 64: return false
	for c in value:
		if c not in "0123456789abcdef": return false
	return true

static func manifest_problem(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != 1 or value.get("format") != FORMAT or not valid_hash(value.get("root"), true): return "Unbekannter oder beschädigter Regionsspeicher."
	return ""

func open(value: Dictionary) -> bool:
	unsupported = value.get("schema", 1) != 1 or value.get("format", FORMAT) != FORMAT
	last_error = manifest_problem(value)
	if not last_error.is_empty(): return false
	root = value.root
	cache.clear()
	pages.clear()
	dirty.clear()
	pinned.clear()
	if not root.is_empty(): _page(root)
	return last_error.is_empty()

func manifest() -> Dictionary:
	return {"schema": 1, "format": FORMAT, "root": root}

func get_value(key: String, writable: bool = false) -> Dictionary:
	if not last_error.is_empty(): return {}
	if cache.has(key):
		var value: Dictionary = cache[key]
		cache.erase(key)
		cache[key] = value
		if writable: dirty[key] = true
		return value
	var hash_value: String = _lookup(root, key, key.sha256_text(), 0)
	if hash_value.is_empty(): return {}
	var value: Dictionary = _read(hash_value)
	if value.get("schema") != 1 or value.get("key") != key or not value.get("value") is Dictionary:
		_fail("Regionsinhalt passt nicht zum Index: " + key)
		return {}
	if not _room(): return {}
	cache[key] = value.value
	peak_cache = maxi(peak_cache, cache.size())
	if writable: dirty[key] = true
	return cache[key]

func put(key: String, value: Dictionary) -> bool:
	if key.is_empty() or key.length() > 400: return _fail("Ungültiger Regionsschlüssel.")
	if not last_error.is_empty() or (not cache.has(key) and not _room()): return false
	cache[key] = value
	dirty[key] = true
	peak_cache = maxi(peak_cache, cache.size())
	return true

func checkpoint() -> Dictionary:
	for key in dirty.keys():
		if not _flush(key): return {}
	return manifest() if last_error.is_empty() else {}

func _room() -> bool:
	if cache.size() < CACHE_LIMIT: return true
	for key in cache:
		if pinned.has(key): continue
		if not _flush(key): return false
		cache.erase(key)
		return true
	return _fail("Alle Regionspuffer sind aktiv; Nachladen wurde angehalten.")

func _flush(key: String) -> bool:
	if not dirty.has(key): return true
	if validate_value.is_valid():
		var problem: String = validate_value.call(key, cache[key])
		if not problem.is_empty(): return _fail(problem)
	var hash_value: String = _write({"schema": 1, "key": key, "value": cache[key]})
	if hash_value.is_empty(): return false
	var next: String = _set_entry(root, key, key.sha256_text(), hash_value, 0)
	if next.is_empty(): return false
	root = next
	dirty.erase(key)
	return true

func _lookup(hash_value: String, key: String, digest: String, depth: int) -> String:
	if hash_value.is_empty(): return ""
	if depth > 64: _fail("Regionsindex ist zu tief."); return ""
	var page: Dictionary = _page(hash_value)
	if page.is_empty(): return ""
	if page.kind == "leaf": return page.entries.get(key, "")
	if depth == 64: _fail("Regionsindex überschreitet den Adressraum."); return ""
	return _lookup(page.children.get(digest[depth], ""), key, digest, depth + 1)

func _set_entry(hash_value: String, key: String, digest: String, value: String, depth: int) -> String:
	if depth > 64: _fail("Regionsindex überschreitet den Adressraum."); return ""
	var page: Dictionary = {"schema": 1, "kind": "leaf", "entries": {}} if hash_value.is_empty() else _page(hash_value).duplicate(true)
	if page.is_empty(): return ""
	if page.kind == "leaf":
		if page.entries.get(key) == value: return hash_value
		page.entries[key] = value
		return _partition(page.entries, depth)
	if depth == 64: _fail("Regionsindex überschreitet den Adressraum."); return ""
	var child: String = _set_entry(page.children.get(digest[depth], ""), key, digest, value, depth + 1)
	if child.is_empty(): return ""
	page.children[digest[depth]] = child
	return _write_page(page)

func _partition(entries: Dictionary, depth: int) -> String:
	if entries.size() <= LEAF_LIMIT: return _write_page({"schema": 1, "kind": "leaf", "entries": entries})
	if depth >= 64: _fail("Regionsindex enthält zu viele gleiche Hashadressen."); return ""
	var buckets: Dictionary = {}
	for key: String in entries:
		var digit: String = key.sha256_text()[depth]
		if not buckets.has(digit): buckets[digit] = {}
		buckets[digit][key] = entries[key]
	var children: Dictionary = {}
	for digit in buckets:
		children[digit] = _partition(buckets[digit], depth + 1)
		if children[digit].is_empty(): return ""
	return _write_page({"schema": 1, "kind": "branch", "children": children})

func _page(hash_value: String) -> Dictionary:
	if pages.has(hash_value): return pages[hash_value]
	var page: Dictionary = _read(hash_value)
	if page.get("schema") != 1 or page.get("kind") not in ["leaf", "branch"]:
		_fail("Unbekannte Regionsindexseite.")
		return {}
	var branch: bool = page.kind == "branch"
	var entries: Variant = page.get("children" if branch else "entries")
	if not entries is Dictionary or entries.size() > (16 if branch else LEAF_LIMIT):
		_fail("Regionsindexseite überschreitet ihr Budget.")
		return {}
	for key in entries:
		if not key is String or key.is_empty() or key.length() > (1 if branch else 400) or (branch and key not in "0123456789abcdef") or not valid_hash(entries[key]):
			_fail("Ungültiger Verweis im Regionsindex.")
			return {}
	_remember_page(hash_value, page)
	return page

func _write_page(page: Dictionary) -> String:
	var hash_value: String = _write(page)
	if not hash_value.is_empty(): _remember_page(hash_value, page)
	return hash_value

func _remember_page(hash_value: String, page: Dictionary) -> void:
	if not pages.has(hash_value) and pages.size() >= PAGE_LIMIT: pages.erase(pages.keys()[0])
	pages[hash_value] = page

func _read(hash_value: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not valid_hash(hash_value): _fail("Ungültige Regionsdateiadresse."); return {}
	var file := FileAccess.open(_path(hash_value), FileAccess.READ)
	if file == null: _fail("Regionsdatei fehlt: " + hash_value); return {}
	if file.get_length() > MAX_BYTES: file.close(); _fail("Regionsdatei überschreitet ihr Budget."); return {}
	var contents: String = file.get_as_text()
	file.close()
	if contents.sha256_text() != hash_value: _fail("Regionsdatei ist beschädigt: " + hash_value); return {}
	var value: Dictionary = Atomic.parse_dictionary(contents)
	if value.is_empty(): _fail("Regionsdatei ist nicht lesbar: " + hash_value)
	if value.has("schema") and value.schema != 1:
		unsupported = true
		_fail("Unbekannte Regionsdateiversion bleibt geschützt: " + hash_value)
		return {}
	reads += 1
	max_io_usec = maxi(max_io_usec, Time.get_ticks_usec() - started)
	return value

func _write(value: Dictionary) -> String:
	if not last_error.is_empty(): return ""
	var started: int = Time.get_ticks_usec()
	# Hash the exact bytes written. Older blobs retain their original hashes
	# and remain readable; only new/changed values use full double precision.
	var contents: String = Atomic.stringify(value, "")
	if contents.to_utf8_buffer().size() > MAX_BYTES: _fail("Regionsdatei überschreitet ihr Budget."); return ""
	var hash_value: String = contents.sha256_text()
	var path: String = _path(hash_value)
	if FileAccess.file_exists(path):
		# Content addresses never authorize overwriting damaged existing data.
		_read(hash_value)
		return hash_value if last_error.is_empty() else ""
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: _fail("Regionsverzeichnis kann nicht angelegt werden."); return ""
	var temporary: String = path + "." + str(OS.get_process_id()) + ".tmp"
	if Atomic._write_text(temporary, contents) != OK or FileAccess.get_file_as_string(temporary) != contents or DirAccess.rename_absolute(temporary, path) != OK:
		_fail("Regionsdatei konnte nicht atomar gesichert werden.")
		return ""
	writes += 1
	max_io_usec = maxi(max_io_usec, Time.get_ticks_usec() - started)
	return hash_value

func _path(hash_value: String) -> String:
	return directory.path_join(hash_value.left(2)).path_join(hash_value + ".json")

func _fail(message: String) -> bool:
	if last_error.is_empty(): last_error = message
	return false
