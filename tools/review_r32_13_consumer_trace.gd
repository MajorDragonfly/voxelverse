extends "res://tests/development_path_test.gd"
## Diagnostic only: retain every consumer assertion and expose the click route.

func _click(control: Control) -> void:
	var tracing: bool = control == ui._development_tab
	if tracing:
		if not control.has_meta("r32_13_trace"):
			control.set_meta("r32_13_trace", true)
			control.pressed.connect(func() -> void: print("R32_CONSUMER_PRESSED development=", ui._development.visible, " body=", ui._body.visible))
		_trace("before", control)
	await super._click(control)
	if tracing:
		_trace("after", control)

func _trace(step: String, control: Control) -> void:
	var hovered: String = str(root.call("gui_get_hovered_control")) if root.has_method("gui_get_hovered_control") else "unavailable"
	print("R32_CONSUMER_TRACE ", JSON.stringify({"step": step, "target": str(control.get_path()),
		"rect": str(control.get_global_rect()), "canvas": str(control.get_global_transform_with_canvas()),
		"panel": str(ui._panel.get_global_rect()), "viewport": str(root.get_visible_rect()),
		"window": str(root.size), "mouse": str(root.get_mouse_position()), "hover": hovered,
		"focus": str(root.gui_get_focus_owner()), "development": ui._development.visible,
		"body": ui._body.visible, "journal": ui.journal.is_open}))
