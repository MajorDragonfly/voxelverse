extends SceneTree
## Mixer cleanup must receive wall time after a slow frame, not its old delta.


class ExitObserver extends Node:
	var audio_exit_usec: int = 0

	func audio_exited() -> void:
		audio_exit_usec = Time.get_ticks_usec()

	func _exit_tree() -> void:
		var elapsed_usec: int = Time.get_ticks_usec() - audio_exit_usec
		if audio_exit_usec == 0 or elapsed_usec < 140_000:
			push_error("Mixer cleanup ended too early after a slow frame: %d us" % elapsed_usec)
		else:
			print("RUNTIME_SHUTDOWN_PASSED: mixer received ", elapsed_usec, " us of wall time.")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var observer := ExitObserver.new()
	root.add_child(observer)
	root.get_node("AudioManager").tree_exited.connect(observer.audio_exited)
	await process_frame
	# Reproduce a blocking scene/terrain operation before the next frame.
	OS.delay_msec(350)
	await preload("res://core/runtime_shutdown.gd").finish(self)
