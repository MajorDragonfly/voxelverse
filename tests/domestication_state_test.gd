extends SceneTree
const State = preload("res://world/domestication/animal_state.gd")
const Controller = preload("res://world/domestication/domestication_controller.gd")
const Fixture = preload("res://world/domestication/lab/lab_fixture.gd")
const Store = preload("res://world/domestication/lab/lab_store.gd")
var failures: Array[String] = []
var checks: int = 0
var snapshot: Dictionary
var controller = Controller.new()
var store = Store.new()
var fail_write: bool = false
var use_disk: bool = false
var change_events: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").session_managed = true
	root.get_node("SaveGameService").session_active = false
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--d2-child" in args:
		store.path = args[args.find("--d2-child") + 1]
		snapshot = store.load_snapshot()
		_expect(not snapshot.is_empty(), "Child cannot load snapshot")
		if snapshot.is_empty():
			_finish()
			return
		use_disk = true
		controller.configure(snapshot["registry"], _commit, Fixture.policy)
		_restart_child()
		_finish()
		return
	store.path = "user://d2_tests/%s/snapshot.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	controller.animal_changed.connect(func(_id: String, code: String): change_events.append(code))
	_reset()
	var original: String = JSON.stringify(snapshot)
	_expect(controller.configure(snapshot["registry"], _commit).is_empty(), "Missing adapter must still allow read-only setup")
	_expect(_begin()["code"] == "d1_unavailable", "Unreviewed D1 must fail closed")
	_expect(JSON.stringify(snapshot) == original, "Missing D1 changed stock/individual")
	controller.configure(snapshot["registry"], _commit, Fixture.policy)
	for pair: Array in [["phase", 0], ["player_species_id", Fixture.FOREIGN], ["body_id", "other_body"], ["campaign_id", "other_campaign"], ["actor_alive", false], ["line_of_sight", false], ["threatened", true], ["actor_position", Vector3(50, 0, 0)], ["home", Vector3(NAN, 0, 0)], ["capacity", 0]]:
		var context: Dictionary = Fixture.context(snapshot)
		context[pair[0]] = pair[1]
		_expect(not controller.begin_offer(Fixture.ANIMAL, "roots", context)["ok"], "Invalid context accepted: " + str(pair[0]))
	_expect(not _begin("meat")["ok"], "Wrong food accepted")
	snapshot["stock"]["roots"] = 0
	_expect(not _begin()["ok"], "Empty stock accepted")
	snapshot["stock"]["roots"] = 12
	snapshot["friendship"] = true
	_expect(not controller.command(Fixture.ANIMAL, "follow", Fixture.context(snapshot))["ok"], "Friendship granted an animal command")
	_expect(controller.record(Fixture.ANIMAL)["owner_faction_id"] == "" and controller.record(Fixture.ANIMAL)["trust"] == 0.0, "Friendship became taming")
	fail_write = true
	var previous_events: int = change_events.size()
	_expect(not _begin()["ok"] and controller.record(Fixture.ANIMAL)["status"] == "wild", "Failed start reserved animal")
	_expect(change_events.size() == previous_events, "Failed save emitted success feedback")
	fail_write = false
	_expect(_begin()["ok"], "Cannot start offer")
	_expect(not _begin()["ok"], "Double click started overlapping offer")
	_expect(not controller.advance_offer(Fixture.ANIMAL, 100, Fixture.context(snapshot))["ok"], "Huge delta bypassed offering")
	_expect(not controller.advance_offer(Fixture.ANIMAL, NAN, Fixture.context(snapshot))["ok"], "NaN delta accepted")
	var paused_context: Dictionary = Fixture.context(snapshot)
	paused_context["paused"] = true
	controller.advance_offer(Fixture.ANIMAL, 0.25, paused_context)
	_expect(controller.record(Fixture.ANIMAL)["pending"]["elapsed"] == 0.0, "Paused offering advanced")
	var unsafe: Dictionary = Fixture.context(snapshot)
	unsafe["line_of_sight"] = false
	controller.advance_offer(Fixture.ANIMAL, 0.25, unsafe)
	_expect(controller.record(Fixture.ANIMAL)["status"] == "wild" and snapshot["stock"]["roots"] == 12, "Interrupted unpaid offer kept claim or charged food")
	_begin()
	for i in range(7): controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))
	fail_write = true
	_expect(not controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))["ok"], "Failed commit accepted food/trust")
	_expect(snapshot["stock"]["roots"] == 12 and controller.record(Fixture.ANIMAL)["trust"] == 0.0, "Failed write did not roll back")
	fail_write = false
	_expect(controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))["ok"], "Retry failed")
	_expect(snapshot["stock"]["roots"] == 11 and controller.record(Fixture.ANIMAL)["trust"] == 25.0, "Retry charged wrong amount")
	_expect(not controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))["ok"] and snapshot["stock"]["roots"] == 11, "Replaying completed offer charged twice")
	_begin()
	unsafe = Fixture.context(snapshot)
	unsafe["threatened"] = true
	controller.advance_offer(Fixture.ANIMAL, 0.25, unsafe)
	_expect(controller.record(Fixture.ANIMAL)["trust"] == 25.0 and snapshot["stock"]["roots"] == 11, "Flight lost completed trust or charged unfinished meal")
	var other_context: Dictionary = Fixture.context(snapshot)
	other_context["faction_id"] = "other_faction"
	_expect(not controller.begin_offer(Fixture.ANIMAL, "roots", other_context)["ok"], "Another faction stole partial taming")
	var extra: Dictionary = State.individual("second_animal", Fixture.FOREIGN, Fixture.BODY, {"id": "body", "revision": 1}, Vector3(2, 0, 2))
	controller.registry["animals"]["second_animal"] = extra
	_expect(controller.begin_offer("second_animal", "roots", Fixture.context(snapshot))["code"] == "capacity_full", "Partial taming did not reserve capacity")
	_expect(controller.abandon_claim(Fixture.ANIMAL, Fixture.context(snapshot))["ok"], "Cannot free an abandoned claim")
	_expect(State.occupied(controller.registry, Fixture.FACTION) == 0 and snapshot["stock"]["roots"] == 11, "Abandonment refunded food or kept capacity")
	_reset()
	for i in range(4): _meal()
	var animal: Dictionary = controller.record(Fixture.ANIMAL)
	_expect(animal["status"] == "tamed" and animal["owner_faction_id"] == Fixture.FACTION and animal["species_id"] == Fixture.FOREIGN and animal["object_id"] == Fixture.ANIMAL, "Taming changed identity or did not set owner")
	_expect(snapshot["stock"]["roots"] == 8 and animal["trust"] == 100.0, "Taming cost mismatch")
	var owned: Array[Dictionary] = controller.owned_animals(Fixture.FACTION)
	_expect(owned.size() == 1 and controller.owned_animals("other_faction").is_empty(), "Owned animal register mixed factions")
	owned[0]["species_id"] = "mutated_copy"
	_expect(controller.record(Fixture.ANIMAL)["species_id"] == Fixture.FOREIGN, "UI record mutated persistent animal")
	_expect(not controller.command(Fixture.ANIMAL, "follow", other_context)["ok"], "Another faction commands owned animal")
	for order: String in State.ORDERS:
		_expect(controller.command(Fixture.ANIMAL, order, Fixture.context(snapshot))["ok"], "Order refused: " + order)
	_expect(not controller.command(Fixture.ANIMAL, "citizen", Fixture.context(snapshot))["ok"], "Recruitment command accepted")
	_expect(controller.damage(Fixture.ANIMAL, 100)["ok"], "Death failed")
	_expect(controller.record(Fixture.ANIMAL)["status"] == "dead" and State.occupied(controller.registry, Fixture.FACTION) == 0, "Death lost tombstone or occupied capacity")
	_expect(not _begin()["ok"] and not controller.command(Fixture.ANIMAL, "home", Fixture.context(snapshot))["ok"], "Dead animal revived or commanded")
	_expect(controller.record(Fixture.ANIMAL)["owner_faction_id"] == Fixture.FACTION, "Death lost ownership history")
	_expect(controller.owned_animals(Fixture.FACTION).is_empty() and controller.owned_animals(Fixture.FACTION, true).size() == 1, "Dead animal counted as living owned animal")
	# Validation at load boundaries: JSON numbers, unknown versions, invalid state.
	var serialized: Variant = JSON.parse_string(JSON.stringify(controller.registry))
	_expect(State.validate(serialized).is_empty(), "JSON round trip rejected numeric values")
	for pair: Array in [["health", NAN], ["position", [0, "bad", 0]], ["pending", []], ["status", "citizen"], ["surface_mode", "spherical"], ["cargo", {"milk": 1}], ["trust", 101]]:
		var corrupted: Dictionary = controller.registry.duplicate(true)
		corrupted["animals"][Fixture.ANIMAL][pair[0]] = pair[1]
		_expect(not State.validate(corrupted).is_empty(), "Malformed animal accepted: " + pair[0])
	_test_store_and_restart()
	_finish()

func _test_store_and_restart() -> void:
	_reset()
	use_disk = true
	_expect(controller.checkpoint(), "Initial snapshot cannot save")
	_meal()
	_begin()
	for i in range(3): controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))
	_expect(controller.checkpoint(), "Partial offer not saved")
	var expected: String = JSON.stringify(store.load_snapshot())
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/domestication_state_test.gd", "--", "--d2-child", ProjectSettings.globalize_path(store.path)], output, true)
	_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and str(output).contains("D2_STATE_PASS"), "Restart child failed: " + str(output))
	snapshot = store.load_snapshot()
	_expect(snapshot["registry"]["animals"][Fixture.ANIMAL]["order"] == "home" and snapshot["stock"]["roots"] == 8, "Child's persisted order/cost lost")
	var saved: String = FileAccess.get_file_as_string(store.path)
	# Incomplete temp must never win over a complete main file.
	_write(store.path + ".tmp", "{")
	_expect(JSON.stringify(store.load_snapshot()) == JSON.stringify(JSON.parse_string(saved)), "Incomplete temporary file replaced valid save")
	_write(store.path, "{broken")
	var recovered: Dictionary = store.load_snapshot()
	_expect(not recovered.is_empty() and store.recovered, "Backup recovery failed")
	_expect(store.write_snapshot(recovered), "Recovered save cannot be repaired")
	_write(store.path, '{"schema":99}')
	_expect(store.load_snapshot().is_empty() and store.blocked and not store.write_snapshot(recovered), "Future version was overwritten or bypassed via backup")
	_expect(FileAccess.get_file_as_string(store.path) == '{"schema":99}', "Future original changed")
	# A real filesystem failure, not just the injected transaction failure above.
	var blocked := Store.new()
	var parent_file: String = store.path.get_base_dir() + "/not_a_directory"
	_write(parent_file, "sentinel")
	blocked.path = parent_file + "/save.json"
	_expect(not blocked.write_snapshot(recovered) and FileAccess.get_file_as_string(parent_file) == "sentinel", "Real write failure damaged existing file")
	_expect(not expected.is_empty(), "Missing restart baseline")

func _restart_child() -> void:
	var a: Dictionary = controller.record(Fixture.ANIMAL)
	_expect(a["object_id"] == Fixture.ANIMAL and a["species_id"] == Fixture.FOREIGN and a["trust"] == 25.0 and a["pending"]["elapsed"] == 0.75, "Restart lost identity/trust/partial progress")
	_expect(snapshot["stock"]["roots"] == 11, "Restart changed stock")
	for i in range(5): controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))
	_meal()
	_meal()
	_expect(controller.record(Fixture.ANIMAL)["status"] == "tamed" and snapshot["stock"]["roots"] == 8, "Restart continuation did not tame at exact cost")
	for order: String in ["follow", "wait", "home"]:
		_expect(controller.command(Fixture.ANIMAL, order, Fixture.context(snapshot))["ok"], "Child command failed")
		var restored: Dictionary = store.load_snapshot()
		_expect(restored["registry"]["animals"][Fixture.ANIMAL]["order"] == order and restored["registry"]["animals"][Fixture.ANIMAL]["owner_faction_id"] == Fixture.FACTION, "Saved order/owner lost")

func _reset() -> void:
	snapshot = Fixture.create()
	fail_write = false
	use_disk = false
	controller.configure(snapshot["registry"], _commit, Fixture.policy)

func _begin(food: String = "roots") -> Dictionary:
	return controller.begin_offer(Fixture.ANIMAL, food, Fixture.context(snapshot))

func _meal() -> void:
	_expect(_begin()["ok"], "Meal start failed")
	for i in range(8): controller.advance_offer(Fixture.ANIMAL, 0.25, Fixture.context(snapshot))

func _commit(registry: Dictionary, cost: Dictionary) -> bool:
	if fail_write: return false
	var proposed: Dictionary = snapshot.duplicate(true)
	proposed["registry"] = registry
	for food: String in cost:
		if int(proposed["stock"].get(food, 0)) < int(cost[food]): return false
		proposed["stock"][food] -= cost[food]
	if use_disk and not store.write_snapshot(proposed): return false
	snapshot = proposed
	return true

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("D2_FAIL: " + label)

func _finish() -> void:
	print(JSON.stringify({"checks": checks, "failures": failures}))
	print("D2_STATE_PASS" if failures.is_empty() else "D2_STATE_FAIL")
	quit(0 if failures.is_empty() else 1)
