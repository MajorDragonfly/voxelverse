extends Node3D
## Bounded, collision-free warehouse props. Stock and construction own all goods.
const Inventory = preload("res://world/tribe/village_inventory_view.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const MAX_UNITS: int = 12
const OFFSETS := {"wood": Vector3(-1.8, 0, -0.8), "stone": Vector3(1.8, 0, -0.8),
	"fiber": Vector3(-1.95, 0, 0.45), "water": Vector3(1.95, 0, 0.45),
	"food": Vector3(-1.25, 0, 1.6), "milk": Vector3(1.25, 0, 1.6), "eggs": Vector3(0, 0, 2.0)}
var snapshot: Dictionary = {}
var lots: Dictionary = {}
var changes: int = 0
var hovered_resource: String = ""
var _stages: Dictionary = {}
var _place: Variant
var _identity: String = ""
var _controller: Node
var _caption: Label3D
var _pointer := Vector2.ZERO
var _hover_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_controller = get_tree().get_first_node_in_group(&"tribe_controller")
	_pointer = get_viewport().get_mouse_position()
	var ordinary := _material(Color.WHITE)
	var reserved := _material(Color("ffd16b"))
	reserved.vertex_color_use_as_albedo = false
	for kind: String in Inventory.Economy.Resources.IDS:
		var lot := Node3D.new()
		lot.name = "Stored_" + kind
		add_child(lot)
		var mesh: ArrayMesh = _unit_mesh(kind)
		var groups: Dictionary = {"root": lot}
		for group: String in ["stored", "reserved"]:
			var visual := MultiMeshInstance3D.new()
			visual.name = group
			visual.multimesh = MultiMesh.new()
			visual.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			visual.multimesh.mesh = mesh
			visual.multimesh.instance_count = MAX_UNITS
			visual.multimesh.visible_instance_count = 0
			visual.material_override = ordinary if group == "stored" else reserved
			for index in range(MAX_UNITS): visual.multimesh.set_instance_transform(index, _unit_transform(index))
			lot.add_child(visual)
			groups[group] = visual
		# A shallow pallet remains when empty; nothing resembles a full stock.
		var base := MeshInstance3D.new()
		base.mesh = _mesh([[Vector3(0, 0.025, 0), Vector3(1.05, 0.05, 0.85), Color("6e5238")],
			[Vector3(0, 0.06, 0.42), Vector3(1.05, 0.07, 0.05), Color("b9854d")]])
		base.material_override = ordinary
		lot.add_child(base)
		lots[kind] = groups
	_caption = Label3D.new()
	_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption.font_size = 24
	_caption.pixel_size = 0.014
	_caption.modulate = Color("efe4cb")
	_caption.outline_size = 5
	add_child(_caption)
	_caption.hide()

static func stage(amount: int, capacity: int) -> int:
	return clampi(ceili(float(amount) * MAX_UNITS / maxi(1, capacity)), 0, MAX_UNITS)

func sync(data: Dictionary) -> void:
	snapshot = Inventory.rows(data)
	if _identity != str(data.id) or _place != data.anchor:
		_identity = str(data.id)
		_place = data.anchor.duplicate(true)
		position = Vector3.ZERO if Space.adapter(self) != null else Inventory.Economy.Home.vector(data.anchor)
		for kind: String in lots:
			var lot: Node3D = lots[kind].root
			lot.position = OFFSETS[kind]
			var hit: Dictionary = Space.floor_hit(self, lot.global_position, 2.0, 4.0)
			if not hit.is_empty(): lot.global_position = hit.position
			lot.global_basis = Space.frame(self, lot.global_position)
	for kind: String in snapshot:
		var row: Dictionary = snapshot[kind]
		var next := Vector2i(stage(row.stored, row.capacity), stage(row.reserved, row.capacity))
		if _stages.get(kind, Vector2i(-1, -1)) == next: continue
		_stages[kind] = next
		var free_mesh: MultiMesh = lots[kind].stored.multimesh
		var reserved_mesh: MultiMesh = lots[kind].reserved.multimesh
		free_mesh.visible_instance_count = next.x
		reserved_mesh.visible_instance_count = next.y
		for index in range(next.y): reserved_mesh.set_instance_transform(index, _unit_transform(next.x + index))
		changes += 1
	if not hovered_resource.is_empty(): _show_detail(hovered_resource)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse: _pointer = event.position

func _process(delta: float) -> void:
	if not is_instance_valid(_controller) or not _controller.is_active() or not _controller.placement.is_empty() or get_viewport().gui_get_hovered_control() != null:
		_hide_detail()
		return
	_hover_time -= delta
	if _hover_time > 0: return
	_hover_time = 0.1
	var hit: Dictionary = _controller.ground_hit(_pointer)
	if hit.is_empty():
		_hide_detail()
		return
	var closest: String = ""
	var distance: float = 0.7
	for kind: String in lots:
		var local: Vector3 = lots[kind].root.to_local(hit.position)
		var planar: float = Vector2(local.x, local.z).length()
		if absf(local.y) < 1.0 and planar < distance:
			closest = kind
			distance = planar
	if closest.is_empty(): _hide_detail()
	else: _show_detail(closest)

func _show_detail(kind: String) -> void:
	if not snapshot.has(kind): return
	hovered_resource = kind
	_caption.text = Inventory.detail(snapshot[kind])
	var lot: Node3D = lots[kind].root
	# Keep the lower text edge above the permanent village/source captions.
	var half_text_height: float = (_caption.text.count("\n") + 1) * _caption.font_size * _caption.pixel_size * 0.65
	_caption.global_position = lot.global_position + lot.global_basis.y * (4.3 + half_text_height)
	_caption.show()

func _hide_detail() -> void:
	hovered_resource = ""
	_caption.hide()

func _unit_transform(index: int) -> Transform3D:
	var layer: int = index / 3
	var column: int = index % 3
	return Transform3D(Basis.IDENTITY, Vector3((column - 1) * 0.31, 0.07 + layer * 0.23, 0))

func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = tint
	material.roughness = 0.95
	return material

func _unit_mesh(kind: String) -> ArrayMesh:
	var color := Color(Inventory.Economy.Resources.definition(kind).color)
	var parts: Array = []
	match kind:
		"wood":
			parts = [[Vector3(0, 0.10, 0), Vector3(0.26, 0.20, 0.72), color],
				[Vector3(0, 0.10, 0.365), Vector3(0.20, 0.14, 0.025), Color("d5b57d")]]
		"stone":
			parts = [[Vector3(0, 0.08, 0), Vector3(0.28, 0.16, 0.48), color],
				[Vector3(0.02, 0.18, -0.03), Vector3(0.20, 0.08, 0.32), color.lightened(0.08)]]
		"fiber":
			parts = [[Vector3(0, 0.08, 0), Vector3(0.22, 0.16, 0.58), color],
				[Vector3(0, 0.085, 0), Vector3(0.25, 0.18, 0.08), Color("795a38")]]
		"food":
			parts = [[Vector3(0, 0.09, 0), Vector3(0.22, 0.18, 0.42), color],
				[Vector3(0, 0.15, -0.23), Vector3(0.16, 0.06, 0.15), Color("78964b")]]
		"water", "milk":
			parts = [[Vector3(0, 0.09, 0), Vector3(0.27, 0.18, 0.32), Color("8e633f")],
				[Vector3(0, 0.18, 0), Vector3(0.19, 0.07, 0.24), color],
				[Vector3(0, 0.06, 0), Vector3(0.29, 0.04, 0.34), Color("514738")]]
		"eggs":
			parts = [[Vector3(0, 0.02, 0), Vector3(0.28, 0.04, 0.34), Color("8e633f")],
				[Vector3(0, 0.10, 0), Vector3(0.20, 0.12, 0.24), color],
				[Vector3(0, 0.18, 0), Vector3(0.12, 0.05, 0.16), color.lightened(0.08)]]
	return _mesh(parts)

func _mesh(parts: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[1]
		var arrays: Array = box.get_mesh_arrays()
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			surface.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
			surface.set_color(part[2])
			surface.add_vertex(arrays[Mesh.ARRAY_VERTEX][index] + part[0])
	return surface.commit()
