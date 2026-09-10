extends SceneTree
## Maintainer utility: run only at the explicitly documented legacy baseline.
func _initialize() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(preload("res://tests/creature_foot_snapshot.gd").capture(), "\t") + "\n")
	file.close()
	quit()
