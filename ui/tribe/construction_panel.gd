extends VBoxContainer
## Stable project controls; every mutation delegates to the village writer.
const Construction = preload("res://world/tribe/village_construction.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
const Style = preload("res://ui/progression_style.gd")
var controller: Node
var _title: Label
var _details: Label
var _notice: Label
var _progress: ProgressBar
var _pause: Button
var _assign: Button
var _cancel: Button
var _keep: Button
var _project: Dictionary = {}
var _confirming: bool = false
var _result: String = ""

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title = Style.label("", 17, Style.SOCIAL)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 20
	add_child(_progress)
	_details = Style.label("", 15, Style.MUTED)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_details)
	var actions := HFlowContainer.new()
	add_child(actions)
	_pause = Style.button("")
	_pause.name = "PauseConstruction"
	actions.add_child(_pause)
	_pause.pressed.connect(func() -> void: _command("resume" if Construction.state(controller.village().project) == "paused" else "pause"))
	_assign = Style.button("")
	_assign.name = "AssignConstruction"
	actions.add_child(_assign)
	_assign.pressed.connect(func() -> void: controller.issue_order("build"))
	_cancel = Style.button("")
	_cancel.name = "CancelConstruction"
	actions.add_child(_cancel)
	_cancel.pressed.connect(func() -> void:
		if _confirming: _command("cancel")
		else:
			_confirming = true
			refresh(controller.village()))
	_keep = Style.button("")
	_keep.name = "KeepConstruction"
	actions.add_child(_keep)
	_keep.pressed.connect(func() -> void:
		_confirming = false
		refresh(controller.village()))
	_notice = Style.label("", 15, Style.MUTED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_notice)

func _command(action: String) -> void:
	var result: Dictionary = controller.control_construction(action)
	_result = result.code
	_confirming = false
	refresh(controller.village())

func refresh(data: Dictionary) -> void:
	if not is_same(_project, data.project):
		_project = data.project
		_confirming = false
		_result = ""
	visible = not _project.is_empty()
	if not visible: return
	var view: Dictionary = Construction.summary(data)
	var recovering: bool = view.state == "recovering"
	var status: String = Text.text("CONSTRUCTION_STATE_" + str(view.state).to_upper())
	_title.text = Text.format_text("CONSTRUCTION_TITLE", {"name": Text.text(Presentation.PROJECTS.get(view.kind, "TRIBE_COMMAND")), "state": status})
	_progress.value = float(_project.progress) / float(Model.WORK.get(view.kind, 15.0)) * 100.0
	var returned: int = 0
	var required: int = 0
	var lines: PackedStringArray = [Text.format_text("CONSTRUCTION_WORKERS", {"count": view.workers, "blocked": view.blocked})]
	for kind: String in view.materials:
		var row: Dictionary = view.materials[kind].merged({"resource": Presentation.resource_title(kind)})
		lines.append(Text.format_text("CONSTRUCTION_RETURN_ROW" if recovering else "CONSTRUCTION_MATERIAL_ROW", row))
		returned += int(row.returned)
		required += int(row.required)
	if recovering: _progress.value = 100.0 * returned / maxi(1, required)
	_details.text = "\n".join(lines)
	var unavailable: bool = not controller.is_active()
	_pause.text = Text.text("CONSTRUCTION_RESUME" if view.state == "paused" else "CONSTRUCTION_PAUSE")
	_pause.disabled = unavailable or recovering
	_assign.text = Text.text("CONSTRUCTION_ASSIGN")
	_assign.disabled = unavailable or controller.selected.is_empty()
	_cancel.text = Text.text("CONSTRUCTION_CONFIRM_CANCEL" if _confirming else "CONSTRUCTION_CANCEL")
	_cancel.disabled = unavailable or recovering
	_keep.text = Text.text("CONSTRUCTION_KEEP")
	_keep.visible = _confirming
	_keep.disabled = unavailable
	var code: String = "CONSTRUCTION_CONFIRM_HINT" if _confirming else _result
	if code.is_empty(): code = "CONSTRUCTION_RECOVERY_HINT" if recovering else "CONSTRUCTION_PAUSE_HINT"
	_notice.text = Text.text(code)
