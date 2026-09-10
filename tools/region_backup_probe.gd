extends SceneTree
## Real RegionStore/SaveGameService writer and a separate-process reader.
const Store = preload("res://core/persistence/region_store.gd")
const History = preload("res://core/persistence/slot_history.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	saves.autosave_enabled = false
	var result: Dictionary = {}
	if "create" in OS.get_cmdline_user_args():
		var slot: String = saves.create_slot("Regions 1", 15838)
		_expect(not slot.is_empty(), "Slot creation failed: " + saves.last_error)
		var body: Dictionary = state.get_current_body_record()
		var store := Store.new()
		for i in range(1200):
			_expect(store.put("arch13:region:" + str(i), {"id": i, "stock": 7, "cargo": "milk"}), store.last_error)
		body.surface_population = {"schema": 2, "body_id": body.id, "storage": store.checkpoint()}
		_expect(saves.save_now(), "First root save failed: " + saves.last_error)
		for i in range(1200):
			store.get_value("arch13:region:" + str(i), true).stock = 8
		body.surface_population.storage = store.checkpoint()
		saves.slot_name = "Regions 2"
		_expect(saves.save_now(), "Second root save failed: " + saves.last_error)
		result = {"slot": ProjectSettings.globalize_path(slot), "regions": ProjectSettings.globalize_path(Store.DIRECTORY),
			"campaign_id": state.campaign.data.id, "body_id": body.id}
	else:
		var checked: int = 0
		var peak_cache: int = 0
		var slot: String = ""
		for filename in DirAccess.get_files_at("user://saves"):
			if filename.ends_with(".json"): slot = "user://saves/" + filename
		_expect(not slot.is_empty(), "Restored slot missing")
		var paths: Array[String] = [slot, slot + ".bak"]
		paths.append_array(History.paths(slot))
		for path in paths:
			_expect(saves.load_now(path), "Restored save cannot load: " + path + " " + saves.last_error)
			var body: Dictionary = state.get_current_body_record()
			if not body.has("surface_population"): continue
			var store := Store.new()
			_expect(store.open(body.surface_population.storage), "Restored root missing")
			for i in range(1199, -1, -1):
				var record: Dictionary = store.get_value("arch13:region:" + str(i))
				_expect(record.get("id") == i and record.get("stock") == (8 if saves.slot_name == "Regions 2" else 7) and record.get("cargo") == "milk", "Restored region lost identity or cargo")
				checked += 1
			peak_cache = maxi(peak_cache, store.peak_cache)
		# Finish on the current snapshot for the cross-process identity check.
		_expect(saves.load_now(slot), "Current snapshot could not be restored")
		result = {"checked_regions": checked, "peak_cache": peak_cache,
			"campaign_id": state.campaign.data.id, "body_id": state.get_current_body_record().id}
	for message in failures: push_error(message)
	result["passed"] = failures.is_empty()
	print("REGION_BACKUP_PROBE ", JSON.stringify(result))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
