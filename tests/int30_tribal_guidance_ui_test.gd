extends "res://tests/int30_tribal_guidance_test.gd"
## Isolated rendered consumer fixture. No planet/performance acceptance claimed.
const Card = preload("res://ui/tutorial/tribal_guidance_card.gd")
class ObservedHost extends Host:
	signal guidance_action(action: String, amount: float)
	signal community_event(kind: StringName, details: Dictionary)
	var panel: Node
	func is_active() -> bool:
		return enabled and (not is_inside_tree() or not get_tree().paused)
class GuideShell extends CanvasLayer:
	var _saves: Node
	func _live_session() -> bool: return true
class PanelStub extends Node:
	func set_guidance(_caption: String, _detail: String) -> void: pass
var host: Node
var card: PanelContainer
var shell: CanvasLayer
var observer: RefCounted
var captures := ""
var stages: Array[Dictionary] = []
var translations: Node

func _run() -> void:
	preload("res://tests/int30_tribal_guidance_support.gd").install_copy()
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.session_managed = true
	saves.session_active = false
	saves.guidance.reset(true)
	progress = saves.guidance
	progress.select_tribal("tribe_work")
	translations = root.get_node("LocaleManager")
	translations._apply("de")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
	host = ObservedHost.new()
	host.snapshot = _context().village
	host.panel = PanelStub.new()
	host.add_child(host.panel)
	root.add_child(host)
	shell = GuideShell.new()
	shell._saves = saves
	root.add_child(shell)
	observer = preload("res://ui/frontend/tribal_guidance.gd").new(shell)
	observer.bind(host)
	var background := ColorRect.new()
	background.color = Color("0c1b22")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_child(background)
	card = Card.new()
	card.controller = host
	shell.add_child(card)
	_layout()
	await _show("selection", "01-no-selection-de")
	host.selected.append(host.snapshot.members[0].id)
	host.guidance_action.emit("tribe_single", 1.0)
	var member: Dictionary = host.snapshot.members[0]
	member.hunger = 75.0
	member.order = "wood"
	host.order_resolved.emit(&"wood", "fixture-order", true)
	_expect(progress.tribal_done("tribe_order") and not progress.tribal_done("tribe_delivery"), "Accepted receipt fabricated arrival")
	await _show("gathering", "02-gathering-de")
	member.blocked = true # Explicit blocked-state fixture, no particular obstacle.
	await _show("blocked", "03-blocked-state-de")
	member.blocked = false
	member.position = host.snapshot.deposits.wood.position.duplicate()
	var effects: Array = []
	Work.step(host.snapshot, member, 3.0, 1.0, effects)
	_expect(member.cargo == "wood" and not progress.tribal_done("tribe_delivery"), "Pickup completed the delivery exercise")
	await _show("cargo", "04-cargo-in-transit-de")
	member.position = host.snapshot.anchor.duplicate()
	effects.clear()
	Work.step(host.snapshot, member, 0.1, 1.0, effects)
	_emit_effects(effects)
	_expect(progress.tribal_done("tribe_delivery") and host.snapshot.stock.wood == 1, "Arrived-work observer did not record actual delivery")
	await _show("gather", "05-empty-pantry-de")
	progress.select_tribal("tribe_build")
	await _show("materials", "06-missing-materials-de")
	# Conserved fixture quantities for the finished-tool/paid-site presentation.
	for resource: String in ["wood", "stone"]:
		host.snapshot.deposits[resource].remaining -= 8
		host.snapshot.stock[resource] += 8
	member.order = "tool"
	for resource: String in Model.COSTS.tool: host.snapshot.stock[resource] -= Model.COSTS.tool[resource]
	host.snapshot.project = {"kind": "tool", "progress": 0.0}
	effects.clear()
	Work.step(host.snapshot, member, 10.0, 1.0, effects)
	_emit_effects(effects)
	_expect(progress.tribal_done("tribe_tool"), "Finished tool event was not observed")
	host.snapshot.project = Economy.station_project(host.snapshot, "forester", [5, 0, 4])
	for resource: String in Economy.COSTS.forester: host.snapshot.stock[resource] -= Economy.COSTS.forester[resource]
	member.order = "forester"
	host.order_resolved.emit(&"forester", "fixture-site", true)
	await _show("build_materials", "07-reserved-site-materials-de")
	_expect(Model.Construction.command(host.snapshot, "pause").ok, "Pure construction pause rejected")
	await _show("build_paused", "08-paused-construction-de")
	await _matrix()
	var tutorial := progress.export_state()
	var village: Dictionary = host.snapshot.duplicate(true)
	paused = true
	card.refresh()
	_expect(not card.visible and progress.export_state() == tutorial and host.snapshot == village, "Paused card mutated work/progress")
	paused = false
	host.enabled = false
	card.refresh()
	_expect(not card.visible, "Inactive fixture exposed the card")
	host.enabled = true
	progress.import_state({"schema": 99, "future": "keep"})
	card.refresh()
	_expect(not card.visible and progress.export_state() == {"schema": 99, "future": "keep"}, "Future progress altered by rendered UI")
	if not captures.is_empty():
		var file := FileAccess.open(captures.path_join("stages.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"fixture": "isolated UI and actual arrived-work effects", "stages": stages, "checks": checks, "failures": failures}, "\t"))
	observer.bind(null)
	card.queue_free()
	await process_frame
	_expect(not host.order_resolved.is_connected(card._source._order) if is_instance_valid(card) else true, "Freed card kept an observer")
	shell.queue_free()
	host.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print(JSON.stringify({"test": "int30_tribal_guidance_ui", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	if failures.is_empty(): print("INT30_TRIBAL_GUIDANCE_UI_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _emit_effects(effects: Array) -> void:
	for effect: Dictionary in effects:
		if effect.has("data"): host.community_event.emit(StringName(effect.kind), effect.data)

func _layout() -> void:
	var screen := root.get_visible_rect().size
	card.position = Vector2(24, 24)
	card.size = Vector2(minf(660, screen.x - 48), 0)

func _show(code: String, stage: String) -> void:
	card.refresh()
	_layout()
	await _frames(4)
	_expect(card.view.get("code") == code, stage + ": " + str(card.view))
	var tutorial := progress.export_state()
	var village: Dictionary = host.snapshot.duplicate(true)
	var rewards: Dictionary = root.get_node("ProgressionService").export_state()
	await _click(card._toggle)
	_expect(card._detail.visible, "Explain did not open: " + stage)
	await _click(card._toggle)
	_expect(not card._detail.visible and progress.export_state() == tutorial and host.snapshot == village, "Help clicks fabricated effects: " + stage)
	_expect(root.get_node("ProgressionService").export_state() == rewards, "Explanation click changed rewards/unlocks: " + stage)
	stages.append({"stage": stage, "code": card.view.get("code"), "step": progress.tribal_step(), "reason": card._reason.text, "next": card._next.text,
		"stock": host.snapshot.stock.duplicate(), "completed": progress.tribal_completed()})
	await _capture(stage)

func _matrix() -> void:
	var tutorial := progress.export_state()
	var village: Dictionary = host.snapshot.duplicate(true)
	for locale: String in ["de", "en"]:
		translations._apply(locale)
		for dimensions: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = dimensions
			for scaling: float in [1.0, 1.25, 1.5]:
				root.content_scale_factor = scaling
				card.refresh()
				_layout()
				await _frames(5)
				_expect(root.get_visible_rect().encloses(card.get_global_rect()), "Context card clipped: " + str([locale, dimensions, scaling]))
				_expect(not str([card._reason.text, card._next.text]).contains("TG_"), "Missing localized context text")
				await _click(card._toggle)
				await _click(card._toggle)
				if scaling == 1.5: await _capture("layout-%s-%d-150" % [locale, dimensions.x])
	_expect(progress.export_state() == tutorial and host.snapshot == village, "Language/size/input matrix mutated progress or work")

func _click(button: BaseButton) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _frames(3)

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _capture(stage: String) -> void:
	print("INT30_GUIDANCE_UI_STAGE: ", stage)
	if captures.is_empty(): return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png(captures.path_join(stage + ".png")) == OK, "Capture write failed: " + stage)
