extends SceneTree
## Run only against the pre-extraction hand geometry at 4a3c805.
func _initialize() -> void:
	var ids: Array = ["hands_grasp", "hands_claws", "hands_pincers"]
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(preload("res://tests/creature_foot_snapshot.gd").capture(ids), "\t") + "\n")
	file.close()
	quit()
