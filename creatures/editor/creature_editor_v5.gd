extends "res://creatures/editor/creature_editor_v4.gd"

const BaseBlueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const BasePartLibraryV5 = preload(
	"res://creatures/editor/creature_part_library.gd"
)
const SpineProfileV5 = preload(
	"res://creatures/editor/creature_spine_profile.gd"
)
const BlueprintV5 = preload(
	"res://creatures/editor/creature_blueprint_v5.gd"
)
const Anatomy = preload(
	"res://creatures/editor/creature_anatomy.gd"
)
const EvolutionGenerator = preload(
	"res://creatures/editor/creature_evolution_generator.gd"
)

const MAIN_SCENE_PATH: String = "res://main/main.tscn"

var _v5_panel: PanelContainer
var _seed_edit: LineEdit
var _archetype_option: OptionButton
var _generation_label: Label
var _v5_status_label: Label


func _ready() -> void:
	super._ready()

	if _title_label != null:
		_title_label.text = "VOXELVERSE CREATURE LAB V5"

	if _help_label != null:
		_help_label.text += (
			"\n\nV5 EVOLUTION LAB:\n"
			+ "Seeded generation is deterministic.\n"
			+ "Mutate creates a related descendant.\n"
			+ "Attached parts now follow body edits.\n"
			+ "F2 in the world returns to this lab."
		)

	_build_v5_tools()

	var saved_blueprint: Dictionary = BlueprintV5.load_best_available()

	if not saved_blueprint.is_empty():
		blueprint = saved_blueprint

	BlueprintV5.normalize(blueprint)
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)
	_sync_v5_controls_from_blueprint()
	_refresh_all()
	_set_v5_status(
		"V5 ready: generate, mutate or edit the current creature."
	)

	print(
		"Creature Lab V5 ready. Runtime bridge and deterministic "
		+ "evolution generation enabled."
	)


func _build_v5_tools() -> void:
	if _ui_root == null:
		return

	_v5_panel = PanelContainer.new()
	_v5_panel.name = "EvolutionLabPanel"
	_v5_panel.anchor_left = 0.0
	_v5_panel.anchor_top = 0.0
	_v5_panel.anchor_right = 1.0
	_v5_panel.anchor_bottom = 0.0
	_v5_panel.offset_left = 320.0
	_v5_panel.offset_top = 58.0
	_v5_panel.offset_right = -330.0
	_v5_panel.offset_bottom = 204.0
	_ui_root.add_child(_v5_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 6)
	_v5_panel.add_child(content)

	var generator_row := HBoxContainer.new()
	generator_row.alignment = BoxContainer.ALIGNMENT_CENTER
	generator_row.add_theme_constant_override("separation", 8)
	content.add_child(generator_row)

	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	generator_row.add_child(seed_label)

	_seed_edit = LineEdit.new()
	_seed_edit.name = "SeedEdit"
	_seed_edit.custom_minimum_size = Vector2(150.0, 0.0)
	_seed_edit.placeholder_text = "e.g. 314159"
	_seed_edit.text_submitted.connect(_on_seed_submitted)
	generator_row.add_child(_seed_edit)

	var archetype_label := Label.new()
	archetype_label.text = "Archetype"
	archetype_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	generator_row.add_child(archetype_label)

	_archetype_option = OptionButton.new()
	_archetype_option.name = "ArchetypeOption"
	_archetype_option.custom_minimum_size = Vector2(132.0, 0.0)

	for archetype in EvolutionGenerator.ARCHETYPES:
		var item_index: int = _archetype_option.item_count
		_archetype_option.add_item(archetype.capitalize())
		_archetype_option.set_item_metadata(item_index, archetype)

	generator_row.add_child(_archetype_option)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	content.add_child(action_row)

	_add_v5_button(action_row, "Generate", _generate_from_controls)
	_add_v5_button(action_row, "Mutate", _mutate_current)
	_add_v5_button(action_row, "Rebind Parts", _rebind_parts)
	_add_v5_button(action_row, "Play Creature", _play_test_placeholder)

	_generation_label = Label.new()
	_generation_label.name = "GenerationLabel"
	_generation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_generation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_generation_label)

	_v5_status_label = Label.new()
	_v5_status_label.name = "StatusLabel"
	_v5_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_v5_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_v5_status_label)


func _add_v5_button(
	parent: Control,
	button_text: String,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(112.0, 34.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func _on_seed_submitted(_submitted_text: String) -> void:
	_generate_from_controls()


func _generate_from_controls() -> void:
	var seed_value: int = _get_seed_from_controls()
	var archetype: String = _get_selected_archetype()
	blueprint = EvolutionGenerator.generate(seed_value, archetype)
	selected_part_index = -1
	selected_body_segment = -1
	current_category = BasePartLibraryV5.CATEGORY_BODY
	_sync_v5_controls_from_blueprint()
	_refresh_all()
	_set_v5_status(
		"Generated deterministic creature from seed %d." % seed_value
	)


func _mutate_current() -> void:
	var mutation_seed: int = EvolutionGenerator.create_seed()
	blueprint = EvolutionGenerator.mutate(blueprint, mutation_seed, 0.24)
	selected_part_index = -1
	selected_body_segment = -1
	current_category = BasePartLibraryV5.CATEGORY_BODY
	_sync_v5_controls_from_blueprint()
	_refresh_all()
	_set_v5_status(
		"Created descendant mutation with seed %d." % mutation_seed
	)


func _rebind_parts() -> void:
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)
	_refresh_preview()
	_refresh_stats_panel()
	_set_v5_status(
		"All attached parts were rebound to the current body and spine."
	)


func _get_seed_from_controls() -> int:
	if _seed_edit == null:
		return EvolutionGenerator.create_seed()

	var seed_text: String = _seed_edit.text.strip_edges()

	if seed_text.is_valid_int():
		return int(seed_text)

	var generated_seed: int = EvolutionGenerator.create_seed()
	_seed_edit.text = str(generated_seed)
	return generated_seed


func _get_selected_archetype() -> String:
	if _archetype_option == null or _archetype_option.item_count <= 0:
		return "random"

	return str(_archetype_option.get_selected_metadata())


func _sync_v5_controls_from_blueprint() -> void:
	if blueprint.is_empty():
		return

	var generation: Dictionary = blueprint.get("generation", {})
	var seed_value: int = int(generation.get("seed", 0))
	var archetype: String = str(generation.get("archetype", "custom"))

	if _seed_edit != null:
		_seed_edit.text = str(seed_value)

	if _archetype_option != null:
		for item_index in range(_archetype_option.item_count):
			if str(
				_archetype_option.get_item_metadata(item_index)
			) == archetype:
				_archetype_option.select(item_index)
				break

	_update_generation_label()


func _update_generation_label() -> void:
	if _generation_label == null:
		return

	var generation: Dictionary = blueprint.get("generation", {})
	_generation_label.text = (
		"Seed %d · Generation %d · Parent %d · Archetype %s · "
		+ "Complexity %d/%d"
	) % [
		int(generation.get("seed", 0)),
		int(generation.get("generation", 0)),
		int(generation.get("parent_seed", 0)),
		str(generation.get("archetype", "custom")).capitalize(),
		BaseBlueprint.calculate_complexity(blueprint),
		BaseBlueprint.COMPLEXITY_LIMIT,
	]


func _set_v5_status(status_text: String) -> void:
	if _v5_status_label != null:
		_v5_status_label.text = status_text


func _refresh_stats_panel() -> void:
	super._refresh_stats_panel()
	_update_generation_label()


func _apply_spine_delta(
	width_delta: float,
	height_delta: float,
	curve_delta: float,
	length_delta: float
) -> void:
	super._apply_spine_delta(
		width_delta,
		height_delta,
		curve_delta,
		length_delta
	)
	Anatomy.rebind_all_parts(blueprint)
	_refresh_preview()
	_refresh_stats_panel()


func _apply_body_delta(
	position_delta: Vector3,
	scale_delta: float
) -> void:
	super._apply_body_delta(position_delta, scale_delta)
	Anatomy.rebind_all_parts(blueprint)
	_refresh_preview()
	_refresh_stats_panel()


func _apply_transform_delta(
	position_delta: Vector3,
	scale_delta: float,
	rotation_y_delta: float
) -> void:
	super._apply_transform_delta(
		position_delta,
		scale_delta,
		rotation_y_delta
	)

	if (
		selected_part_index >= 0
		and current_category != BasePartLibraryV5.CATEGORY_BODY
		and current_category != BasePartLibraryV5.CATEGORY_PAINT
		and position_delta != Vector3.ZERO
	):
		Anatomy.capture_manual_offset(blueprint, selected_part_index)


func _drag_selected_part_from_mouse(event: InputEventMouseMotion) -> void:
	super._drag_selected_part_from_mouse(event)

	if selected_part_index >= 0:
		Anatomy.capture_manual_offset(blueprint, selected_part_index)


func _on_part_button_pressed(part_id: String) -> void:
	var category_before: String = current_category
	var count_before: int = BaseBlueprint.get_part_count(blueprint)
	super._on_part_button_pressed(part_id)

	if category_before == BasePartLibraryV5.CATEGORY_BODY:
		Anatomy.rebind_all_parts(blueprint)
	elif (
		category_before != BasePartLibraryV5.CATEGORY_PAINT
		and BaseBlueprint.get_part_count(blueprint) > count_before
		and selected_part_index >= 0
	):
		Anatomy.ensure_anchors(blueprint, false)
		Anatomy.reset_part_anchor(blueprint, selected_part_index)

	_refresh_preview()
	_refresh_stats_panel()


func _reset_selected_transform() -> void:
	var selected_part_before: int = selected_part_index
	var category_before: String = current_category
	super._reset_selected_transform()

	if (
		selected_part_before >= 0
		and category_before != BasePartLibraryV5.CATEGORY_BODY
		and category_before != BasePartLibraryV5.CATEGORY_PAINT
	):
		Anatomy.reset_part_anchor(blueprint, selected_part_before)
		_refresh_preview()
		_refresh_stats_panel()


func _save_blueprint() -> void:
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)
	super._save_blueprint()

	var save_error: Error = BlueprintV5.save_to_file(blueprint)

	if save_error != OK:
		push_error("Creature V5 save failed: %s" % save_error)
		_set_v5_status("V5 save failed: %s" % save_error)
		return

	_set_v5_status(
		"Saved self-contained V5 blueprint for editor and runtime."
	)
	print("Creature V5 saved: ", BlueprintV5.SAVE_PATH)


func _load_blueprint() -> void:
	var loaded_blueprint: Dictionary = BlueprintV5.load_best_available()

	if loaded_blueprint.is_empty():
		_set_v5_status("No V5 or legacy creature save was found.")
		return

	blueprint = loaded_blueprint
	selected_part_index = -1
	selected_body_segment = -1
	current_category = BasePartLibraryV5.CATEGORY_BODY
	Anatomy.ensure_anchors(blueprint, true)
	Anatomy.rebind_all_parts(blueprint)
	_sync_v5_controls_from_blueprint()
	_refresh_all()
	_set_v5_status("Loaded creature blueprint.")


func _reset_blueprint() -> void:
	blueprint = BaseBlueprint.create_default()
	selected_part_index = -1
	selected_body_segment = -1
	_is_dragging_spine_segment = false
	current_category = BasePartLibraryV5.CATEGORY_BODY
	SpineProfileV5.reset_all(blueprint)
	BlueprintV5.normalize(blueprint)
	Anatomy.reset_all_anchors(blueprint)
	_sync_v5_controls_from_blueprint()
	_refresh_all()
	_set_v5_status("Created a clean custom creature blueprint.")


func _randomize_blueprint() -> void:
	var seed_value: int = EvolutionGenerator.create_seed()

	if _seed_edit != null:
		_seed_edit.text = str(seed_value)

	_generate_from_controls()


func _play_test_placeholder() -> void:
	_save_blueprint()

	var change_error: Error = get_tree().change_scene_to_file(
		MAIN_SCENE_PATH
	)

	if change_error != OK:
		push_error("Could not start creature play test: %s" % change_error)
		_set_v5_status("Could not start play test: %s" % change_error)
