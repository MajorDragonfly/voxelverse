extends Node
## Standalone entry point only. A production host needs its own close adapter.
const Preview = preload("res://civilization/technology/technology_preview.tscn")

func _ready() -> void:
	var version: Dictionary = Engine.get_version_info()
	if version["major"] != 4 or version["minor"] != 6 or version["patch"] != 3:
		push_error("The medieval technology prototype requires Godot 4.6.3")
		get_tree().quit(1)
		return
	var panel: Control = Preview.instantiate()
	panel.close_requested.connect(func() -> void: get_tree().quit())
	add_child(panel)
	print("MEDTECH_ENTRY_READY: standalone scene; no campaign autoloads")
