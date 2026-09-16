extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void: root.add_child(load("res://core/diagnostics/player_recovery_probe.gd").new())

func _finalize() -> void:
	if not has_meta("recovery_completed"):
		printerr("ERROR: Recovery probe exited before its completion marker.")
