extends "tribal_age_test.gd"
const Atomic = preload("res://core/persistence/atomic_json.gd")
const H = preload("res://world/tribe/village_husbandry.gd")
const Lab = preload("res://world/tribe/lab/husbandry_lab.gd")
var evidence: Dictionary = {}
var pen_id: String = ""
var lab: Node3D

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	Engine.time_scale = 3.0
	root.size = Vector2i(1280, 800)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_dir = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(capture_dir)
	lab = load("res://world/tribe/lab/husbandry_lab.tscn").instantiate()
	scene = lab
	root.add_child(scene)
	current_scene = scene
	await _until(func() -> bool: return lab.ready_for_entry, 200)
	tribe = lab.tribe
	home = lab.home
	player = lab.player
	if not lab.ready_for_entry:
		_expect(false, "Lab failed to initialize: " + lab.banner.text)
		await _cleanup()
		_finish()
		return
	if "--restart-check" in args:
		await _restart_check()
		return
	await _frames(20)
	await _click(tribe.panel.entry)
	await _click(tribe.panel.confirm)
	await _until(func() -> bool: return lab.ready_for_work and tribe.is_active() and not tribe.navigation.pending, 1200)
	_expect(lab.ready_for_work and tribe.is_active(), "Lab village entry failed: " + lab.banner.text + " / " + saves.last_error)
	if not tribe.is_active() or not lab.ready_for_work:
		await _cleanup()
		_finish()
		return
	tribe.select_all()
	tribe.panel._tabs.current_tab = 2
	await _frames(3)
	var original_source: Dictionary = JSON.parse_string(Atomic.stringify(lab.registry()))
	await _click(tribe.panel._buttons["pen"])
	_expect(tribe.placement == "pen", "Pen UI did not arm placement.")
	await _world_click(tribe.camera.unproject_position(Vector3(0, 100.06, 7)), MOUSE_BUTTON_RIGHT)
	_expect(tribe.village()["project"].get("kind") == "pen", "Pen placement failed: " + tribe.status)
	if tribe.village()["project"].is_empty():
		await _cleanup()
		_finish()
		return
	_expect(tribe.village()["stock"]["wood"] == 12 and tribe.village()["stock"]["fiber"] == 2, "Pen cost was not reserved once.")
	await _until(func() -> bool: return tribe.village()["members"].any(func(m: Dictionary) -> bool: return m["construction_id"] != "" and Model.Home.vector(m["position"]).distance_to(tribe.anchor()) > 3.2), 500)
	_expect(tribe.village()["members"].any(func(m: Dictionary) -> bool: return m["construction_id"] != ""), "No physical pen material transport.")
	tribe.issue_order("wait")
	await _saved_roundtrip("pen construction")
	tribe.select_all()
	tribe.issue_order("resume")
	await _until(func() -> bool: return not tribe.village()["husbandry"]["pens"].is_empty(), 1600)
	_expect(not tribe.village()["husbandry"]["pens"].is_empty(), "Pen did not complete: " + tribe.status)
	if tribe.village()["husbandry"]["pens"].is_empty():
		print(tribe.village()["members"])
		await _cleanup()
		_finish()
		return
	pen_id = tribe.village()["husbandry"]["pens"][0]["id"]
	await _until(func(): return not tribe.navigation.pending, 1200)
	_expect(Model.Housing.beds(tribe.village()) == 0 and tribe.actors.size() == 3, "Pen created housing or a new resident.")
	var before: Dictionary = tribe.village().duplicate(true)
	tribe.husbandry.source.registry = Callable()
	_expect(not tribe.husbandry.assign(pen_id, Lab.ANIMAL) and tribe.village() == before, "Missing D2 source accepted an animal.")
	tribe.husbandry.configure(lab.registry, lab.traits, lab.live_actor)
	for field: String in ["owner_faction_id", "species_id"]:
		var a: Dictionary = lab.registry()["animals"][Lab.ANIMAL]
		var old: String = a[field]
		a[field] = "foreign-faction" if field == "owner_faction_id" else tribe.village()["species_id"]
		_expect(not tribe.husbandry.assign(pen_id, Lab.ANIMAL) and tribe.village() == before, "Invalid source accepted: " + field)
		a[field] = old
	lab.animal.visible = false
	_expect(not tribe.husbandry.assign(pen_id, Lab.ANIMAL), "Unloaded/hidden animal accepted.")
	lab.animal.visible = true
	tribe.panel._tabs.current_tab = 2
	tribe.panel.refresh()
	await _frames(3)
	await _click(tribe.panel._bind_animal)
	_expect(_pen()["animal_id"] == Lab.ANIMAL, "UI animal assignment failed: " + tribe.status)
	if _pen()["animal_id"] != Lab.ANIMAL:
		await _cleanup()
		_finish()
		return
	tribe.select_member(tribe.village()["members"][0]["id"])
	_expect(tribe.assign_profession("keeper"), "Keeper assignment failed.")
	await _until(func() -> bool: return tribe.village()["members"][0]["care_pen_id"] != "" and Model.Home.vector(tribe.village()["members"][0]["position"]).distance_to(tribe.anchor()) > 3.2, 500)
	_expect(tribe.village()["members"][0]["care_pen_id"] == pen_id and float(_pen()["water"]) == 0, "Water credited before physical delivery.")
	tribe.issue_order("wait")
	await _saved_roundtrip("care cargo")
	tribe.select_member(tribe.village()["members"][0]["id"])
	_expect(tribe.village()["members"][0]["profession"] == "keeper" and tribe.village()["members"][0]["paused_order"] == "tend", "Keeper profession or paused order lost.")
	# If D2 disappears while cargo is in transit, it returns to shared storage.
	tribe.husbandry.source.registry = Callable()
	var returned: int = tribe.village()["husbandry"]["returned"]["water"]
	tribe.issue_order("resume")
	await _until(func() -> bool: return tribe.village()["members"][0]["care_pen_id"] == "", 500)
	_expect(tribe.village()["husbandry"]["returned"]["water"] == returned + 1 and float(_pen()["water"]) == 0, "Missing animal lost or duplicated in-flight water.")
	tribe.husbandry.configure(lab.registry, lab.traits, lab.live_actor)
	tribe.select_member(tribe.village()["members"][1]["id"])
	tribe.assign_profession("provider")
	tribe.select_member(tribe.village()["members"][2]["id"])
	tribe.assign_profession("milk_carrier")
	await _until(func() -> bool: return float(_record()["clock"]) > 4, 1800)
	_expect(float(_record()["clock"]) > 4 and tribe.village()["husbandry"]["delivered"]["water"] > 0 and tribe.village()["husbandry"]["delivered"]["food"] > 0, "Keeper did not physically supply production.")
	print("D3: pen built; care cargo stopped, reloaded, returned and resumed; canonical production started")
	# Presence, D1 revisions, ownership and D2 death suspend service without changing source.
	for mode: String in ["away", "follow", "dead", "foreign", "traits"]:
		var a: Dictionary = lab.registry()["animals"][Lab.ANIMAL]
		var saved_animal: Dictionary = a.duplicate(true)
		var saved_traits: Dictionary = lab.traits(Lab.SPECIES).duplicate(true)
		var position: Vector3 = lab.animal.position
		if mode == "away":
			lab.animal.position.x += 4
			a["position"] = Model.Home.vector_array(lab.animal.position)
		elif mode == "follow": a.merge({"order": "follow", "handler_id": tribe.village()["members"][0]["id"]}, true)
		elif mode == "dead": a.merge({"status": "dead", "health": 0.0}, true)
		elif mode == "foreign": a["owner_faction_id"] = "foreign-faction"
		elif mode == "traits": lab.traits(Lab.SPECIES)["milk_yield"] = 3.0
		var clock: float = _record()["clock"]
		await _frames(30)
		_expect(float(_record()["clock"]) == clock, "Invalid source advanced production: " + mode)
		lab.registry()["animals"][Lab.ANIMAL] = saved_animal
		tribe.body()["d3_lab_sources"]["traits"] = saved_traits
		lab.animal.position = position
	await _saved_roundtrip("partial milk cycle")
	# Fail the next complete production transaction. No inbox, counter or milk survives it.
	await _until(func() -> bool: return float(_record()["clock"]) > 298.0, 7500)
	_expect(float(_record()["clock"]) > 298.0 and _record()["cycles"] == 0, "First canonical 300-second cycle failed to approach completion.")
	var block: FileAccess = FileAccess.open("user://d3-blocked", FileAccess.WRITE)
	block.store_string("not a directory")
	block.close()
	saves.save_path = "user://d3-blocked/save.json"
	await _until(func() -> bool: return tribe.husbandry.retry > 0, 400)
	_expect(tribe.husbandry.retry > 0 and _record()["cycles"] == 0 and tribe.village()["economy"]["incoming"].is_empty() and tribe.village()["economy"]["milk_received"] == 0, "Failed save acknowledged or duplicated produced milk.")
	saves.save_path = Lab.SAVE
	await _until(func() -> bool: return tribe.village()["members"].any(func(m: Dictionary) -> bool: return m["cargo"] == "milk"), 800)
	_expect(tribe.village()["members"].any(func(m: Dictionary) -> bool: return m["cargo"] == "milk"), "Milk never travelled as real carrier cargo.")
	tribe.select_all()
	tribe.issue_order("wait")
	await _saved_roundtrip("milk cargo and receipt")
	tribe.select_all()
	tribe.issue_order("resume")
	await _until(func() -> bool: return int(tribe.village()["stock"]["milk"]) + int(tribe.village()["economy"]["milk_meals"]) == 2, 800)
	_expect(int(tribe.village()["stock"]["milk"]) + int(tribe.village()["economy"]["milk_meals"]) == 2, "Produced milk did not arrive exactly once.")
	_expect(JSON.parse_string(Atomic.stringify(lab.registry())) == original_source, "D3 changed D2 identity, ownership, health, orders or animal position.")
	# Freeze through a missing host for cold-start evidence; earned progress must survive.
	tribe.husbandry.source.registry = Callable()
	tribe.select_all()
	tribe.issue_order("wait")
	var receipt: Dictionary = tribe.village()["economy"]["receipts"][Lab.ANIMAL].duplicate(true)
	var prior: Dictionary = tribe.village().duplicate(true)
	_expect(tribe.receive_milk(receipt) and tribe.village() == prior, "Receipt retry duplicated milk.")
	_expect(saves.save_now(), "Final D3 snapshot did not save: " + saves.last_error)
	evidence = {"schema": tribe.village()["schema"], "animal_id": Lab.ANIMAL, "pen_id": pen_id, "cycles": _record()["cycles"], "milk_received": tribe.village()["economy"]["milk_received"], "stock": tribe.village()["stock"].duplicate(), "care": tribe.village()["husbandry"].duplicate(true)}
	var evidence_file := FileAccess.open("user://d3-village-lab/evidence.json", FileAccess.WRITE)
	evidence_file.store_string(JSON.stringify(evidence, "\t"))
	evidence_file.close()
	tribe.husbandry.configure(lab.registry, lab.traits, lab.live_actor)
	tribe.panel._tabs.current_tab = 2
	tribe.panel.refresh()
	await _capture("01_tierhaltung")
	await _cleanup()
	_finish()

func _saved_roundtrip(label: String) -> void:
	_key(KEY_SPACE)
	var saved: Dictionary = JSON.parse_string(Atomic.stringify(tribe.village()))
	await _frames(15)
	_expect(JSON.parse_string(Atomic.stringify(tribe.village())) == saved, "Pause changed " + label)
	_expect(saves.save_now() and saves.load_now(), "Save/Load failed: " + label + " / " + saves.last_error)
	_expect(tribe.village() == saved, "Load changed " + label)
	await _until(func(): return tribe._active and not tribe.navigation.pending, 1200)

func _restart_check() -> void:
	await _until(func() -> bool: return tribe.is_active() and lab.ready_for_work and not tribe.navigation.pending, 1200)
	evidence = JSON.parse_string(FileAccess.get_file_as_string("user://d3-village-lab/evidence.json"))
	pen_id = evidence["pen_id"]
	_expect(_pen()["animal_id"] == Lab.ANIMAL and _record()["cycles"] == evidence["cycles"] and tribe.village()["economy"]["milk_received"] == evidence["milk_received"] and tribe.actors.size() == 3, "Cold restart changed animal, production or population.")
	var receipt: Dictionary = tribe.village()["economy"]["receipts"][Lab.ANIMAL].duplicate(true)
	var before: Dictionary = tribe.village().duplicate(true)
	_expect(tribe.receive_milk(receipt) and tribe.village() == before, "Cold restart repeated accepted milk.")
	_expect(tribe.husbandry.attendance(_pen())["error"].is_empty(), "Live D1/D2 source did not reconnect after cold load.")
	tribe.panel._tabs.current_tab = 2
	tribe.panel.refresh()
	await _capture("02_tierhaltung_neustart")
	if not capture_dir.is_empty():
		root.size = Vector2i(800, 900)
		await _frames(8)
		tribe.panel._scroll.ensure_control_visible(tribe.panel._bind_animal)
		await _frames(3)
		await _capture("03_tierhaltung_schmal")
		await _click(tribe.panel._collapse)
		await _frames(3)
		await _capture("04_tierhaltung_welt")
	await _cleanup()
	_finish()

func _pen() -> Dictionary:
	return H.pen(tribe.village(), pen_id)

func _record() -> Dictionary:
	return tribe.village()["husbandry"]["records"][Lab.ANIMAL]

func _finish() -> void:
	print(JSON.stringify({"test": "tribal_age_husbandry", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
