extends RefCounted
## All guidance is presentation. No action here creates gameplay progress.
const Text = preload("res://core/localization/ui_text.gd")
const Keys = preload("res://core/input_preferences.gd")

static func title(step: String) -> String:
	return Text.text("GUIDE_STEP_" + step.to_upper())

static func chapter(chapter_id: String) -> String:
	return Text.text("GUIDE_CHAPTER_" + chapter_id.to_upper())

static func hint(step: String, detailed: bool = false) -> String:
	var values := {"interact": Keys.binding_label("primary_action"),
		"scan": Keys.binding_label("inspection_mode"), "jump": Keys.binding_label("jump"),
		"forward": Keys.binding_label("move_forward"), "left": Keys.binding_label("move_left"),
		"back": Keys.binding_label("move_back"), "right": Keys.binding_label("move_right")}
	var result := Text.format_text("GUIDE_HINT_" + step.to_upper(), values)
	if detailed:
		result += "\n" + Text.text("GUIDE_DETAIL_" + step.to_upper())
	return result
