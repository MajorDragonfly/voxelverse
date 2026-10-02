extends "res://core/diagnostics/frontend_probe.gd"
## Reuse the unchanged existing Controls consumer without its full world route.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	captures = false

func _click(control: Control) -> void:
	print("R32_15_CONSUMER_CLICK ", control.name if control != null else "missing", " rect=", control.get_global_rect() if control != null else Rect2(), " focus=", get_viewport().gui_get_focus_owner())
	super._click(control)
	print("R32_15_CONSUMER_AFTER_CLICK listening=", get_node("/root/DisplaySettings")._control_settings.listening_action)
