extends CanvasLayer
## A disposable launcher for an ordinary, independently saved spherical campaign.
## Home placement and the explicit phase confirmation remain owned by gameplay.
const Style = preload("res://ui/frontend/menu_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const SEED: int = 15838
const PREPARATION_TIMEOUT_MS: int = 60000
var _flow: Node
var _scene: Node3D
var _player: Node
var _player_mode: int = Node.PROCESS_MODE_INHERIT
var _campaign_id: String = ""
var _started: int = 0
var _preparing: bool = false
var _released: bool = false
var _home_created: bool = false
var _error: bool = false
var _detail: Label


static func start(flow: Node) -> bool:
	var scene: Node = flow.get_tree().current_scene
	if flow.loading or scene == null or scene.scene_file_path != flow.TITLE_SCENE or flow.has_node("TribalPlaytestLauncher"):
		return false
	var launcher := new()
	launcher.name = "TribalPlaytestLauncher"
	launcher._flow = flow
	flow.add_child(launcher)
	launcher._begin()
	return true


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_flow.world_started.connect(_world_started, CONNECT_ONE_SHOT)
	_flow.menu_error.connect(_loading_failed)


func _begin() -> void:
	# new_game creates a random slot ID. No original save is selected or copied.
	await _flow.new_game(Text.text("TRIBAL_TEST_SAVE_NAME"), SEED)
	_campaign_id = str(get_node("/root/GameState").campaign.data.id)


func _world_started() -> void:
	_scene = get_tree().current_scene as Node3D
	if _scene == null or _scene.scene_file_path != _flow.SPHERE_SCENE:
		queue_free()
		return
	_player = _scene.player
	_player_mode = _player.process_mode
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_preparing = true
	_started = Time.get_ticks_msec()
	_build_overlay()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_overlay() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.085, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.theme = Style.theme()
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	shade.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	Style.paragraph(column, "TRIBAL_TEST_ENTRY", 30)
	_detail = Style.paragraph(column, "TRIBAL_TEST_LOADING", 22)
	Style.button(column, "TRIBAL_TEST_CANCEL_SETUP", _cancel, "CancelTribalPlaytest").grab_focus()


func _process(_delta: float) -> void:
	if not _preparing or _released: return
	if not is_instance_valid(_scene) or get_tree().current_scene != _scene or str(get_node("/root/GameState").campaign.data.id) != _campaign_id:
		_release()
		return
	if _error or get_tree().paused: return
	if Time.get_ticks_msec() - _started > PREPARATION_TIMEOUT_MS:
		_error = true
		_detail.text = "TRIBAL_TEST_SETUP_FAILED"
		return
	var home: Node = _scene.get_node("Nest/HomeGroup")
	var tribe: Node = _scene.get_node("Nest/Tribe")
	if not home.can_use_panel() or not is_instance_valid(tribe.player): return
	# Wait for collision across the complete village footprint before placing home.
	for x: int in [-12, 0, 12]:
		for z: int in [-12, 0, 12]:
			if not Space.ground_ready(self, Space.offset(self, _player.global_position, Vector3(x, 0, z))): return
	if not _home_created:
		var result: Dictionary = home.establish_home()
		if not result.ok:
			_error = true
			_detail.text = Text.text("TRIBAL_TEST_SETUP_FAILED") + "\n\n" + Text.text(str(result.message))
			return
		_home_created = true
		return # Publish the new companions' collision before navigation queries.
	if home.actors.size() != 2 or not tribe.blockers().is_empty(): return
	_restore_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The standard dialog owns the pause, token, save transaction and final click.
	# A rejected footprint is explained there; no phase flag or points are forged.
	if tribe.panel.open_confirmation():
		_release()
	else:
		_error = true
		_detail.text = "TRIBAL_TEST_SETUP_FAILED"


func _input(event: InputEvent) -> void:
	if not _preparing or _released: return
	# Leave Tab/Enter to this overlay's button while blocking gameplay shortcuts.
	if event is InputEventKey and event.physical_keycode not in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER]:
		if event.is_action_pressed("ui_cancel"): _cancel()
		get_viewport().set_input_as_handled()


func _cancel() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_release()


func _restore_player() -> void:
	if is_instance_valid(_player):
		_player.process_mode = _player_mode
		_player = null


func _release() -> void:
	_released = true
	_restore_player()
	hide()
	queue_free()


func _loading_failed(_message: String) -> void:
	_release()


func _exit_tree() -> void:
	_restore_player()
