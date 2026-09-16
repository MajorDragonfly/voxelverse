extends Node3D
## Visual-only placement aid. Never owns collision, stock, IDs or save data.
const Space = preload("res://world/surface/gameplay_space.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const Shelters = preload("res://world/tribe/village_shelters.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
const CHECK_INTERVAL: float = 0.15
var controller: Node
var result: Dictionary = {}
var check_count: int = 0
var _kind: String = ""
var _model: Node3D
var _caption: Label3D
var _material: StandardMaterial3D
var _elapsed: float = CHECK_INTERVAL
var _checked_point := Vector3.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_caption = Label3D.new()
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.font_size = 22
	_caption.pixel_size = 0.013
	_caption.position = Vector3(0, 4.0, 0)
	_caption.outline_size = 5
	add_child(_caption)
	hide()

func _process(delta: float) -> void:
	_elapsed += delta
	update_screen(get_viewport().get_mouse_position())

func update_screen(point: Vector2) -> void:
	if not controller.is_active() or controller.placement.is_empty() or not get_viewport().get_visible_rect().has_point(point):
		clear_preview()
		return
	# Menus/minimap consume their clicks; do not show a build ghost behind them.
	if get_viewport().gui_get_hovered_control() != null:
		clear_preview()
		return
	var hit: Dictionary = controller.ground_hit(point)
	if hit.is_empty():
		clear_preview()
		return
	var target: Vector3 = hit.position
	var snapped: Vector3 = controller.navigation.snap(target)
	if result.is_empty() or _kind != controller.placement or snapped != _checked_point or _elapsed >= CHECK_INTERVAL:
		show_at(target)
	else:
		show()

func clear_preview() -> void:
	hide()
	result.clear()
	_checked_point = Vector3.INF
	_elapsed = CHECK_INTERVAL

func show_at(target: Vector3) -> void:
	if not controller.is_active() or controller.placement.is_empty() or not target.is_finite():
		clear_preview()
		return
	var kind: String = controller.placement
	result = controller.placement_check(kind, target)
	check_count += 1
	_checked_point = controller.navigation.snap(target)
	_elapsed = 0.0
	if _kind != kind:
		_build(kind)
	global_position = result.position
	global_basis = Space.frame(self, global_position)
	_material.albedo_color = Color(0.25, 0.95, 0.60, 0.42) if result.ok else Color(1.0, 0.30, 0.25, 0.48)
	var state: String = Text.text("TRIBE_PREVIEW_FREE") if result.ok else Text.text("TRIBE_PREVIEW_BLOCKED")
	var title: String = Text.text(Presentation.PROJECTS.get(kind, "TRIBE_COMMAND"))
	_caption.text = title + " · " + state + "\n" + (Text.text("TRIBE_PREVIEW_CONFIRM") if result.ok else Presentation.legacy_status(result.reason))
	_caption.modulate = Color("9dffd2") if result.ok else Color("ffb4a3")
	show()

func _build(kind: String) -> void:
	if is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	_kind = kind
	_model = Node3D.new()
	add_child(_model)
	if kind in Housing.KINDS:
		var source := Shelters.new()
		source.add_model(_model, kind, false)
		source.free()
	elif kind in Housing.ANIMAL_SITES:
		if kind == "laying_site":
			_box(Vector3(0, 0.08, -0.3), Vector3(1.3, 0.16, 1.3))
			for side in [-1, 1]:
				_box(Vector3(side * 0.65, 0.16, -0.3), Vector3(0.12, 0.25, 1.3))
		for side in [-1, 1]:
			_box(Vector3(side, 0.5, -1), Vector3(0.16, 1, 0.16))
			_box(Vector3(side * 0.85, 0.2, 0.5), Vector3(0.45, 0.4, 1.1))
	elif kind == "well":
		for side in [-1, 1]:
			_box(Vector3(side * 0.7, 0.4, 0), Vector3(0.2, 0.8, 1.5))
		_box(Vector3(0, 0.2, 0), Vector3(1.2, 0.15, 1.2))
	else:
		_box(Vector3(0, 0.08, 0), Vector3(2.1, 0.16, 2.1))
		for i in range(5):
			var offset := Vector3((i % 3 - 1) * 0.35, 0.22 + (i / 3) * 0.22, (i % 2) * 0.4)
			_box(offset, Vector3(0.26, 0.26, 1.2) if kind == "forester" else Vector3(0.4, 0.4, 0.4))
	# Footprint and entry remain readable from the overhead camera.
	for side in [-1, 1]:
		_box(Vector3(side * 1.3, 0.10, 0), Vector3(0.06, 0.06, 2.6))
		_box(Vector3(0, 0.10, side * 1.3), Vector3(2.6, 0.06, 0.06))
	if kind in Housing.BUILDS:
		_box(Vector3(0, 0.10, 1.8), Vector3(1.3, 0.06, 1.0))
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _box(offset: Vector3, size_value: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.position = offset
	_model.add_child(visual)
