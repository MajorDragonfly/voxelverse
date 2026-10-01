extends SceneTree
const Catalog = preload("res://civilization/technology/technology_catalog.gd")
const Model = preload("res://civilization/technology/preview_model.gd")
const Civilization = preload("res://core/progression/civilization_contract.gd")
const Text = preload("res://civilization/technology/preview_text.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _reject(value: Dictionary, code: String) -> void:
	var errors: PackedStringArray = Catalog.validate(value)
	_expect(errors.has(code), "Missing rejection " + code + ": " + str(errors))
	_expect(not Catalog.describe(value, "medieval.housing")["available"] and not Catalog.describe(value, "medieval.housing")["preview_ready"], "Invalid catalog became available")

func _run() -> void:
	_expect(root.get_node_or_null("GameState") == null and root.get_node_or_null("SaveGameService") == null and root.get_node_or_null("ProgressionService") == null, "Campaign autoloads present in standalone preview")
	var catalog: Dictionary = Catalog.read_catalog()
	var original: Dictionary = catalog.duplicate(true)
	_expect(Catalog.validate(catalog).is_empty(), "Default catalog invalid: " + str(Catalog.validate(catalog)))
	var ids := PackedStringArray()
	for node: Dictionary in catalog["nodes"]: ids.append(node["id"])
	_expect(ids == PackedStringArray(["medieval.housing", "medieval.storage", "medieval.crafting", "medieval.roads", "medieval.trade"]), "Stable IDs or order changed")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(catalog))
	_expect(Catalog.validate(roundtrip).is_empty() and roundtrip == catalog, "JSON roundtrip changed IDs/dependencies")
	var reversed: Dictionary = catalog.duplicate(true)
	reversed["nodes"].reverse()
	_expect(Catalog.validate(reversed).is_empty(), "Valid dependency graph depends on input ordering")
	var candidate: Dictionary = catalog.duplicate(true)
	candidate["schema"] = 2
	_reject(candidate, "unsupported_schema")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["id"] = "Housing"
	_reject(candidate, "invalid_id")
	candidate = catalog.duplicate(true)
	candidate["nodes"].append(candidate["nodes"][0].duplicate(true))
	_reject(candidate, "duplicate_id:medieval.housing")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["requires"] = ["medieval.missing"]
	_reject(candidate, "unknown_dependency:medieval.housing:medieval.missing")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["requires"] = ["medieval.housing"]
	_reject(candidate, "dependency_cycle")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["requires"] = ["medieval.trade"]
	_reject(candidate, "dependency_cycle")
	candidate = catalog.duplicate(true)
	candidate["nodes"][3]["requires"] = ["medieval.trade"]
	_reject(candidate, "dependency_cycle")
	candidate = catalog.duplicate(true)
	candidate["nodes"][4]["requires"] = ["medieval.storage", "medieval.storage"]
	_reject(candidate, "invalid_reference:medieval.trade:requires")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["contract_requirements"] = ["invented"]
	_reject(candidate, "unknown_contract:invented")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["resources"] = ["gold"]
	_reject(candidate, "unknown_resource:gold")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["building_parts"] = ["road_automatic"]
	_reject(candidate, "unknown_building_part:road_automatic")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["implemented"] = true
	_reject(candidate, "unsafe_effect_or_balance:medieval.housing")
	candidate["nodes"][0]["implemented"] = 0
	_reject(candidate, "unsafe_effect_or_balance:medieval.housing")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["requires"] = "not_an_array"
	_reject(candidate, "invalid_list:medieval.housing:requires")
	candidate = catalog.duplicate(true)
	candidate["nodes"][0]["requires"] = [null]
	_reject(candidate, "invalid_reference:medieval.housing:requires")
	candidate = catalog.duplicate(true)
	candidate["nodes"] = []
	_reject(candidate, "invalid_nodes")
	var model := Model.new()
	_expect(not model.status("medieval.housing")["preview_ready"], "Housing ready without tribal evidence")
	_expect(not Catalog.describe(catalog, "medieval.housing", {"housing": 1})["preview_ready"], "Numeric value forged boolean evidence")
	_expect(model.status("medieval.housing")["reasons"][0]["code"] == "contract_missing", "Housing lock has no machine-readable explanation")
	_expect(not model.toggle_mark("medieval.trade") and model.marks.is_empty(), "Blocked trade was marked")
	model.select_scenario(1)
	_expect(model.status("medieval.housing")["preview_ready"], "Supplied example cannot mark housing")
	_expect(not model.status("medieval.storage")["preview_ready"], "Storage ignored housing dependency")
	for id: String in ids:
		_expect(model.toggle_mark(id), "Topological preview marking failed for " + id)
		_expect(not model.status(id)["available"] and not model.status(id)["implemented"], "Preview released a real technology")
	_expect(model.marks.size() == 5, "Preview marks incomplete")
	_expect(model.toggle_mark("medieval.storage"), "Cannot remove storage mark")
	_expect("medieval.crafting" not in model.marks and "medieval.trade" not in model.marks and "medieval.roads" in model.marks, "Transitive invalidation wrong")
	model.toggle_mark("medieval.housing")
	_expect(model.marks.is_empty(), "Removed root retained dependent marks")
	model.select_scenario(2)
	_expect(model.marks.size() == 5 and not model.facts.has("runtime"), "Complete preview forged a runtime release")
	var snapshot: Dictionary = {"schema": 999, "technology": {"future.keep": {"revision": 12}}, "points": 77, "phase": 1, "extension": {"unchanged": [2,3,4]}}
	var bytes: String = JSON.stringify(snapshot)
	Catalog.describe(catalog, "medieval.trade", snapshot, model.marks)
	_expect(JSON.stringify(snapshot) == bytes, "Read-only query mutated unknown/future caller data")
	model.select_scenario(0)
	_expect(model.facts.is_empty() and model.marks.is_empty(), "Reset leaked preview state")
	_expect(Model.new().marks.is_empty(), "Fresh process model inherited marks")
	_expect(not Catalog.describe(catalog, "medieval.unknown")["preview_ready"], "Unknown technology accepted")
	_expect(catalog == original, "Catalog query mutated source data")
	_expect(Civilization.PHASES[2]["implemented"] == false, "Existing epoch contract changed")
	# Keep copied DE/EN presentations of contract requirements honest.
	var translator := Text.new()
	translator.install()
	TranslationServer.set_locale("de")
	for rule: Array in Civilization.PHASES[2]["requirements"]:
		_expect(Text.requirement(rule[0]) == rule[1], "Localized requirement diverged from product contract: " + str(rule[0]))
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for node: Dictionary in catalog["nodes"]:
			for key: String in ["title_key", "description_key", "effect_key"]:
				_expect(not Text.text(node[key]).begins_with("MEDTECH_"), "Missing " + locale + " text for " + node[key])
	translator.uninstall()
	if failures.is_empty(): print("MEDTECH_CATALOG_PASSED: ", checks, " checks; IDs, dependencies, cycles, locks, retention, languages, runtime gate")
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
