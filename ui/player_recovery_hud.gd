extends CanvasLayer
const Style = preload("res://ui/frontend/menu_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Layout = preload("res://ui/hud_layout.gd")
var panel: PanelContainer
var heading: Label
var detail: Label
var hint: Label
var bar: ProgressBar

func _ready() -> void:
	layer = 70
	# Visibility follows menus even while the recovery clock is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.name = "RecoveryCard"
	panel.theme = Style.theme()
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	heading = Style.paragraph(box, "", 24)
	heading.add_theme_color_override("font_color", Style.ACCENT)
	detail = Style.paragraph(box, "", 18)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	box.add_child(bar)
	hint = Style.paragraph(box, "", 14)
	_ignore_mouse(panel)
	hide()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var recovery: Node = get_parent()
	var flow := get_node_or_null("/root/SessionFlow")
	visible = recovery.stage != "inactive" and not get_tree().paused and (flow == null or not flow.loading)
	if not visible: return
	var font_scale: float = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	heading.add_theme_font_size_override("font_size", roundi(24 * font_scale))
	detail.add_theme_font_size_override("font_size", roundi(18 * font_scale))
	hint.add_theme_font_size_override("font_size", roundi(14 * font_scale))
	var protected: bool = recovery.protected()
	heading.text = Text.text("RECOVERY_SAFE" if protected else "RECOVERY_TITLE")
	match recovery.stage:
		"countdown": detail.text = Text.format_text("RECOVERY_COUNTDOWN", {"seconds": ceili(recovery.remaining)})
		"preparing": detail.text = Text.text("RECOVERY_PREPARING")
		"blocked": detail.text = Text.text("RECOVERY_BLOCKED")
		"protected": detail.text = Text.format_text("RECOVERY_PROTECTION", {"seconds": ceili(recovery.remaining)})
	hint.text = Text.text("RECOVERY_ATTACK" if protected else "RECOVERY_KEEP")
	bar.visible = recovery.stage in ["countdown", "protected"]
	bar.value = 100.0 * recovery.remaining / maxf(recovery.PROTECTION_SECONDS if protected else recovery.player.respawn_delay, 0.01)
	var screen: Vector2 = Layout.screen_size(self)
	var width: float = minf(520.0, screen.x - 32.0)
	Layout.place(panel, Rect2(Vector2.ZERO, Vector2(width, 0)))
	var top: float = 28.0 if protected else maxf(16.0, (screen.y - panel.size.y) * 0.42)
	Layout.place(panel, Rect2(Vector2((screen.x - width) * 0.5, top), panel.size))

func _ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_mouse(child)
