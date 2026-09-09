extends RefCounted
## Release audio while the tree and mixer still run, then terminate the runtime.

static func finish(tree: SceneTree, code: int = 0) -> void:
	if tree.has_meta(&"runtime_finishing"):
		return
	tree.set_meta(&"runtime_finishing", true)
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null:
		audio.prepare_shutdown()
		audio.queue_free()
		await tree.process_frame
		# Mixer cleanup follows wall time, even during accelerated simulation.
		await tree.create_timer(0.15, true, false, true).timeout
	tree.quit(code)
