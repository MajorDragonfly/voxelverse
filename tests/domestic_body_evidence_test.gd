extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
var failures: Array[String] = []
var reports: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	var work: Dictionary = {}
	var seeds: Array = [1, 2, 3, 10, 42, 100, 555, 1337, 15838, 63352, 23757, 99991, 87654321, 2147483647] + range(1000, 1064)
	if "--quick" in OS.get_cmdline_user_args(): seeds = [15838]
	for seed_value in seeds:
		state.start_world_with_seed(seed_value)
		state.campaign.reset("d11-evidence")
		state.active_system_id = ""
		state.set_world_seed(state.world_seed, false)
		var catalog: Dictionary = Catalog.ensure(state)
		for entry: Dictionary in catalog["species"]:
			var before: String = JSON.stringify(entry["blueprint"])
			var check_started: int = Time.get_ticks_usec()
			Evidence.confirm(entry, root)
			var check_usec: int = Time.get_ticks_usec() - check_started
			var evidence: Dictionary = entry["body_evidence"]
			if reports.is_empty() and not evidence["errors"].is_empty(): print(JSON.stringify(evidence))
			check(Evidence.approved(entry), "Rejected generated body %d/%s: %s" % [seed_value, entry["group"], evidence["errors"]])
			check(before == JSON.stringify(entry["blueprint"]), "Inspection mutated frozen body")
			var restored: Dictionary = JSON.parse_string(JSON.stringify(entry))
			check(Evidence.validate(restored).is_empty(), "Evidence failed JSON reload")
			var preserved: String = JSON.stringify(restored)
			check(not Evidence.confirm(restored, root) and preserved == JSON.stringify(restored), "Saved evidence regenerated")
			reports.append({"seed": seed_value, "group": entry["group"], "legs": evidence["rest"]["leg_count"], "gap": evidence["rest"]["max_contact_error"], "stretch": evidence["rest"]["max_rest_stretch"], "check_usec": check_usec, "errors": evidence["errors"]})
			if entry["group"] == "work": work = entry.duplicate(true)
		check(Catalog.validate(catalog, state.get_current_body()).is_empty(), "Catalog rejected measured evidence")
	# Original D1 snapshots had no B1 attachment block. Reading must stay pure.
	var legacy: Dictionary = work.duplicate(true)
	legacy.erase("body_evidence")
	legacy["blueprint"]["assembly"].erase("body_attachments")
	var legacy_before: String = JSON.stringify(legacy["blueprint"])
	Evidence.confirm(legacy, root)
	check(Evidence.approved(legacy) and legacy["body_evidence"]["body"]["attachment_source"] == "legacy_default", "Unchanged pre-B1 body lost suitability")
	check(legacy_before == JSON.stringify(legacy["blueprint"]), "Legacy body acquired authored attachments")
	for negative in ["disabled", "buried", "stretch", "span"]:
		var candidate: Dictionary = work.duplicate(true)
		candidate.erase("body_evidence")
		var blueprint: Dictionary = Contract.decode(candidate["blueprint"])
		if negative == "disabled": blueprint["assembly"]["body_attachments"]["sockets"]["saddle.primary"]["enabled"] = false
		elif negative == "buried": blueprint["assembly"]["body_attachments"]["sockets"]["saddle.primary"]["offset"][1] = -0.3
		else:
			var first: bool = true
			for part: Dictionary in blueprint["parts"]:
				if part["category"] != "legs": continue
				if negative == "stretch" and first: part["scale"] *= 0.25
				if negative == "span": part["anchor_t"] = 0.5
				first = false
			Anatomy.rebind_all_parts(blueprint)
		candidate["blueprint"] = Contract.encode(blueprint)
		Evidence.confirm(candidate, root)
		check(not Evidence.approved(candidate), "Unsuitable actual body passed: " + negative)
		check(Evidence.validate(candidate).is_empty(), "Rejected body cannot be preserved: " + negative)
		candidate["body_evidence"]["status"] = "passed"
		check(not Evidence.validate(candidate).is_empty(), "Forged verdict accepted: " + negative)
	var stale: Dictionary = work.duplicate(true)
	stale["blueprint"]["name"] = "Changed body snapshot"
	check(not Evidence.validate(stale).is_empty(), "Unbound evidence accepted")
	for key in ["schema", "policy_version"]:
		var future: Dictionary = work.duplicate(true)
		future["body_evidence"][key] = 99 if key == "schema" else "future_body_v99"
		check(Evidence.unsupported(future), "Future body policy accepted")
	var output := {"test": "domestic_body_evidence", "seeds": seeds.size(), "bodies": reports.size(), "failures": failures, "measurements": reports}
	FileAccess.open("user://d11-body-evidence.json", FileAccess.WRITE).store_string(JSON.stringify(output, "\t"))
	print(JSON.stringify(output))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
