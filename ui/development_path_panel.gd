extends VBoxContainer

## Read-only chapter browser. Progress, blockers and saves remain with ProgressionService.
const Text = preload("res://core/localization/ui_text.gd")
const Symbols = preload("res://ui/catalog/development_symbols.gd")
const Style = preload("res://ui/progression_style.gd")
const Presentation = preload("res://ui/skills_presentation.gd")

const CHAPTERS := ["creature", "nest_group", "tribe", "medieval", "modern", "space"]
const MIN_TEXT_PIXELS := 12.0
const MIN_CHAPTER_PIXELS := 13.0
const GOAL_NAMES := {
	"neighbor_help": "PATH_GOAL_NEIGHBOR", "sustained_supply": "PATH_GOAL_SUPPLY",
	"working_professions": "PATH_GOAL_PROFESSIONS", "shared_stock": "PATH_GOAL_STOCK",
	"shared_tool": "PATH_GOAL_TOOL", "shared_hut": "PATH_GOAL_HUT",
	"shared_garden": "PATH_GOAL_GARDEN", "shared_meals": "PATH_GOAL_MEALS"
}

var _stage_labels: Dictionary = {}
var _home: Label
var _legacy: Label
var _transition: Label
var _stages: BoxContainer
var _community: Label
var _factions: Label
var _epochs: Dictionary = {}
var _future: BoxContainer
var _chapter_buttons: Dictionary = {}
var _chapter_details: Dictionary = {}
var _summary: Label
var _heading: Label
var _future_heading: Label
var _selected: String = "creature"
var _initialized_selection: bool = false


func _ready() -> void:
	name = "DevelopmentPath"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_heading = Style.label("", 19)
	add_child(_heading)
	_summary = Style.label("", 13, Style.MUTED)
	add_child(_summary)
	_stages = BoxContainer.new()
	_stages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stages.add_theme_constant_override("separation", 6)
	add_child(_stages)
	_future_heading = Style.label("", 12, Style.MUTED)
	add_child(_future_heading)
	_future = BoxContainer.new()
	_future.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_future.add_theme_constant_override("separation", 6)
	add_child(_future)
	for stage_id: String in CHAPTERS:
		var parent: BoxContainer = _stages if stage_id in ["creature", "nest_group", "tribe"] else _future
		var button := Style.button("")
		button.name = "Chapter_" + stage_id
		button.custom_minimum_size.y = 40
		button.add_theme_font_size_override("font_size", 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(select_chapter.bind(stage_id))
		parent.add_child(button)
		_chapter_buttons[stage_id] = button
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.add_theme_constant_override("separation", 6)
		add_child(detail)
		_chapter_details[stage_id] = detail
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		detail.add_child(title_row)
		var icon := Symbols.view(stage_id, false, 40)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		title_row.add_child(icon)
		var title := Style.label("", 19, Style.SOCIAL)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var status := Style.label("", 13, Style.MUTED)
		detail.add_child(status)
		var control := Style.label("", 14)
		detail.add_child(control)
		var description := Style.label("", 13, Style.MUTED)
		detail.add_child(description)
		_stage_labels[stage_id] = {"title": title, "status": status, "control": control,
			"description": description, "panel": detail, "icon": icon}
		if stage_id == "nest_group":
			_home = Style.label("", 13)
			detail.add_child(_home)
		if stage_id == "tribe":
			_community = Style.label("", 13)
			detail.add_child(_community)
			_legacy = Style.label("", 13, Style.SOCIAL)
			detail.add_child(_legacy)
			_transition = Style.label("", 13, Style.MUTED)
			detail.add_child(_transition)
			_factions = Style.label("", 13, Style.MUTED)
			detail.add_child(_factions)
		if stage_id in ["medieval", "modern"]:
			var goals := Style.label("", 13, Style.MUTED)
			detail.add_child(goals)
			var action := Style.button("")
			action.disabled = true
			action.custom_minimum_size.y = 38
			action.add_theme_font_size_override("font_size", 13)
			detail.add_child(action)
			_epochs[2 if stage_id == "medieval" else 3] = {
				"title": title, "goals": goals, "action": action}
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()


func select_chapter(id: String) -> void:
	if not id in _chapter_details:
		return
	_selected = id
	_update_selection()


func _update_selection() -> void:
	for id: String in CHAPTERS:
		_chapter_details[id].visible = id == _selected
		var active: bool = id == _selected
		_chapter_buttons[id].add_theme_stylebox_override("normal",
			Style.box(Color("2b4149") if active else Color("162630"),
				Style.SOCIAL if active else Color("354750"), 7))
		_chapter_buttons[id].add_theme_color_override("font_color", Style.TEXT if active else Style.MUTED)


func refresh() -> void:
	if _home == null:
		return
	var data: Dictionary = get_node("/root/ProgressionService").get_development_path()
	var phase: int = int(data["current_phase"])
	var current_stage: String = str(data["current_stage"])
	if not _initialized_selection:
		_selected = current_stage
		_initialized_selection = true
	_heading.text = Text.text("PATH_TITLE")
	_future_heading.text = Text.text("PATH_FUTURE")
	_summary.text = Text.format_text("PATH_SUMMARY", {
		"stage": Text.text("PATH_" + current_stage.to_upper() + "_NAME"),
		"phase": Presentation.phase_name(clampi(phase, 0, 5))})
	for stage_id: String in CHAPTERS:
		var labels: Dictionary = _stage_labels[stage_id]
		var title_key := "PATH_" + stage_id.to_upper() + "_NAME"
		var status_key := "PATH_CURRENT" if stage_id == current_stage else "PATH_PLAYABLE" if stage_id == "tribe" and phase == 0 else "PATH_PAST" if stage_id == "creature" and phase > 0 else "PATH_PLANNED" if stage_id in ["medieval", "modern", "space"] else "PATH_PRECURSOR"
		var title := Text.text(title_key)
		var status := Text.text(status_key)
		_chapter_buttons[stage_id].text = title + " · " + status
		_chapter_buttons[stage_id].tooltip_text = title + " · " + status
		labels["title"].text = title
		labels["status"].text = status
		labels["control"].text = Text.text("PATH_" + stage_id.to_upper() + "_CONTROL")
		labels["description"].text = Text.text("PATH_" + stage_id.to_upper() + "_DETAIL")
		labels["icon"].texture = Symbols.texture(stage_id, stage_id == "creature" or stage_id == "nest_group" and data["home"]["status"] == "saved" or stage_id == "tribe" and phase >= 1)
	var home: Dictionary = data["home"]
	_home.text = Text.format_text("PATH_HOME_MEMBERS", {"count": int(home["member_count"])}) if home["status"] == "saved" else Text.text("PATH_HOME_" + str(home["status"]).to_upper())
	if not home["runtime_available"] and phase == 0:
		_home.text += "\n" + Text.text("PATH_HOME_RUNTIME")
	var cooperation: int = roundi((float(data["legacy"]["group_cooperation"]["value"]) - 1.0) * 100.0)
	var defense: int = roundi((float(data["legacy"]["group_defense"]["value"]) - 1.0) * 100.0)
	_legacy.text = Text.format_text("PATH_BONUSES", {"cooperation": cooperation, "defense": defense})
	_legacy.text += "\n" + Text.text("PATH_BONUS_ACTIVE" if phase == 1 else "PATH_BONUS_LATER")
	_transition.text = Text.text("PATH_TRIBE_ACTIVE" if phase == 1 else "PATH_TRIBE_READY" if data["transition"]["available"] else "PATH_TRIBE_BLOCKED")
	_community.text = Text.format_text("PATH_TRIBE_POINTS", {"count": int(data["tribal_wallet"]["available"]["social"])})
	var earned := 0
	for goal: Dictionary in data["tribal_goals"]:
		if goal["completed"]:
			earned += 1
		var goal_key: String = GOAL_NAMES.get(str(goal["id"]), "")
		var goal_name: String = Text.text(goal_key) if not goal_key.is_empty() else str(goal["name"])
		_community.text += "\n%s %s · +%d" % ["✓" if goal["completed"] else "○", goal_name, int(goal["points"])]
	_community.tooltip_text = Text.format_text("PATH_GOAL_COUNT", {"earned": earned, "total": data["tribal_goals"].size()})
	_factions.text = Text.text("PATH_FACTIONS")
	for epoch: Dictionary in data["epochs"]:
		var target: int = int(epoch["target"])
		var controls: Dictionary = _epochs[target]
		var chapter_id := "medieval" if target == 2 else "modern"
		controls["title"].text = Text.text("PATH_" + chapter_id.to_upper() + "_NAME")
		controls["goals"].text = Text.text("PATH_REQUIREMENTS")
		for requirement: Dictionary in epoch["requirements"]:
			var key := "PATH_REQUIREMENT_" + chapter_id.to_upper() + "_" + str(requirement["id"]).to_upper()
			controls["goals"].text += "\n%s %s" % ["✓" if requirement["met"] else "○", Text.text(key)]
		controls["action"].text = Text.text("PATH_LOCKED_ACTION")
		controls["action"].tooltip_text = Text.text("PATH_FUTURE_BLOCKED")
		controls["action"].disabled = true
	_update_selection()
	_layout()


func _layout() -> void:
	if _stages == null:
		return
	var width: float = get_viewport().get_visible_rect().size.x
	var scale: float = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	# The settings host stretches a 1920x1080 canvas into small windows.
	# Account for that final downscale as well as the requested UI scale.
	var visible_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	var pixel_scale := maxf(0.01, minf(window_size.x / visible_size.x, window_size.y / visible_size.y))
	_stages.vertical = width < 780 * scale
	_future.vertical = width < 780 * scale
	for button: Button in _chapter_buttons.values():
		_set_font_size(button, maxi(roundi(13 * scale), ceili(MIN_CHAPTER_PIXELS / pixel_scale)))
		_set_minimum_height(button, maxf(36 * scale, 30.0 / pixel_scale))
	for epoch: Dictionary in _epochs.values():
		var action: Button = epoch["action"]
		_set_font_size(action, maxi(roundi(13 * scale), ceili(MIN_CHAPTER_PIXELS / pixel_scale)))
		_set_minimum_height(action, maxf(38 * scale, 30.0 / pixel_scale))
	_scale_labels(self, scale, ceili(MIN_TEXT_PIXELS / pixel_scale))


func _scale_labels(node: Node, scale: float, minimum_font: int) -> void:
	if node is Label:
		if not node.has_meta("path_font_size"):
			node.set_meta("path_font_size", node.get_theme_font_size("font_size"))
		_set_font_size(node, maxi(roundi(int(node.get_meta("path_font_size")) * scale), minimum_font))
	for child: Node in node.get_children():
		_scale_labels(child, scale, minimum_font)


func _set_font_size(control: Control, value: int) -> void:
	# Font overrides invalidate container minimums. Repeated refresh/layout
	# calls must not keep queuing identical minimum-size notifications.
	if control.get_theme_font_size("font_size") != value:
		control.add_theme_font_size_override("font_size", value)


func _set_minimum_height(control: Control, value: float) -> void:
	if not is_equal_approx(control.custom_minimum_size.y, value):
		control.custom_minimum_size.y = value


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		call_deferred("refresh")
