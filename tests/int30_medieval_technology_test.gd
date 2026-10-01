extends SceneTree
## Execute the isolated prototype checks without importing preview state.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output: Array = []
	var code: int = OS.execute("python3", [ProjectSettings.globalize_path("res://civilization/technology/run_preview.py"),
		"--godot", OS.get_executable_path(), "--verify", "--output", ProjectSettings.globalize_path("user://int30_medieval_checks")], output, true)
	for line: String in output: print(line)
	if code != 0: push_error("Isolated medieval technology prototype checks failed")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if code == 0 else 1)
