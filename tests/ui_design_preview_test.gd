extends SceneTree
## Shared theme isolation and a real read-only building preview lifecycle.
const Design = preload("res://ui/design/design_system.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
const Preview = preload("res://ui/blueprints/building_design_preview.gd")
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	await process_frame
	var first: Theme = Design.theme()
	var second: Theme = Design.theme()
	first.default_font_size = 41
	(first.get_stylebox("normal", "Button") as StyleBoxFlat).bg_color = Color.MAGENTA
	_expect(second.default_font_size == 18, "One UI changed another UI's font size")
	_expect(second.get_stylebox("normal", "Button").bg_color == Design.PANEL, "One UI changed another UI's button style")
	var icon: Texture2D = Symbols.texture("search")
	_expect(icon.get_width() <= 32 and icon.get_height() <= 32, "Raw search icon expands input fields")
	_expect(Symbols.texture("search") == icon, "Repeated icon allocates another texture")
	var known := {}
	for id: String in ["wood", "stone", "food", "water", "book", "map", "creature", "tribe", "settings", "tools"]:
		var value: Texture2D = Symbols.texture(id)
		_expect(not known.has(value), "Unrelated gameplay meanings share an unknown fallback: " + id)
		known[value] = true
	var source: Dictionary = Blueprint.create_default()
	var before: String = JSON.stringify(source)
	var preview := Preview.new()
	preview.size = Vector2(420, 240)
	root.add_child(preview)
	_expect(preview.show_design(source), "Valid design cannot be previewed")
	await process_frame
	_expect(JSON.stringify(source) == before, "Preview changed the source design")
	_expect(preview._visual != null and preview._visual.get_combined_aabb().size.length() > 0.1, "Preview contains no actual building geometry")
	_expect(not preview._visual.build_collision and preview._visual.get_node_or_null("AssemblyCollision") == null, "Preview created gameplay collisions")
	var old: Node = preview._visual
	var next: Dictionary = Blueprint.create_default()
	next.name = "Second preview"
	_expect(preview.show_design(next), "Second valid selection failed")
	await process_frame
	_expect(not is_instance_valid(old), "Previous selection survives as a second model")
	preview.hide()
	await process_frame
	_expect(preview._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden preview keeps rendering")
	preview.show()
	_expect(preview._viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED, "Reopened preview never requests rendering")
	await process_frame
	var future: Dictionary = source.duplicate(true)
	future.building.schema = Blueprint.SAVE_VERSION + 1
	var future_before: String = JSON.stringify(future)
	_expect(not preview.show_design(future), "Preview accepted a future building schema")
	_expect(JSON.stringify(future) == future_before, "Preview rewrote a future design")
	_expect(preview._visual == null, "Rejected preview retains misleading old geometry")
	preview.queue_free()
	await process_frame
	await process_frame
	print("UI_DESIGN_PREVIEW: ", JSON.stringify({"checks": checks, "failures": failures}))
	if failures.is_empty(): print("UI_DESIGN_PREVIEW_PASSED")
	else:
		for message: String in failures: push_error(message)
	await load("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
