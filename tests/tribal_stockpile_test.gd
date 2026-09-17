extends "tribal_age_test.gd"
## Real pickup/arrival/consumption plus bounded presentation-only stage fixtures.
const Inventory = preload("res://world/tribe/village_inventory_view.gd")
const Checks = preload("res://core/diagnostics/stockpile_checks.gd")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://tribal_stockpile_test.json"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	Engine.time_scale = 3.0
	state.start_world_with_seed(15838)
	await process_frame
	_build_fixture()
	tribe = scene.get_node("Nest/Tribe")
	await _frames(25)
	_expect(home.establish_home().ok, "Cannot establish stockpile fixture.")
	await _frames(15)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 600)
	if not tribe.is_active():
		_expect(false, "Tribe did not activate.")
		await _cleanup()
		await _finish()
		return
	tribe.select_member(str(tribe.village().members[1].id))
	_expect(tribe.issue_order("wood"), "Cannot order actual wood collection.")
	await _until(func() -> bool: return tribe.village().members[1].cargo == "wood", 900)
	_expect(tribe.village().members[1].cargo == "wood" and tribe.village().stock.wood == 0, "Pickup credited wood before arrival.")
	failures.append_array(await Checks.verify(tribe))
	_expect(Inventory.rows(tribe.village()).wood.carried == 1, "Carrier absent from inventory details.")
	await _until(func() -> bool: return tribe.village().stock.wood > 0, 900)
	_expect(tribe.village().stock.wood > 0, "Wood never arrived.")
	tribe.select_all()
	_expect(tribe.issue_order("wait"), "Cannot stop collection.")
	failures.append_array(await Checks.verify(tribe))
	# Obtain actual food before exercising consumption.
	tribe.select_member(str(tribe.village().members[1].id))
	_expect(tribe.issue_order("food"), "Cannot collect food for consumption.")
	await _until(func() -> bool: return tribe.village().stock.food >= 2, 1800)
	tribe.select_all()
	tribe.issue_order("wait")
	# Consumption must shrink the same view through the existing economy.
	var data: Dictionary = tribe.village()
	var food_before: int = data.stock.food
	data.members[1].hunger = 30.0
	tribe.select_member(str(data.members[1].id))
	_expect(food_before > 0 and tribe.issue_order("feed"), "Cannot use stored food.")
	await _until(func() -> bool: return tribe.village().stock.food < food_before, 900)
	_expect(tribe.village().stock.food < food_before, "Eating did not consume actual stock.")
	tribe.select_all()
	tribe.issue_order("wait")
	failures.append_array(await Checks.verify(tribe))
	_expect(saves.save_now() and saves.load_now(), "Stockpile Save/Load failed: " + saves.last_error)
	await _until(func() -> bool: return tribe.is_active() and not tribe.navigation.pending, 600)
	failures.append_array(await Checks.verify(tribe))
	tribe.set_process(false)
	tribe.set_physics_process(false)
	var piles: Node3D = tribe._visuals.stockpiles
	var initial: Dictionary = tribe.village().duplicate(true)
	var saved_bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var preview: Dictionary = initial.duplicate(true)
	preview.project.clear()
	for member: Dictionary in preview.members: member.cargo = ""
	var meshes: Dictionary = {}
	for kind: String in piles.lots:
		meshes[kind] = piles.lots[kind].stored.multimesh
		_expect(piles.lots[kind].stored.multimesh.mesh == piles.lots[kind].reserved.multimesh.mesh, "Reserved stock duplicates geometry.")
	_expect(piles.find_children("*", "CollisionObject3D", true, false).is_empty(), "Storage props introduce movement blockers.")
	tribe.panel.hide()
	tribe.camera.global_position = tribe.anchor() + Vector3(6, 8, 11)
	tribe.camera.look_at(tribe.anchor() + Vector3.UP * 0.4)
	for amount: int in [0, 1, 24, 48]:
		for kind: String in preview.stock: preview.stock[kind] = amount
		piles.sync(preview)
		await _frames(2)
		for kind: String in piles.lots:
			var expected: int = 0 if amount == 0 else (1 if amount == 1 else (6 if amount == 24 else 12))
			_expect(piles.lots[kind].stored.multimesh == meshes[kind] and meshes[kind].visible_instance_count == expected, "Incorrect stage or recreated pool: " + kind + "/" + str(amount))
		await _capture("stockpile-" + str(amount))
	for kind: String in preview.stock: preview.stock[kind] = 1
	piles.sync(preview)
	var changes: int = piles.changes
	for kind: String in preview.stock: preview.stock[kind] = 2
	piles.sync(preview)
	_expect(piles.changes == changes and piles.snapshot.wood.stored == 2, "Exact count rebuilt unchanged geometry.")
	piles.sync(initial)
	tribe.panel.show()
	tribe.panel.refresh()
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		tribe.panel.refresh()
		var tip: String = tribe.panel._stock.tooltip_text
		_expect(not tip.contains("TRIBE_STORAGE_") and tip.contains("/48"), "Storage tooltip is missing or untranslated.")
		for row: Dictionary in Inventory.rows(initial).values():
			_expect(tip.contains(row.resource), "Tooltip omitted a resource.")
	# A real cursor ray opens only the hovered lot; HUD and pause dismiss it.
	var motion := InputEventMouseMotion.new()
	motion.position = tribe.camera.unproject_position(piles.lots.wood.root.global_position)
	root.push_input(motion, true)
	await _frames(20)
	_expect(piles.hovered_resource == "wood" and piles._caption.visible, "Wood hover did not use the world pointer.")
	await _capture("stockpile-hover")
	motion.position = tribe.panel._stock.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames(20)
	_expect(piles.hovered_resource.is_empty(), "Storage hover leaked through HUD.")
	paused = true
	await process_frame
	_expect(not piles._caption.visible, "Storage hover persisted into pause.")
	paused = false
	_expect(tribe.village() == initial and FileAccess.get_file_as_string(saves.save_path) == saved_bytes, "Presentation changed persistent inventory.")
	Engine.time_scale = 1.0
	if failures.is_empty(): print("TRIBAL_STOCKPILE_PASSED")
	await _cleanup()
	await _finish()

func _capture(label: String) -> void:
	await super._capture(label)
	# Two bounded inline previews allow visual review when artifact extraction
	# is unavailable. Full-resolution evidence remains in the PNG artifact.
	if not capture_dir.is_empty() and label == "stockpile-48":
		var image: Image = Image.load_from_file(capture_dir.path_join(label + ".png"))
		image.resize(960, 600, Image.INTERPOLATE_LANCZOS)
		print("STOCKPILE_IMAGE:" + label + ":" + Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.8)))
