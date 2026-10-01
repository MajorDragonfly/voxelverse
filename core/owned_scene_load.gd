extends RefCounted
## One background scene load, with explicit ownership and a joined result.
## Godot 4.6.3 can leave a native LoadToken when a public threaded Get races
## the worker's final unreference. A user Thread runs synchronous load inline.

var _thread: Thread

func begin(path: String) -> Error:
	if is_active(): return ERR_BUSY
	if not ResourceLoader.exists(path, "PackedScene"): return ERR_FILE_NOT_FOUND
	_thread = Thread.new()
	var error: Error = _thread.start(_load.bind(path))
	if error != OK: _thread = null
	return error

func is_active() -> bool:
	return _thread != null

func is_ready() -> bool:
	return is_active() and not _thread.is_alive()

func take() -> PackedScene:
	if not is_ready(): return null
	var result: Variant = _thread.wait_to_finish()
	_thread = null
	return result as PackedScene

func discard(tree: SceneTree) -> void:
	# Resource loading may publish changed-signal connections on the main
	# queue. Keep frames advancing before joining an unfinished user Thread.
	# Retain ownership if the requesting node leaves the tree mid-load.
	var keep_alive: RefCounted = self
	while is_active() and _thread.is_alive():
		await tree.process_frame
	keep_alive.call("join")

func join() -> void:
	if not is_active(): return
	_thread.wait_to_finish()
	_thread = null

static func _load(path: String) -> PackedScene:
	return ResourceLoader.load(path, "PackedScene") as PackedScene
