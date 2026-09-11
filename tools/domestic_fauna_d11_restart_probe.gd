extends SceneTree
const Registry = preload("res://core/campaign/body_registry.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Recovery = preload("res://world/fauna/domestication/domestic_habitat_recovery.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://d11-restart.json"
	var mode: String = OS.get_environment("D1_RESTART_MODE")
	if mode == "write":
		state.start_world_with_seed(15838)
		state.campaign.reset("d11-cold-restart")
		state.active_system_id = ""
		state.set_world_seed(state.world_seed, false)
		var expected: Dictionary = {"catalogs": {}}
		for seed_value in [15838, 63352, 23757]:
			state.activate_planet(15838, 0, seed_value)
			var catalog: Dictionary = Catalog.ensure(state)
			if seed_value == 15838:
				for species: Dictionary in catalog["species"]:
					species["blueprint"]["assembly"].erase("body_attachments")
					species["blueprint"]["name"] = "Already saved " + species["group"]
				check(saves.save_now("user://d11-legacy.json"), "Save D1 catalog before B1/evidence")
				expected["legacy_species"] = signature(catalog["species"])
			for species: Dictionary in catalog["species"]:
				Evidence.confirm(species, root)
				check(Evidence.approved(species), "Generated or old body rejected")
			if seed_value == 15838:
				catalog["habitat_status"] = "unavailable"
				var recovery := Recovery.new()
				recovery.begin(root.get_node("WorldGenerator"), catalog)
				recovery.step(root.get_node("WorldGenerator"), catalog, 7)
				check(recovery.data["status"] == "searching" and recovery.data["direction"] == 7, "Cold restart did not stop inside a node")
				var completed: Dictionary = catalog.duplicate(true)
				var reference := Recovery.new()
				reference.begin(root.get_node("WorldGenerator"), completed)
				complete(reference, completed, 32)
				check(completed["habitat_status"] == "ready", "Reference search failed")
				expected["completed"] = signature(completed)
			expected["catalogs"][str(seed_value)] = signature(catalog)
		check(saves.save_now(), "Save D1.1 campaign: " + saves.last_error)
		check(Atomic.write("user://d11-expected.json", expected) == OK, "Write cold restart reference")
	elif mode == "read":
		check(saves.load_now(), "Cold load D1.1: " + saves.last_error)
		var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://d11-expected.json"))
		for seed_value in [23757, 63352, 15838]:
			state.activate_planet(15838, 0, seed_value)
			var catalog: Dictionary = Catalog.ensure(state)
			check(signature(catalog) == expected["catalogs"][str(seed_value)], "Visit order or restart changed catalog")
			for species: Dictionary in catalog["species"]:
				check(Evidence.approved(species) and not Evidence.confirm(species, root), "Cold load reran/rejected saved body check")
		var resumed: Dictionary = Catalog.ensure(state)
		var recovery := Recovery.new()
		recovery.begin(root.get_node("WorldGenerator"), resumed)
		complete(recovery, resumed, 1)
		check(signature(resumed) == expected["completed"], "Fresh-process recovery changed routes, IDs or search cursor")
		check(saves.save_now(), "Save completed recovery")
		var snapshot: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(saves.save_path))
		for kind in ["evidence_schema", "evidence_policy", "body_schema", "rest_schema", "attachment_schema", "recovery_schema", "recovery_algorithm"]:
			var future: Dictionary = snapshot.duplicate(true)
			var catalog: Dictionary = Registry.active(future.game_state)["fauna_catalog"]
			var evidence: Dictionary = catalog["species"][0]["body_evidence"]
			match kind:
				"evidence_schema": evidence["schema"] = 99
				"evidence_policy": evidence["policy_version"] = "future_body_v99"
				"body_schema": evidence["body"]["schema"] = 99
				"rest_schema": evidence["rest"]["schema"] = 99
				"attachment_schema": catalog["species"][0]["blueprint"]["assembly"]["body_attachments"] = {"schema": 99}
				"recovery_schema": catalog["habitat_recovery"]["schema"] = 99
				"recovery_algorithm": catalog["habitat_recovery"]["algorithm"] = "future_search_v99"
			check(Atomic.write("user://d11-future.json", future, false) == OK, "Write future fixture")
			check(Atomic.write("user://d11-future.json.bak", snapshot, false) == OK, "Write compatible backup")
			var before: String = FileAccess.get_file_as_string("user://d11-future.json")
			check(not saves.load_now("user://d11-future.json"), "Downgraded future " + kind)
			check(not saves.save_now("user://d11-future.json"), "Overwrote future " + kind)
			check(before == FileAccess.get_file_as_string("user://d11-future.json"), "Changed protected future bytes")
			check(saves.load_now(), "Restore compatible D1.1")
		check(saves.load_now("user://d11-legacy.json"), "Load original D1 file")
		var old: Dictionary = Catalog.ensure(state)
		check(signature(old["species"]) == expected["legacy_species"], "Old species changed during load")
		for species: Dictionary in old["species"]:
			var before: String = signature(species["blueprint"])
			Evidence.confirm(species, root)
			check(Evidence.approved(species) and species["body_evidence"]["body"]["attachment_source"] == "legacy_default", "Old catalog cannot be confirmed without rewriting")
			check(before == signature(species["blueprint"]), "Rewrote original D1 body")
		check(saves.save_now("user://d11-migrated.json"), "Save additive D1.1 evidence")
	else: failures.append("Run write/read in separate processes")
	print(JSON.stringify({"test": "domestic_fauna_d11_restart", "mode": mode, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func complete(recovery: RefCounted, catalog: Dictionary, budget: int) -> void:
	while recovery.data["status"] == "searching": recovery.step(root.get_node("WorldGenerator"), catalog, budget)
func signature(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(Atomic.stringify(value))).sha256_text()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
