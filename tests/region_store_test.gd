extends SceneTree
const Store = preload("res://core/persistence/region_store.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var store := Store.new()
	store.directory = "user://region-store-test"
	for i in range(1200):
		_expect(store.put("region:" + str(i), {"id": i, "stock": 7, "cargo": "milk"}), "Write failed: " + store.last_error)
	var first: Dictionary = store.checkpoint()
	_expect(not first.is_empty() and store.cache.size() <= Store.CACHE_LIMIT and store.pages.size() <= Store.PAGE_LIMIT, "Growing world exceeded resident memory budgets.")
	for i in range(1199, -1, -1):
		var data: Dictionary = store.get_value("region:" + str(i), true)
		if data.is_empty(): _expect(false, store.last_error); break
		_expect(data.id == i and data.stock == 7 and data.cargo == "milk", "Eviction lost inventory.")
		data.stock += 1
	var second: Dictionary = store.checkpoint()
	var old := Store.new()
	old.directory = store.directory
	_expect(old.open(first), "Cannot open earlier save root.")
	_expect(old.reads == 1, "Opening a slot deserialized visited regions.")
	_expect(old.get_value("region:10").stock == 7, "Later writes mutated an older save.")
	var fresh := Store.new()
	fresh.directory = store.directory
	_expect(fresh.open(second) and fresh.get_value("region:10").stock == 8, "Fresh reader lost committed state.")
	var broken := Store.new()
	broken.directory = "user://missing-regions"
	_expect(not broken.open(first) and not broken.last_error.is_empty(), "Missing data silently became a new world.")
	var future: Dictionary = first.duplicate(true)
	future.schema = 2
	_expect(not fresh.open(future), "Future storage version was accepted.")
	var future_root: String = store._write({"schema": 2, "kind": "leaf", "entries": {}})
	future = {"schema": 1, "format": Store.FORMAT, "root": future_root}
	_expect(not fresh.open(future) and fresh.unsupported, "Future root could fall back to an older save.")
	var saved: Dictionary = {"game_state": {"campaign": {}}}
	saved.game_state.campaign.bodies = {"15838": {"surface_population": {"schema": 2, "storage": future}}}
	var global_root: String = Store.new()._write({"schema": 2, "kind": "leaf", "entries": {}})
	saved.game_state.campaign.bodies["15838"].surface_population.storage.root = global_root
	_expect(root.get_node("SaveGameService")._has_unsupported_contract(saved), "Save loader would replace a future regional root with a backup.")
	var file := FileAccess.open(old._path(first.root), FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	var corrupt := Store.new()
	corrupt.directory = store.directory
	_expect(not corrupt.open(first), "Corrupt root was accepted.")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("REGION_STORE_PASSED: 1200 regions, bounded caches, lazy load, immutable history, corruption and future protection.")
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
