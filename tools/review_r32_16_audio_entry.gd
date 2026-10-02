extends SceneTree
## Run the existing public campaign launcher with the R32 audio-only consumer.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	root.add_child(load("res://tools/review_r32_16_audio_campaign.gd").new())
