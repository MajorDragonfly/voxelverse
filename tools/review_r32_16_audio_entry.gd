extends SceneTree
## Run the existing public campaign launcher with the R32 audio-only consumer.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	var probe: Script = load("res://tools/review_r32_16_audio_campaign.gd")
	if probe == null or not probe.can_instantiate():
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	root.add_child(probe.new())
