extends SceneTree
const Progress = preload("res://core/onboarding_progress.gd")
const Advice = preload("res://ui/tutorial/tribal_context_guidance.gd")
const Source = preload("res://ui/tutorial/tribal_context_source.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Economy = Model.Economy
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Home = Model.Home
const Work = preload("res://world/tribe/village_work.gd")
class Host extends Node:
	signal order_resolved(order: StringName, receipt: String, accepted: bool)
	var selected: Array[String] = []
	var status := ""
	var placement := ""
	var building_preview: Node3D
	var navigation := preload("res://world/tribe/village_navigation.gd").new()
	var snapshot: Dictionary
	var enabled := true
	func village() -> Dictionary: return snapshot
	func is_active() -> bool: return enabled
var failures: Array[String] = []
var checks := 0
var progress := Progress.new()

func _initialize() -> void: call_deferred("_run")

func _context() -> Dictionary:
	var campaign := Campaign.new()
	campaign.reset("int30-guidance")
	var body: Dictionary = campaign.body_for_seed(15838, 1)
	var home: Dictionary = Home.create(body.id, campaign.data.player_species_id, Vector3.ZERO)
	var data: Dictionary = Model.create(home, campaign.data, {"position": [0, 0, 0]},
		{"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4]]})
	return {"active": true, "village": data, "selected": [data.members[0].id], "navigation_pending": false, "placement": "", "preview": {}}

func _step(step: String) -> void:
	progress.reset(true)
	for earlier: String in Progress.TRIBE_STEPS:
		if earlier == step: break
		progress.record_tribal(earlier, Progress.tribal_goal(earlier))

func _code(context: Dictionary, expected: String, message: String) -> Dictionary:
	var before := context.duplicate(true)
	var saved := progress.export_state()
	var view: Dictionary = Advice.resolve(progress, context)
	_expect(view.get("code") == expected, message + ": " + str(view))
	_expect(context == before and progress.export_state() == saved, "Advice mutated input: " + message)
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		var copy: Dictionary = Advice.render(view)
		_expect(not str(copy).contains("TG_") and not str(copy).contains("GUIDE_") and not str(copy).contains("{count}"), "Untranslated advice: " + message + " / " + locale)
	return view

func _run() -> void:
	preload("res://tests/int30_tribal_guidance_support.gd").install_copy()
	var context := _context()
	_step("tribe_camera")
	_code(context, "camera", "Camera source step")
	_step("tribe_single")
	_code(context, "single", "Single selection source step")
	_step("tribe_group")
	_code(context, "group", "Group selection source step")
	_step("tribe_order")
	context.selected = []
	_code(context, "selection", "Missing selection")
	context.selected = [context.village.members[0].id, "removed-resident"]
	_code(context, "stale_selection", "Removed selection")
	context.selected = [context.village.members[0].id]
	context.navigation_pending = true
	_code(context, "paths", "Pending navigation")
	context.navigation_pending = false
	context.village.members[0].blocked = true
	_code(context, "blocked", "Known blocked flag without invented obstacle")
	context.village.members[0].blocked = false
	_code(context, "gather", "Real order next step")
	context.rejection = {"reason": "Speichern fehlgeschlagen. Der bisherige Auftrag bleibt erhalten."}
	_code(context, "order_rejected", "Actual rejected receipt")
	context.erase("rejection")
	_step("tribe_delivery")
	context.village.members[0].order = "wood"
	_code(context, "gathering", "Gathering is not arrival")
	context.village.deposits.wood.remaining = 0
	_code(context, "assigned_source_empty", "The assigned source is actually empty")
	context.village.deposits.wood.remaining = 48
	context.village.deposits.wood.remaining -= 1
	context.village.members[0].cargo = "wood"
	var cargo: Dictionary = _code(context, "cargo", "Carried goods are not stored")
	context.selected = []
	_code(context, "cargo", "An existing delivery does not need a new selection")
	context.selected = [context.village.members[0].id]
	context.village.members[0].care_pen_id = "actual-animal-pen"
	_expect(Advice.resolve(progress, context).get("code") != "cargo", "Animal-care cargo was presented as warehouse delivery")
	context.village.members[0].care_pen_id = ""
	_expect(not progress.tribal_done("tribe_delivery") and context.village.stock.wood == 0, "Cargo credited as arrival")
	context.village.members[0].position = context.village.anchor.duplicate()
	var effects: Array = []
	Work.step(context.village, context.village.members[0], 0.1, 1.0, effects)
	_expect(context.village.stock.wood == 1 and effects.any(func(e: Dictionary) -> bool: return e.kind == "delivery"), "Real arrived work did not emit delivery")
	_expect(not progress.tribal_done("tribe_delivery"), "Pure advice recorded the real event itself")
	_step("tribe_supply")
	context.village.members[0].hunger = 75.0
	_code(context, "gather", "Empty pantry needs gathering")
	context.village.stock.food = 1
	_code(context, "feed", "Available food and need")
	context.village.members[0].hunger = 100.0
	context.village.members[0].hydration = 50.0
	_code(context, "source_required", "Water requires a built well")
	context.village.stock.water = 1
	_code(context, "drink", "Available water and need")
	context.village.members[0].hydration = 100.0
	_code(context, "satisfied", "No fake care while already supplied")
	_step("tribe_tool")
	var deficit: Dictionary = _code(context, "materials", "Actual missing stored materials")
	_expect(deficit.values.count == 2 and deficit.values.carried == 0, "Wrong material deficit")
	context.village.stock.wood = 3
	context.village.stock.stone = 2
	_code(context, "tool", "Real recipe ready")
	context.village.stock.wood = 2
	context.village.members[0].cargo = "wood"
	_code(context, "materials_in_transit", "Enough carried material needs arrival, not more gathering")
	context.village.members[0].cargo = ""
	context.village.stock.wood = 3
	context.village.tools = 1
	_step("tribe_place")
	context.placement = "quarry"
	_code(context, "materials", "Selected build uses its own recipe")
	context.placement = "tent"
	_code(context, "source_required", "Missing fibers require their real source first")
	context.placement = "quarry"
	context.village.stock.wood = 4
	_code(context, "place_target", "No current ground preview is not a valid site")
	context.preview = {"ok": false, "reason": "Ein ausgewählter Bewohner erreicht diesen Bauplatz nicht."}
	_code(context, "placement_rejected", "Live placement reason")
	context.preview = {"ok": true}
	_code(context, "place", "Valid preview remains unbuilt")
	context.placement = ""
	context.preview = {}
	_step("tribe_finish")
	context.village.project = Economy.station_project(context.village, "forester", [5, 0, 4])
	_code(context, "build_workers", "Unstaffed site")
	context.village.members[0].order = "forester"
	_code(context, "build_materials", "Reserved materials are not delivered")
	context.village.project.control = {"schema": 1, "state": "paused"}
	_code(context, "build_paused", "Paused construction")
	context.village.project.control.state = "recovering"
	_code(context, "build_recovering", "Return before rebuilding")
	context.village.project.erase("control")
	context.village.project.delivered_materials = Economy.COSTS.forester.duplicate()
	context.village.project.materials = {"wood": 0, "stone": 0}
	_code(context, "build_working", "Material arrival is not build completion")
	_step("tribe_profession")
	_code(context, "profession", "Profession source step")
	_step("tribe_workplace")
	_code(context, "no_workplace", "No invented workplace")
	context.village.economy.stations.forester = {"id": "real-workplace", "position": [5, 0, 4]}
	_code(context, "workplace", "Existing workplace")
	progress.skip_tribal()
	_expect(Advice.resolve(progress, context).is_empty(), "Skipped guide forced visible help")
	progress.import_state({"schema": 99, "future": ["preserve"]})
	var future := progress.export_state()
	_expect(Advice.resolve(progress, context).is_empty() and progress.export_state() == future, "Future progress changed")
	_step("tribe_order")
	context.active = false
	_expect(Advice.resolve(progress, context).is_empty(), "Inactive/paused controller showed actionable advice")
	context.active = true
	context.village.schema = 99
	_expect(Advice.resolve(progress, context).is_empty(), "Future village treated as known")
	_source_cases()
	for failure: String in failures: push_error(failure)
	print(JSON.stringify({"test": "int30_tribal_guidance", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _source_cases() -> void:
	var first := Host.new()
	first.snapshot = _context().village
	first.selected.append(first.snapshot.members[0].id)
	var second := Host.new()
	second.snapshot = first.snapshot.duplicate(true)
	second.snapshot.id = "other-village"
	var source := Source.new()
	source.bind(first)
	first.status = "Speichern fehlgeschlagen. Der bisherige Auftrag bleibt erhalten."
	first.order_resolved.emit(&"wood", "rejected", false)
	_expect(not source.read().rejection.is_empty(), "Rejected real receipt missing")
	var copy: Dictionary = source.read()
	copy.village.stock.wood = 999
	copy.selected.clear()
	_expect(first.snapshot.stock.wood == 0 and first.selected.size() == 1, "Snapshot leaked mutable host references")
	first.order_resolved.emit(&"wood", "accepted", true)
	_expect(source.read().rejection.is_empty(), "Successful command retained stale rejection")
	first.order_resolved.emit(&"wood", "rejected-again", false)
	first.snapshot.stock.wood = 1
	_expect(source.read().rejection.is_empty(), "Changed prerequisites retained an obsolete rejection")
	source.bind(second)
	_expect(source.read().rejection.is_empty() and not first.order_resolved.is_connected(source._order), "Load/rebind kept old listener/rejection")
	source.bind(null)
	_expect(source.read().is_empty() and not second.order_resolved.is_connected(source._order), "Unbind kept old listener")
	first.free()
	second.free()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
