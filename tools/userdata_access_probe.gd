extends SceneTree
## Subprocess endpoint for the Python lifecycle acceptance test. The parent
## owns process termination and archive replay; this uses the real game writers.
const Access = preload("res://core/persistence/userdata_access.gd")
const Store = preload("res://core/persistence/region_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var campaign_store: RefCounted
var laboratory_store: RefCounted

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0]
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.session_managed = true
	var result: Dictionary = {"user_data": OS.get_user_data_dir(), "mode": mode}
	if mode == "blocked":
		var lease: RefCounted = Access.acquire()
		result["lease_blocked"] = lease == null
		if lease != null: lease.release()
		result["atomic_blocked"] = Atomic.write("user://blocked.json", {"value": 1}) == ERR_BUSY
		campaign_store = Store.new()
		result["region_blocked"] = not campaign_store.put("blocked", {"stock": 99})
		result["save_blocked"] = not saves.save_now()
		result["copy_blocked"] = saves.duplicate_slot("user://unused.json").is_empty()
		result["clear_blocked"] = not saves.clear_save()
		result["create_blocked"] = saves.create_slot("Blocked", 15838).is_empty()
	elif mode == "hold":
		campaign_store = Store.new()
		laboratory_store = Store.new()
		laboratory_store.directory = "user://living_fauna/blobs"
		var ok: bool = campaign_store.put("region:stable", {"stock": 7})
		ok = laboratory_store.put("lab:stable", {"health": 80}) and ok
		var snapshot: Dictionary = {"storage": campaign_store.checkpoint(), "fauna_archive": {
			"schema": 1, "body_id": "body:access", "count": 1, "storage": laboratory_store.checkpoint()}}
		ok = Atomic.write("user://access_snapshot.json", snapshot) == OK and ok
		# Written, but not yet committed to an owner: an offline scan must wait
		# even though the last snapshot itself is a complete, healthy generation.
		ok = campaign_store.put("region:pending", {"stock": 9}) and ok
		ok = not campaign_store.checkpoint().is_empty() and ok
		result["prepared"] = ok
	else:
		var lease: RefCounted = Access.acquire()
		result["acquired"] = lease != null
		if lease != null: lease.release()
	print("USERDATA_ACCESS_PROBE ", JSON.stringify(result))
	if mode == "hold":
		var deadline: int = Time.get_ticks_msec() + 30000
		while not FileAccess.file_exists(args[1]) and Time.get_ticks_msec() < deadline:
			await create_timer(0.02).timeout
	campaign_store = null
	laboratory_store = null
	await preload("res://core/runtime_shutdown.gd").finish(self)
