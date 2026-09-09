extends SceneTree
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for group in Contract.GROUPS:
		var value: Dictionary = Contract.suitability(group)
		check(Contract.validate(value).is_empty(), "Valid role rejected: " + group)
		var future: Dictionary = value.duplicate(true)
		future["schema"] = 2
		check(not Contract.validate(future).is_empty(), "Future schema accepted")
		value["trainability"] = NAN
		check(not Contract.validate(value).is_empty(), "Nonfinite value accepted")
	var milk: Dictionary = Contract.suitability("milk")
	milk["milk_interval"] = 0
	check(not Contract.validate(milk).is_empty(), "Zero production interval accepted")
	var work: Dictionary = Contract.suitability("work")
	work["anatomy"]["locomotion"] = "swim"
	check(not Contract.validate(work).is_empty(), "Swimmer accepted as mount")
	var dog: Dictionary = Contract.suitability("companion")
	dog["bonding"] = 0.1
	check(not Contract.validate(dog).is_empty(), "Unsocial companion accepted")
	var design := {"parts": [{"uid": "old-id", "position": Vector3(1.25, 2.5, -3)}], "revision": 4}
	var restored: Dictionary = Contract.decode(JSON.parse_string(JSON.stringify(Contract.encode(design))))
	check(restored["parts"][0]["position"] == design["parts"][0]["position"] and restored["parts"][0]["uid"] == "old-id" and int(restored["revision"]) == 4, "Snapshot lost vector/identity")
	print(JSON.stringify({"test": "domestication_contract", "failures": failures}))
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
