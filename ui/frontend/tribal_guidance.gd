extends RefCounted
## Observes successful commands and actual arrived-work effects; never drives work.
const Progress = preload("res://core/onboarding_progress.gd")
const Copy = preload("res://ui/frontend/guidance_text.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
var guide: CanvasLayer
var tribe: Node

func _init(owner: CanvasLayer) -> void:
	guide = owner

func bind(controller: Node) -> void:
	if controller == tribe: return
	if is_instance_valid(tribe):
		tribe.guidance_action.disconnect(record)
		tribe.order_resolved.disconnect(_order)
		tribe.community_event.disconnect(_work)
		if is_instance_valid(tribe.panel): tribe.panel.set_guidance("", "")
	tribe = controller
	if not is_instance_valid(tribe): return
	tribe.guidance_action.connect(record)
	tribe.order_resolved.connect(_order)
	tribe.community_event.connect(_work)

func active() -> bool:
	return guide._live_session() and is_instance_valid(tribe) and tribe.is_active() and not guide.get_tree().paused

func record(step: String, amount: float = 1.0) -> void:
	if not active(): return
	var progress: RefCounted = guide._saves.guidance
	var before: int = progress.tribal_completed()
	if progress.record_tribal(step, amount) and progress.tribal_completed() > before:
		guide._saves.schedule_autosave(2.0)

func _order(order: StringName, _receipt: String, accepted: bool) -> void:
	if not accepted: return
	if order in Economy.RESOURCES + ["supply", "provision"]: record("tribe_order")
	if order == "workplace": record("tribe_workplace")
	if order in Economy.STATIONS.keys() + Housing.BUILDS: record("tribe_place")

func _work(kind: StringName, details: Dictionary) -> void:
	if not active() or details.get("tribe_id") != tribe.village().id: return
	match kind:
		&"delivery": record("tribe_delivery")
		&"meal", &"drink": record("tribe_supply")
		&"construction":
			if details.get("kind") == "tool": record("tribe_tool")
			elif details.get("kind") in Economy.STATIONS.keys() + Housing.BUILDS: record("tribe_finish")

func refresh() -> void:
	if not is_instance_valid(tribe): return
	var step: String = guide._saves.guidance.tribal_step() if active() else ""
	if not step.is_empty():
		# A saved tool cannot be crafted twice, and a full village may have no
		# free building slots. Recover these actual, durable prerequisites when
		# an existing tribe opts in; never grant goods or infer a delivery.
		var data: Dictionary = tribe.village()
		if int(data.tools) > 0: record("tribe_tool")
		if not data.housing.homes.is_empty() or not data.economy.stations.is_empty() or not data.husbandry.pens.is_empty():
			record("tribe_place")
			record("tribe_finish")
		step = guide._saves.guidance.tribal_step()
	var caption: String = ""
	var detail: String = ""
	if not step.is_empty():
		caption = Text.format_text("GUIDE_TRIBAL_CARD", {"done": guide._saves.guidance.tribal_completed(), "total": Progress.TRIBE_STEPS.size(), "hint": Copy.hint(step)})
		detail = Copy.hint(step, true)
	tribe.panel.set_guidance(caption, detail)
