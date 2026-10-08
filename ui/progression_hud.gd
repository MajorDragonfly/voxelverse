extends Node

const SkillTree = preload("res://ui/behavior_skill_tree.gd")
const Style = preload("res://ui/progression_style.gd")
const Design = preload("res://ui/design/design_system.gd")
const GameSymbols = preload("res://ui/design/game_symbols.gd")
const Keys = preload("res://core/input_preferences.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Journal = preload("res://ui/discovery/discovery_journal.gd")
const JournalText = preload("res://ui/discovery/journal_presentation.gd")

var _player: Node3D
var _hud: CanvasLayer
var _progress_label: Label
var _notification_label: Label
var _notification_timer: float = 0.0
var _shortcut_buttons: Dictionary = {}
var _skill_tree: CanvasLayer
var _discovery_journal: CanvasLayer
var _notification_receipt: Dictionary = {}


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
	var dock := PanelContainer.new()
	dock.name = "ProgressionDock"
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_stylebox_override("panel", Design.box(Design.PANEL, Design.EDGE, 8))
	_hud.add_child(dock)
	var column := Style.column(dock, 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_label = Label.new()
	_progress_label.name = "ProgressionSummary"
	_progress_label.offset_left = 20.0
	_progress_label.offset_top = 136.0
	_progress_label.offset_right = 320.0
	_progress_label.offset_bottom = 176.0
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Design.MUTED)
	column.add_child(_progress_label)
	# Keep discovery and skill counts at the book entry instead of occupying the
	# exploration view on every frame. The book still opens with one click.
	_progress_label.hide()

	_notification_label = Label.new()
	_notification_label.name = "DiscoveryNotification"
	_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification_label.offset_left = -320.0
	_notification_label.offset_top = 104.0
	_notification_label.offset_right = 320.0
	_notification_label.offset_bottom = 150.0
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification_label.offset_bottom = 205.0
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_label.add_theme_font_size_override("font_size", 17)
	_notification_label.add_theme_color_override("font_color", Design.TEXT)
	_notification_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_notification_label.add_theme_constant_override("shadow_offset_x", 2)
	_notification_label.add_theme_constant_override("shadow_offset_y", 2)
	_notification_label.visible = false
	_hud.add_child(_notification_label)
	_discovery_journal = Journal.new()
	_discovery_journal.name = "DiscoveryJournal"
	_discovery_journal.player = _player
	add_child(_discovery_journal)
	var minimap := preload("res://ui/minimap/minimap_hud.gd").new()
	minimap.player = _player
	add_child(minimap)
	_skill_tree = SkillTree.new()
	_skill_tree.player = _player
	_skill_tree.journal = _discovery_journal
	add_child(_skill_tree)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 6)
	column.add_child(shortcuts)
	for entry: Array in [["HUD_DEVELOPMENT", "OpenPlayerProgression", _skill_tree.open_panel, "development"],
		["HUD_JOURNAL", "OpenDiscoveryJournal", _discovery_journal.open_journal, "journal"]]:
		var button := Style.button(Keys.hint(entry[0]))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_shortcut_buttons[entry[0]] = button
		button.name = entry[1]
		button.custom_minimum_size = Vector2(0, 36)
		GameSymbols.apply(button, entry[3], 20)
		button.add_theme_constant_override("h_separation", 6)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.get_theme_stylebox(state).set_content_margin_all(6)
		button.pressed.connect(entry[2])
		shortcuts.add_child(button)
	get_node("/root/DisplaySettings").input_preferences.bindings_changed.connect(_refresh_summary)
	get_node("/root/LocaleManager").language_changed.connect(func(_locale: String) -> void:
		_refresh_summary()
		if _notification_label.visible: _render_receipt())

	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null:
		if progression.has_signal("part_unlocked"):
			progression.connect("part_unlocked", Callable(self, "_on_part_unlocked"))
		if progression.has_signal("species_discovered"):
			progression.connect("species_discovered", Callable(self, "_on_species_discovered"))
		if progression.has_signal("discovery_points_changed"):
			progression.connect("discovery_points_changed", Callable(self, "_on_points_changed"))
		progression.behavior_changed.connect(_refresh_summary)
		progression.behavior_rewarded.connect(_on_behavior_rewarded)
	get_node("/root/GameState").phase_changed.connect(func(_phase: int) -> void: _refresh_summary())
	_refresh_summary()


func _refresh_summary() -> void:
	for key: String in _shortcut_buttons: _shortcut_buttons[key].text = Keys.hint(key)
	if _progress_label == null:
		return
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null:
		_progress_label.text = ""
		return
	_progress_label.text = Text.format_text("HUD_PROGRESS", {
		"species": progression.get_discovered_species_count(),
		"parts": progression.get_unlocked_count(), "points": progression.discovery_points})
	var wallet: Dictionary = progression.get_behavior_wallet(0)
	_progress_label.text += "\n" + Text.format_text("HUD_BEHAVIOR", {
		"social": wallet.available.social, "aggression": wallet.available.aggression})
	for key: String in _shortcut_buttons:
		_shortcut_buttons[key].tooltip_text = _progress_label.text



func _on_part_unlocked(part_id: String, _reason: String) -> void:
	_show_receipt({"kind": "part", "part": part_id})
	_refresh_summary()


func _on_species_discovered(species_key: String, species_name: String) -> void:
	var receipt := {"kind": "species", "species": species_name, "part": ""}
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null:
		var species: Dictionary = progression.get("discovered_species")
		var part_id: String = str(species.get(species_key, {}).get("unlocked_part", ""))
		if not part_id.is_empty():
			receipt.part = part_id
	_show_receipt(receipt)
	_refresh_summary()


func _on_points_changed(_points: int) -> void:
	_refresh_summary()


func _on_behavior_rewarded(receipt: Dictionary) -> void:
	_show_receipt({"kind": "behavior", "outcome": str(receipt.get("outcome", "")), "amount": int(receipt.get("amount", 0)), "track": str(receipt.get("track", ""))})
	_refresh_summary()


func _show_notification(text: String) -> void:
	if _notification_label == null:
		return
	_notification_label.text = text
	_notification_receipt.clear()
	_notification_label.visible = true
	_notification_timer = 4.0

func _show_receipt(receipt: Dictionary) -> void:
	if _notification_label == null: return
	_notification_receipt = receipt.duplicate(true)
	_notification_label.visible = true
	_notification_timer = 4.0
	_render_receipt()

func _render_receipt() -> void:
	if _notification_receipt.is_empty(): return
	var receipt := _notification_receipt
	match receipt.kind:
		"part":
			_notification_label.text = Text.format_text("HUD_RECEIPT_PART", {"part": JournalText.part(receipt.part)})
		"species":
			_notification_label.text = Text.format_text("HUD_RECEIPT_SPECIES", {"species": receipt.species})
			if not receipt.part.is_empty(): _notification_label.text += Text.format_text("HUD_RECEIPT_SCAN_PART", {"part": JournalText.part(receipt.part)})
			_notification_label.text += Text.format_text("HUD_RECEIPT_JOURNAL", {"key": Keys.binding_label("open_journal")})
		"behavior":
			var outcome: String = {"befriended": "HUD_RECEIPT_FRIEND", "helped": "HUD_RECEIPT_HELP", "won": "HUD_RECEIPT_WIN"}.get(receipt.outcome, "HUD_RECEIPT_DONE")
			_notification_label.text = Text.format_text("HUD_RECEIPT_BEHAVIOR", {"outcome": Text.text(outcome), "amount": receipt.amount, "track": Text.text("Sozialpunkte" if receipt.track == "social" else "Aggressionspunkte")})
