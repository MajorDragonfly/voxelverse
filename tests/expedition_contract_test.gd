extends SceneTree
## Executable design acceptance, not flight/gameplay acceptance (ARCH-30).
const Contract = preload("res://tests/fixtures/expedition_contract_draft.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const CONTEXT: Dictionary = {
	"campaign_id": "campaign_fixture", "faction_id": "faction_fixture", "species_id": "species_fixture",
	"systems": ["system_home", "system_other"],
	"bodies": {"body_home": "system_home", "body_other": "system_other"}}
const PATH: String = "user://arch30_whole_snapshot.json"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--arch30-restart"):
		_restart_check(args[args.find("--arch30-restart") + 1])
	else:
		_contract_checks()
		_transfer_checks()
	print(JSON.stringify({"test": "expedition_contract", "scope": "design_fixture", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	return Atomic.parse_dictionary(FileAccess.get_file_as_string("res://tests/fixtures/expedition_contract_draft.json"))

func _contract_checks() -> void:
	var initial: Dictionary = _fixture()
	_expect(Contract.validate(initial, CONTEXT).is_empty(), "Two independent ships rejected.")
	_expect(Atomic.parse_dictionary(JSON.stringify(initial)) == initial, "JSON changed the exact fixture coordinates.")
	_precision_gate(initial)
	var docked: Dictionary = _docked(initial)
	_expect(Contract.validate(docked, CONTEXT).is_empty(), "Dock/crew/cargo/control candidate rejected.")
	var landed: Dictionary = initial.duplicate(true)
	landed.ships.ship_lander.place = _surface()
	landed.people.person_player.place = _surface()
	landed.control = {"person_id": "person_player", "kind": "person", "target_id": "person_player"}
	_expect(Contract.validate(landed, CONTEXT).is_empty(), "Same-body surface/person addresses rejected.")
	for face in range(6):
		landed.ships.ship_lander.place.address = Contract.Cube.address("body_home", face, 1.0, -1.0)
		_expect(Contract.validate(landed, CONTEXT).is_empty(), "Cube face edge rejected.")
	var cases: Array = [
		[["schema"], 2, "schema.unsupported"],
		[["schema"], "1", "schema.unsupported"],
		[["schema"], true, "schema.unsupported"],
		[["revision"], -1, "revision.invalid"],
		[["campaign_id"], "other", "owner.mismatch"],
		[["faction_id"], "other", "owner.mismatch"],
		[["species_id"], "other", "owner.mismatch"],
		[["ships"], [], "snapshot.collections"],
		[["ships", "ship_lander", "id"], "ship_expedition", "ship.identity"],
		[["ships", "ship_lander", "blueprint"], null, "blueprint.reference"],
		[["ships", "ship_lander", "blueprint", "payload_schema"], 2, "blueprint.reference"],
		[["ships", "ship_lander", "blueprint", "revision"], 4, "capabilities.revision"],
		[["ships", "ship_lander", "capabilities", "catalog_revision"], 2, "capabilities.revision"],
		[["ships", "ship_lander", "energy"], 21, "energy.capacity"],
		[["ships", "ship_lander", "energy"], 1.5, "energy.capacity"],
		[["ships", "ship_lander", "place"], [], "place.invalid"],
		[["ships", "ship_lander", "place", "kind"], "orbit_v2", "place.kind"],
		[["ships", "ship_lander", "place", "orientation"], [0, 0, 0, 0], "place.system"],
		[["ships", "ship_lander", "place", "position"], Vector3.ZERO, "data.non_json_or_unbounded"],
		[["ships", "ship_lander", "place", "position"], [NAN, 0, 0], "data.non_json_or_unbounded"],
		[["assets", "transport_sample", "ship_id"], "missing", "asset.reference"],
		[["assets", "transport_sample", "space"], 9, "cargo.capacity"],
		[["people", "person_player", "place", "ship_id"], "missing", "person.ship"],
		[["ships", "ship_lander", "capabilities", "seats"], 0, "passengers.capacity"],
		[["control", "target_id"], "ship_expedition", "control.ship"],
	]
	for entry: Array in cases:
		var bad: Dictionary = initial.duplicate(true)
		_set_path(bad, entry[0], entry[1])
		_reject(bad, entry[2])
	# GDScript comparisons across scalar families can throw instead of returning
	# false. Exercise every discriminator/identity/version boundary before use.
	for base: Dictionary in [initial, docked, landed]:
		_malformed_fields(base)
	var bad: Dictionary = initial.duplicate(true)
	bad.ships.ship_lander.place["host_ship_id"] = "ship_expedition"
	_reject(bad, "place.system") # A union cannot also carry a second location.
	bad = landed.duplicate(true)
	bad.ships.ship_lander.place.system_id = "system_other"
	_reject(bad, "place.body_system")
	bad = docked.duplicate(true)
	bad.ships.ship_lander.place.host_ship_id = "missing"
	_reject(bad, "dock.host")
	bad = docked.duplicate(true)
	bad.ships.ship_lander.place.host_ship_id = "ship_lander"
	_reject(bad, "dock.host")
	bad = docked.duplicate(true)
	bad.ships.ship_lander.place.bay_id = "missing"
	_reject(bad, "dock.bay_missing")
	bad = docked.duplicate(true)
	bad.ships["ship_clone"] = bad.ships.ship_lander.duplicate(true)
	bad.ships.ship_clone.id = "ship_clone"
	_reject(bad, "dock.occupied")
	bad = docked.duplicate(true)
	bad.assets["transport_clone"] = bad.assets.transport_sample.duplicate(true)
	bad.assets.transport_clone.id = "transport_clone"
	_reject(bad, "asset.duplicate_record")
	bad = docked.duplicate(true)
	bad.ships.ship_lander.capabilities.bays["bay_parent"] = [200, 200, 200]
	bad.ships.ship_expedition.place = {"kind": "dock", "host_ship_id": "ship_lander", "bay_id": "bay_parent", "offset": [0, 0, 0], "orientation": [0, 0, 0, 1]}
	_reject(bad, "dock.cycle")
	bad = docked.duplicate(true)
	bad.ships.ship_lander.place.offset = [10, 0, 0]
	_reject(bad, "dock.does_not_fit")
	bad = docked.duplicate(true)
	bad.ships.ship_expedition.capabilities.bays.bay_lander = [6, 3, 8]
	_expect(Contract.validate(bad, CONTEXT).is_empty(), "Exact bay fit rejected.")
	bad.ships.ship_lander.place.orientation = [0, sqrt(0.5), 0, sqrt(0.5)]
	_reject(bad, "dock.does_not_fit")
	bad = initial.duplicate(true)
	bad.people["person_clone"] = bad.people.person_player.duplicate(true)
	_reject(bad, "person.identity")
	var old_save: Dictionary = {"schema": 9, "unchanged_old_data": [1, 2, 3]}
	var old_copy: Dictionary = old_save.duplicate(true)
	_reject(old_save, "schema.unsupported")
	_expect(old_save == old_copy and not old_save.has("ships"), "Design fixture migrated an existing save.")

func _transfer_checks() -> void:
	var before: Dictionary = _fixture()
	var after: Dictionary = _docked(before)
	var staged: Dictionary = Contract.stage(before, after, CONTEXT, 2)
	_expect(staged.ok, "Conserved docking handover could not be staged: " + str(staged))
	if not staged.ok: return
	var original: Dictionary = before.duplicate(true)
	var admitted: Dictionary = Contract.admit(before, staged, CONTEXT)
	_expect(admitted.ok and admitted.data == after and before == original, "Admission mutated live state or lost a participant.")
	admitted.data.ships.ship_lander.energy = 0
	_expect(staged.after == after and before == original, "Candidate aliases a live/prepared snapshot.")
	var bad: Dictionary = after.duplicate(true)
	bad.assets.erase("transport_sample")
	_expect(Contract.stage(before, bad, CONTEXT, 2).code == "transfer.identity_or_payload_changed", "Transfer silently destroyed a physical sample.")
	bad = after.duplicate(true)
	bad.assets.transport_sample.record_id = "replacement_sample"
	_expect(Contract.stage(before, bad, CONTEXT, 2).code == "transfer.identity_or_payload_changed", "Transfer substituted sample identity.")
	bad = after.duplicate(true)
	bad.ships.ship_lander.energy += 1
	_expect(Contract.stage(before, bad, CONTEXT, 2).code == "transfer.energy_balance", "Transfer minted energy.")
	bad = after.duplicate(true)
	bad.ships.ship_lander.blueprint.revision += 1
	bad.ships.ship_lander.capabilities.design_revision += 1
	_expect(Contract.stage(before, bad, CONTEXT, 2).code == "transfer.identity_or_payload_changed", "Transfer silently applied a newer blueprint.")
	bad = after.duplicate(true)
	bad.ships.ship_expedition.place.system_id = "system_other"
	_expect(Contract.stage(before, bad, CONTEXT, 2).code == "transfer.system_changed", "Local handover became an interstellar shortcut.")
	bad = before.duplicate(true)
	bad.ships.ship_lander.energy -= 1
	_expect(Contract.admit(bad, staged, CONTEXT).code == "transfer.stale", "Changed same-revision state was overwritten.")
	_expect(Contract.admit(before, {"after": after}, CONTEXT).code == "transfer.invalid_proposal", "Malformed proposal accepted.")
	_expect(Atomic.write(PATH, before) == OK and Atomic.write(PATH, before) == OK, "Fixture writer setup failed.")
	_expect(Atomic.write(PATH + ".request.json", staged, false) == OK, "Restart request setup failed.")
	_child("before") # Process stops after preparation, before authoritative commit.
	var old_text: String = FileAccess.get_file_as_string(PATH)
	var old_backup: String = FileAccess.get_file_as_string(PATH + ".bak")
	_expect(DirAccess.make_dir_absolute(PATH + ".tmp") == OK, "Could not inject a blocked staging path.")
	admitted = Contract.admit(before, staged, CONTEXT)
	_expect(Atomic.write(PATH, admitted.data) != OK, "Injected write failure did not fail.")
	_expect(before == original and FileAccess.get_file_as_string(PATH) == old_text and FileAccess.get_file_as_string(PATH + ".bak") == old_backup, "Failed write partially published transfer or damaged backup.")
	_expect(DirAccess.remove_absolute(PATH + ".tmp") == OK, "Could not remove failure injection.")
	_expect(Atomic.write(PATH, admitted.data) == OK, "Whole snapshot commit failed.")
	before = admitted.data # Test owner publishes only after durable success.
	_expect(before == after, "Successful commit omitted control/cargo/crew/energy/dock data.")
	_child("after") # Crash after commit, before command acknowledgement.
	var next: Dictionary = after.duplicate(true)
	next.revision += 1
	var later: Dictionary = Contract.stage(after, next, CONTEXT, 0)
	_expect(later.ok and Contract.admit(next, staged, CONTEXT).code == "transfer.stale", "Old request replayed after a later revision.")
	# The same manifest and passenger IDs can leave the bay and reach a surface.
	var undocked: Dictionary = original.duplicate(true)
	undocked.revision = after.revision + 1
	undocked.ships.ship_expedition.energy = after.ships.ship_expedition.energy
	undocked.ships.ship_lander.energy = after.ships.ship_lander.energy
	_expect(Contract.stage(after, undocked, CONTEXT, 0).ok, "Undocking did not preserve the participants.")
	var landed: Dictionary = undocked.duplicate(true)
	landed.revision += 1
	landed.ships.ship_lander.place = _surface()
	landed.people.person_player.place = _surface()
	landed.control.kind = "person"
	landed.control.target_id = "person_player"
	_expect(Contract.stage(undocked, landed, CONTEXT, 0).ok, "Surface/control data handover rejected.")
	var future: Dictionary = after.duplicate(true)
	future.schema = 2
	_expect(Atomic.write(PATH, future) == OK, "Future fixture setup failed.")
	old_text = FileAccess.get_file_as_string(PATH)
	old_backup = FileAccess.get_file_as_string(PATH + ".bak")
	var loaded: Dictionary = Atomic.parse_dictionary(old_text)
	_expect(Contract.validate(loaded, CONTEXT) == "schema.unsupported", "Unknown future contract was not rejected.")
	_expect(Contract.admit(loaded, staged, CONTEXT).code == "schema.unsupported" and FileAccess.get_file_as_string(PATH) == old_text and FileAccess.get_file_as_string(PATH + ".bak") == old_backup, "Future source or backup was changed by admission.")

func _precision_gate(initial: Dictionary) -> void:
	# This independent probe records a real integration blocker. The transition
	# proof uses exact coordinates; it does NOT certify the current save format
	# for arbitrary astronomical doubles. Full-precision serialization is needed.
	var precise: Dictionary = initial.duplicate(true)
	precise.ships.ship_lander.place.position[0] = 1000000000010.125
	_expect(Atomic.parse_dictionary(JSON.stringify(precise, "", true, true)) == precise, "Full-precision JSON cannot represent the proposed address.")
	var probe_path: String = PATH + ".precision_probe.json"
	_expect(Atomic.write(probe_path, precise, false) == OK, "Precision probe could not write its fixture.")
	var preserved: bool = Atomic.parse_dictionary(FileAccess.get_file_as_string(probe_path)) == precise
	print(JSON.stringify({"integration_gate": "system_coordinate_save_precision", "ready": preserved, "required": "lossless double round trip through shared save owner"}))

func _malformed_fields(base: Dictionary) -> void:
	var paths: Array = [
		["schema"], ["campaign_id"], ["ships", "ship_lander", "id"], ["ships", "ship_lander", "role"],
		["ships", "ship_lander", "blueprint", "payload_schema"], ["ships", "ship_lander", "capabilities", "design_revision"],
		["ships", "ship_lander", "capabilities", "catalog_revision"], ["ships", "ship_lander", "place", "kind"],
		["assets", "transport_sample", "id"], ["assets", "transport_sample", "kind"],
		["people", "person_player", "id"], ["people", "person_player", "place", "kind"],
		["control", "person_id"], ["control", "kind"], ["control", "target_id"]]
	if base.ships.ship_lander.place.kind == "surface":
		paths.append(["ships", "ship_lander", "place", "address", "mode"])
		paths.append(["ships", "ship_lander", "place", "system_id"])
	for path: Array in paths:
		for wrong in [null, true, "", [], {}]:
			var bad: Dictionary = base.duplicate(true)
			_set_path(bad, path, wrong)
			_expect(not Contract.validate(bad, CONTEXT).is_empty(), "Malformed field escaped validation: " + str(path))

func _restart_check(expected: String) -> void:
	var saved: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH))
	var staged: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH + ".request.json"))
	_expect(Contract.validate(saved, CONTEXT).is_empty(), "Restart loaded an invalid snapshot.")
	_expect(saved == staged[expected], "Restart recovered a mixture of old/new participants.")
	var admitted: Dictionary = Contract.admit(saved, staged, CONTEXT)
	_expect(admitted.ok and admitted.data == staged.after, "Restart could not admit the same request.")
	_expect(admitted.code == ("transfer.replay" if expected == "after" else ""), "Restart did not distinguish uncommitted work from acknowledged replay.")
	_expect(saved == Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH)), "Read/admission wrote the saved source.")

func _child(expected: String) -> void:
	var output: Array = []
	var result: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/expedition_contract_test.gd", "--", "--arch30-restart", expected], output, true)
	for line in output: print(str(line))
	_expect(result == 0, "Fresh-process " + expected + " check failed.")

func _docked(before: Dictionary) -> Dictionary:
	var after: Dictionary = before.duplicate(true)
	after.revision += 1
	after.ships.ship_lander.place = {"kind": "dock", "host_ship_id": "ship_expedition", "bay_id": "bay_lander", "offset": [0, 0, 0], "orientation": [0, 0, 0, 1]}
	after.people.person_player.place.ship_id = "ship_expedition"
	after.control.target_id = "ship_expedition"
	for asset: Dictionary in after.assets.values(): asset.ship_id = "ship_expedition"
	after.ships.ship_expedition.energy -= 4
	after.ships.ship_lander.energy += 2 # Four transferred, two spent: total is conserved.
	return after

func _surface() -> Dictionary:
	return {"kind": "surface", "system_id": "system_home", "address": Contract.Cube.address("body_home", 0, 0.1, -0.2), "orientation": [0, 0, 0, 1]}

func _set_path(data: Dictionary, path: Array, value: Variant) -> void:
	var cursor: Dictionary = data
	for index in range(path.size() - 1): cursor = cursor[path[index]]
	cursor[path.back()] = value

func _reject(data: Dictionary, code: String) -> void:
	_expect(Contract.validate(data, CONTEXT) == code, "Expected " + code + ", got " + Contract.validate(data, CONTEXT))

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
