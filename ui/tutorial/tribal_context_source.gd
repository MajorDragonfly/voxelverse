extends RefCounted
## Read-only projection. Receipts are UI diagnostics, never completion evidence.
var _controller: WeakRef
var _rejection: Dictionary = {}

func bind(controller: Node) -> void:
	var previous: Node = _controller.get_ref() if _controller != null else null
	if previous == controller: return
	if is_instance_valid(previous) and previous.order_resolved.is_connected(_order):
		previous.order_resolved.disconnect(_order)
	_controller = weakref(controller) if is_instance_valid(controller) else null
	_rejection.clear()
	if is_instance_valid(controller): controller.order_resolved.connect(_order)

func _order(order: StringName, _receipt: String, accepted: bool) -> void:
	_rejection.clear()
	var controller: Node = _controller.get_ref() if _controller != null else null
	if not accepted and is_instance_valid(controller):
		_rejection = {"order": str(order), "reason": str(controller.status),
			"selection": controller.selected.duplicate(), "village_id": controller.village().get("id", ""),
			"prerequisites": _prerequisites(controller.village())}

func _prerequisites(data: Dictionary) -> Array:
	return [hash(data.get("stock", {})), data.get("tools"), data.get("project", {}).get("kind", ""),
		hash(data.get("project", {}).get("control", {}))]

func read(allow_paused: bool = false) -> Dictionary:
	var controller: Node = _controller.get_ref() if _controller != null else null
	if not is_instance_valid(controller): return {}
	var data: Dictionary = controller.village()
	# The active host owns validation/migration. Do not migrate a UI read.
	if data.is_empty(): return {}
	var rejection: Dictionary = {}
	if _rejection.get("selection") == controller.selected and _rejection.get("village_id") == data.get("id") and _rejection.get("reason") == controller.status and _rejection.get("prerequisites") == _prerequisites(data):
		rejection = _rejection.duplicate(true)
	var preview: Dictionary = {}
	if not str(controller.placement).is_empty() and is_instance_valid(controller.building_preview):
		preview = controller.building_preview.result.duplicate(true)
	var active: bool = controller.is_active()
	if allow_paused and controller.is_inside_tree() and controller.get_tree().paused:
		var flow: Node = controller.get_node_or_null("/root/SessionFlow")
		active = bool(controller.get("_active")) and flow != null and not flow.loading
	return {"active": active, "village": data.duplicate(true),
		"selected": controller.selected.duplicate(), "navigation_pending": controller.navigation.pending,
		"placement": str(controller.placement), "preview": preview, "rejection": rejection}
