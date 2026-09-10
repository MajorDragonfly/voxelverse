extends SceneTree
## Real shared journal previews; visual QA only, no alternative game UI.
const Feet = preload("res://creatures/catalog/creature_foot_catalog.gd")
const Preview = preload("res://ui/discovery/journal_preview.gd")


func _initialize() -> void: call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array = ["feet_pads", "feet_claws", "feet_hooves", "feet_webbed"]
	if args.size() > 1: ids = Array(args).slice(1)
	if ids.is_empty() or ids.size() > 4:
		push_error("Capture one to four foot IDs per sheet.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("081820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var column := VBoxContainer.new()
	column.position = Vector2(28, 20)
	column.size = Vector2(1224, 680)
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)
	var heading := Label.new()
	heading.text = "ARCH-24  ·  Gemeinsame Fußfamilie / Revision 1"
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	for unlocked: bool in [true, false]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		for id: String in ids:
			var part: Dictionary = Feet.get_profile(id)
			if part.is_empty():
				push_error("Unknown foot ID: " + id)
				quit(1)
				return
			var card := VBoxContainer.new()
			card.custom_minimum_size = Vector2(297, 270)
			row.add_child(card)
			var preview := Preview.new()
			card.add_child(preview)
			preview.custom_minimum_size = Vector2(297, 225)
			preview.show_part(part.id, unlocked)
			var label := Label.new()
			label.text = part.name + ("" if unlocked else " · Gesperrt")
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 20)
			card.add_child(label)
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_cmdline_user_args()[0]
	var error: Error = root.get_texture().get_image().save_png(output)
	print("FOOT_FAMILY_CAPTURE_PASSED" if error == OK else "FOOT_FAMILY_CAPTURE_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if error == OK else 1)
