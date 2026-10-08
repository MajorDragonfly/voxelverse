extends Node3D
## Thin host adapter: existing save transaction, navigation and VillageWork own
## all effects. The marker is a read model in local rendering coordinates.
const Model = preload("res://world/tribe/resource_area_model.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Text = preload("res://core/localization/ui_text.gd")
var controller: Node
var selected_id: String = ""
var drawing: bool = false
var editing_id: String = ""
var _center: Variant
var _radius: float = 1.0
var _marker: MeshInstance3D
var _generation: int = -1
var _graph_id: int = 0
var _route_cache: Dictionary = {}
var _signature: String = ""
var _visible_before: bool = false
# Runtime-only cost counters; never saved and never an economic clock.
var dispatch_calls: int = 0
var dispatch_total_usec: int = 0
var dispatch_max_usec: int = 0
var _source_nodes: Dictionary = {}
var _source_candidates: Array[Dictionary] = []
var _source_proposals: Array[Dictionary] = []
var _source_village: String = ""
var _source_cursor: int = 0
var _source_clock: float = 0.0
var _source_failed: bool = false
const Source = Model.LocalSources
const ADMISSION_STEPS: int = 2

func _ready() -> void:
	_marker = MeshInstance3D.new()
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)

func begin(identity: String = "") -> void:
	if not controller.is_active(): return
	_reset_drawing(identity)
	controller.placement = ""
	controller.status = Text.text("GATHER_DRAW_HINT")
	controller.panel.refresh()

func _reset_drawing(identity: String) -> void:
	editing_id = identity
	drawing = true
	_center = null
	_radius = 1.0
	_signature = ""

func cancel() -> void:
	drawing = false
	editing_id = ""
	_center = null
	_signature = ""

func handle_input(event: InputEvent) -> bool:
	if not drawing: return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		return true
	if not controller.is_active(): return false
	if event is InputEventMouseMotion and _center != null:
		_update_edge(event.position)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit: Dictionary = controller.ground_hit(event.position)
			if not hit.is_empty(): _center = Space.encode(controller, hit.position)
		else:
			if _center == null: return true
			_update_edge(event.position)
			if Model.bounds_valid(controller.village(), _center, _radius):
				var old: Dictionary = Model.get_area(controller.village(), editing_id)
				if command({"action": "create" if old.is_empty() else "update", "id": editing_id,
					"center": _center, "radius": _radius, "kind": old.get("kind", "wood"), "target": old.get("target", 16)}): cancel()
			else: controller.status = Text.text("GATHER_INVALID_BOUNDS")
		return true
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT

func _update_edge(screen: Vector2) -> void:
	var hit: Dictionary = controller.ground_hit(screen)
	if hit.is_empty():
		_radius = INF
	else: _radius = Model.Home.distance(_center, Space.encode(controller, hit.position))

func command(request: Dictionary) -> bool:
	if not controller.is_active(): return false
	var data: Dictionary = controller.village()
	var before: Dictionary = data.duplicate(true)
	var identity: String = str(request.get("id", selected_id))
	var ok: bool = false
	match str(request.get("action", "")):
		"create":
			identity = Model.create(data, request.center, request.radius, request.kind, request.target)
			ok = not identity.is_empty()
		"configure":
			var unavailable: Array = []
			for member: Dictionary in data.members:
				if controller.SiteTransport.bound(controller.body(), member.id): unavailable.append(member.id)
			ok = Model.update(data, identity, request.center, request.radius, request.kind, request.target) and Model.set_workers(data, identity, int(request.count), unavailable)
		"update": ok = Model.update(data, identity, request.center, request.radius, request.kind, request.target)
		"delete": ok = Model.remove(data, identity)
		"workers":
			var unavailable: Array = []
			for member: Dictionary in data.members:
				if controller.SiteTransport.bound(controller.body(), member.id): unavailable.append(member.id)
			ok = Model.set_workers(data, identity, int(request.count), unavailable)
		"assign":
			var members: Array = []
			for id: String in controller.selected:
				if controller.SiteTransport.bound(controller.body(), id): return false
				members.append(controller.member_record(id))
			ok = not members.is_empty() and Model.assign(data, identity, members)
	if not ok:
		if data != before: controller.replace_village(before)
		controller.status = Text.text("GATHER_COMMAND_REJECTED")
		controller.panel.refresh()
		return false
	if not controller._save_economy(before): return false
	selected_id = identity if request.action != "delete" else ""
	_signature = ""
	controller.panel._resource_area.select_area(selected_id)
	controller.panel.refresh()
	return true

func reachable(member: Dictionary, source: Dictionary) -> bool:
	var navigation: RefCounted = controller.navigation
	if not navigation.is_ready(): return false
	if _generation != navigation.generation or _graph_id != navigation.graph.get_instance_id():
		_generation = navigation.generation
		_graph_id = navigation.graph.get_instance_id()
		_route_cache.clear()
	var from: Vector3 = Space.resolve(controller, member.position)
	var first: int = navigation.graph.get_closest_point(from)
	var key: String = "%s:%d" % [source.id, first]
	if not _route_cache.has(key):
		# Finite cache; derived only from the currently verified graph.
		if _route_cache.size() >= 128: _route_cache.clear()
		var point: Vector3 = Space.resolve(controller, source.position)
		_route_cache[key] = not navigation.route(controller.anchor(), point).is_empty() and not navigation.route(from, point).is_empty()
	return bool(_route_cache[key])

func dispatch(member: Dictionary) -> void:
	if member.get("resource_area_id", "") == "" and member.get("resource_source_id", "") == "": return
	var started: int = Time.get_ticks_usec()
	Model.dispatch(controller.village(), member, reachable, not Economy.at_target(controller.village(), member, str(member.order)) if member.order in Model.KINDS else true)
	var cost: int = Time.get_ticks_usec() - started
	dispatch_calls += 1
	dispatch_total_usec += cost
	dispatch_max_usec = maxi(dispatch_max_usec, cost)

func area_at(screen: Vector2) -> String:
	if drawing or not controller.is_active(): return ""
	var hit: Dictionary = controller.ground_hit(screen)
	if hit.is_empty(): return ""
	var place: Variant = Space.encode(controller, hit.position)
	var best: String = ""
	var nearest: float = INF
	for area: Dictionary in Model.entries(controller.village()).values():
		var distance: float = Model.Home.distance(place, area.center)
		if Model.contains(area, place) and distance < nearest:
			nearest = distance
			best = area.id
	return best

func _process(_delta: float) -> void:
	var active: bool = controller._active and controller._body_id == controller._state.active_body_id
	_marker.visible = active
	if not active:
		for node: Node3D in _source_nodes.values(): node.hide()
		_source_village = ""
		if _visible_before: cancel()
		_visible_before = false
		return
	_visible_before = true
	_source_clock -= _delta
	if _source_clock <= 0.0:
		_source_clock = 0.25
		if controller.is_active(): _admit_sources()
		_sync_sources()
	var area: Dictionary = Model.get_area(controller.village(), selected_id)
	var center: Variant = _center if drawing else area.get("center")
	var radius: float = _radius if drawing else float(area.get("radius", 0.0))
	if center == null or not is_finite(radius):
		_marker.hide()
		return
	var valid: bool = Model.bounds_valid(controller.village(), center, radius)
	var origin: Vector3 = Space.resolve(controller, center)
	var stamp: String = str([origin, center, radius, valid, controller.navigation.generation])
	if stamp == _signature: return
	_signature = stamp
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.95, 0.7) if valid else Color(1.0, 0.3, 0.25)
	material.no_depth_test = false
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var up: Vector3 = Space.up(controller, origin)
	for i in range(64):
		for step: int in [i, i + 1]:
			var angle: float = TAU * float(step) / 64.0
			var place: Variant = Model.Home.offset_place(center, Vector3(cos(angle) * radius, 0, sin(angle) * radius))
			var point: Vector3 = Space.resolve(controller, place)
			var hit: Dictionary = controller.home._floor_hit(point)
			if not hit.is_empty(): point = hit.position
			mesh.surface_add_vertex(to_local(point + up * 0.10))
	mesh.surface_end()
	_marker.mesh = mesh

func _admit_sources() -> void:
	# Canonical admission follows the authoritative village lifecycle. UI-only
	# frames during a frozen handoff/read probe may still refresh loose props.
	if not controller.is_physics_processing(): return
	var data: Dictionary = controller.village()
	if not data.anchor is Dictionary or int(data.economy.schema) != 6: return
	# A pending graph is not evidence of an unreachable source. Defer admission
	# without advancing the finite candidate cursor until certification is ready.
	if controller.navigation.pending or not controller.navigation.is_ready(): return
	if _source_village != data.id:
		_source_village = data.id
		_source_candidates.clear()
		_source_proposals.clear()
		_source_cursor = 0
		_source_failed = false
		for dy in range(-4, 5):
			for dx in range(-4, 5): _source_candidates.append(Source.candidate(data.anchor, dx, dy))
	if data.economy.has(Source.FIELD) or _source_failed: return
	# Admission follows the fixed village, never camera visibility. The existing
	# graph and physical floor certify up to two candidates per 0.25-second tick.
	for step in range(ADMISSION_STEPS):
		if _source_cursor >= _source_candidates.size(): break
		var proposal: Dictionary = _source_candidates[_source_cursor].duplicate(true)
		_source_cursor += 1
		var point: Vector3 = Space.resolve(self, proposal.position)
		var hit: Dictionary = controller.home._floor_hit(point)
		if hit.is_empty(): continue
		proposal.position = Space.encode(self, hit.position)
		# Floor hits retain the exact procedural horizontal address. Do not move
		# a candidate to a nearby graph vertex and silently change its identity.
		proposal.position.u = _source_candidates[_source_cursor - 1].position.u
		proposal.position.v = _source_candidates[_source_cursor - 1].position.v
		if not Source.record_valid(data, proposal) or not Space.dry(self, hit.position) or not reachable(data.members[0], proposal): continue
		var occupied: bool = Model.Home.distance(proposal.position, data.anchor) < 3.5
		for site: Dictionary in controller._resource_sites():
			if not site.get("local", false) and Model.Home.distance(proposal.position, site.position) < 2.5: occupied = true
		for village_id: String in controller.Settlements.ids(controller.body()):
			var village: Dictionary = controller.Settlements.village(controller.body(), village_id)
			if village.id != data.id and Source.entries(village).has(proposal.id): occupied = true
		if not occupied and _source_proposals.size() < Source.MAX_SOURCES: _source_proposals.append(proposal)
	if _source_cursor < _source_candidates.size(): return
	var before: Dictionary = data.duplicate(true)
	Source.install(data)
	for proposal: Dictionary in _source_proposals:
		if not Source.admit(data, proposal):
			controller.replace_village(before)
			_source_failed = true
			return
	# Publish sources/props only after the ordinary shared save transaction.
	if not controller._save_economy(before): _source_failed = true

func source_workers(identity: String, change: int) -> bool:
	if not controller.is_active() or change not in [-1, 1]: return false
	var data: Dictionary = controller.village()
	var source: Dictionary = Source.get_source(data, identity)
	if source.is_empty(): return false
	var worker: Dictionary = {}
	for member: Dictionary in data.members:
		if controller.SiteTransport.bound(controller.body(), member.id) or not Model.eligible(member): continue
		var assigned: bool = member.get("resource_area_id", "") == "" and member.get("resource_source_id", "") == identity
		if (change < 0 and assigned) or (change > 0 and not assigned and member.cargo == "" and member.order in ["wait", "move"] and member.paused_order == ""):
			worker = member
			break
	if worker.is_empty(): return false
	var before: Dictionary = data.duplicate(true)
	Model.release(data, worker) # preserves held cargo and provenance
	if change > 0:
		worker.resource_source_id = identity
		worker.order = source.resource_id
		worker.stage = "return" if worker.cargo != "" else "outbound"
	return controller._save_economy(before)

func _sync_sources() -> void:
	var data: Dictionary = controller.village()
	var entries: Dictionary = Source.entries(data)
	for id: String in _source_nodes.keys():
		if not entries.has(id):
			_source_nodes[id].queue_free()
			_source_nodes.erase(id)
	for source: Dictionary in entries.values():
		if not _source_nodes.has(source.id):
			var visual := MeshInstance3D.new()
			var material := StandardMaterial3D.new()
			if source.resource_id == "wood":
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.12, 0.12, 0.95)
				visual.mesh = mesh
				material.albedo_color = Color("91613d")
			else:
				var mesh := SphereMesh.new()
				mesh.radius = 0.22
				mesh.height = 0.25
				mesh.radial_segments = 6
				mesh.rings = 3
				visual.mesh = mesh
				material.albedo_color = Color("454b63") if source.resource_id == "flint" else Color("a5aaac")
			visual.material_override = material
			visual.set_meta("resource_source_id", source.id)
			add_child(visual)
			_source_nodes[source.id] = visual
		var node: Node3D = _source_nodes[source.id]
		var point: Vector3 = Space.resolve(self, source.position)
		node.global_position = point + Space.up(self, point) * 0.10
		node.global_basis = Space.frame(self, point)
		Space.track(node, str(source.id) + ":loose-prop")
		node.visible = int(source.remaining) > 0
