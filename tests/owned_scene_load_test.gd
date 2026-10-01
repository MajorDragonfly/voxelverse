extends SceneTree
## Real background loads, early owner removal, shutdown and exclusive handoff.
const Loader = preload("res://core/owned_scene_load.gd")
const SHUTDOWN = preload("res://core/runtime_shutdown.gd")
const SCENE: String = "res://tests/fixtures/owned_scene_load_scene.tscn"
var failures: Array[String] = []

class RequestOwner extends Node:
	var loader := Loader.new()
	func _exit_tree() -> void:
		loader.discard(get_tree())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var loader := Loader.new()
	_expect(loader.begin("res://missing-owned-scene.tscn") == ERR_FILE_NOT_FOUND and not loader.is_active(), "Missing scene began a worker.")
	_expect(loader.begin(SCENE) == OK, "Cold scene load failed to start.")
	_expect(loader.begin(SCENE) == ERR_BUSY, "A second request replaced the first owner.")
	var deadline: int = Time.get_ticks_msec() + 10000
	while not loader.is_ready() and Time.get_ticks_msec() < deadline: await process_frame
	_expect(loader.is_ready(), "Scene load did not finish within its lifecycle budget.")
	var packed: PackedScene = loader.take()
	_expect(packed != null and not loader.is_active() and loader.take() == null, "Result ownership was lost or delivered twice.")
	if packed != null:
		var node := packed.instantiate()
		_expect(node.name == "Empty", "Loaded scene has the wrong content.")
		node.free()
	packed = null
	# Repeated warm and cold ownership must always join, including discarded work.
	for index in range(64):
		_expect(loader.begin(SCENE) == OK, "Joined loader did not accept the next request.")
		await loader.discard(self)
		_expect(not loader.is_active(), "Discard retained a thread or its result.")
	var owner := RequestOwner.new()
	root.add_child(owner)
	_expect(owner.loader.begin(SCENE) == OK, "Removed-owner fixture failed to start.")
	var retired: WeakRef = weakref(owner.loader)
	owner.free()
	deadline = Time.get_ticks_msec() + 10000
	while retired.get_ref() != null and Time.get_ticks_msec() < deadline: await process_frame
	_expect(retired.get_ref() == null, "Removing the owner left an unjoined loader alive.")
	var flow: Node = root.get_node("SessionFlow")
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	_expect(flow._scene_load.begin(SCENE) == OK, "Busy-flow fixture failed to start.")
	await flow._request_world()
	_expect(flow._scene_load.is_active(), "A duplicate internal request discarded the existing worker.")
	await flow._scene_load.discard(self)
	var saves: Node = root.get_node("SaveGameService")
	var slots_before: Array = saves.list_slots()
	flow.new_game("Shutdown before deferred slot creation", 15838)
	await flow.prepare_shutdown()
	for index in range(4): await process_frame
	_expect(not flow._scene_load.is_active() and saves.list_slots() == slots_before and current_scene.scene_file_path == flow.TITLE_SCENE,
		"A queued new game survived shutdown or changed saves.")
	# Also retire a real scene worker through the public shutdown coordinator.
	_expect(flow._scene_load.begin(flow.SPHERE_SCENE) == OK, "Immediate world shutdown fixture failed to start.")
	flow.loading = true
	flow._loading_scene = true
	flow._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	flow.request_quit()
	_expect(flow._scene_load.is_active() and not has_meta(&"runtime_finishing"), "Window/user quit bypassed the loading guard.")
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("OWNED_SCENE_LOAD_PASSED: cold/warm, busy guard, one result, discard, removed owner, queued-start cancellation, window/user guards, immediate shutdown.")
	await SHUTDOWN.finish(self, 0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
