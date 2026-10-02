extends "res://core/diagnostics/frontend_probe.gd"
## Reuse the unchanged existing Controls consumer without its full world route.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	captures = false
