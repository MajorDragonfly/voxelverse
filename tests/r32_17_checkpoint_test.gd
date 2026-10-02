extends SceneTree
const Probe = preload("res://tools/review_r32_17_campaign.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var original: Dictionary = {"delivered": 3, "stock": {"wood": 3}, "members": [{"order": "wood", "work": 1.9333333333333313, "hydration": 99.33799999999685}]}
	var roundtrip: Dictionary = original.duplicate(true)
	roundtrip.members[0].work = float(original.members[0].work) - 1e-15
	roundtrip.members[0].hydration = float(original.members[0].hydration) - 1e-13
	var drift: Dictionary = Probe.checkpoint_changes(original, roundtrip)
	var checks: Array = [Probe.checkpoint_changes(original, original).changed.is_empty(), drift.changed.is_empty() and drift.json_rounding.size() == 2]
	for mutation: String in ["stock", "order", "progress", "missing"]:
		var changed: Dictionary = roundtrip.duplicate(true)
		match mutation:
			"stock": changed.stock.wood += 1
			"order": changed.members[0].order = "stone"
			"progress": changed.members[0].work += 0.000001
			"missing": changed.erase("delivered")
		checks.append(not Probe.checkpoint_changes(original, changed).changed.is_empty())
	var passed: bool = not checks.has(false)
	print(JSON.stringify({"test": "r32_17_checkpoint", "checks": checks.size(), "passed": passed, "results": checks,
		"comparison": drift,
		"scope": "observed JSON ULP rounding allowed and logged; stock/order/progress/missing data regressions rejected"}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if passed else 1)
