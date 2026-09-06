extends Node

var _player: Node3D
var _hud: CanvasLayer
var _progress_label: Label
var _notification_label: Label
var _notification_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as Node3D
	call_deferred("_install")


func _process(delta: float) -> void:
	if _notification_label == null or not _notification_label.visible:
		return
	_notification_timer -= delta
	if _notification_timer <= 0.0:
		_notification_label.visible = false


func _install() -> void:
	if _player == null:
		return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		return
	_progress_label = Label.new()
	_progress_label.name = "ProgressionSummary"
	_progress_label.offset_left = 20.0
	_progress_label.offset_top = 164.0
	_progress_label.offset_right = 430.0
	_progress_label.offset_bottom = 194.0
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.75, 0.92))
	_hud.add_child(_progress_label)

	_notification_label = Label.new()
	_notification_label.name = "DiscoveryNotification"
	_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification_label.offset_left = -320.0
	_notification_label.offset_top = 104.0
	_notification_label.offset_right = 320.0
	_notification_label.offset_bottom = 150.0
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_label.add_theme_font_size_override("font_size", 17)
	_notification_label.add_theme_color_override("font_color", Color(0.80, 0.94, 0.88, 1.0))
	_notification_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_notification_label.add_theme_constant_override("shadow_offset_x", 2)
	_notification_label.add_theme_constant_override("shadow_offset_y", 2)
	_notification_label.visible = false
	_hud.add_child(_notification_label)

	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null:
		if progression.has_signal("part_unlocked"):
			progression.part_unlocked.connect(_on_part_unlocked)
		if progression.has_signal("species_discovered"):
			progression.species_discovered.connect(_on_species_discovered)
		if progression.has_signal("discovery_points_changed"):
			progression.discovery_points_changed.connect(_on_points_changed)
	_refresh_summary()


func _refresh_summary() -> void:
	if _progress_label == null:
		return
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null:
		_progress_label.text = ""
		return
	_progress_label.text = "Discoveries %d · Parts %d · Insight %d" % [
		int(progression.call("get_discovered_species_count")),
		int(progression.call("get_unlocked_count")),
		int(progression.get("discovery_points")),
	]


func _on_part_unlocked(part_id: String, _reason: String) -> void:
	var PartLibrary = load("res://creatures/editor/creature_part_library.gd")
	var definition: Dictionary = PartLibrary.get_part(part_id)
	var display_name: String = str(definition.get("name", part_id))
	_show_notification("NEW CREATURE PART · %s" % display_name)
	_refresh_summary()


func _on_species_discovered(_species_key: String, species_name: String) -> void:
	_show_notification("SPECIES DISCOVERED · %s" % species_name)
	_refresh_summary()


func _on_points_changed(_points: int) -> void:
	_refresh_summary()


func _show_notification(text: String) -> void:
	if _notification_label == null:
		return
	_notification_label.text = text
	_notification_label.visible = true
	_notification_timer = 4.0
