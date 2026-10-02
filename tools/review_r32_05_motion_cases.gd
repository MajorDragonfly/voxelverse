extends "res://tools/scanner_visibility_cases.gd"
## Extend the existing shared cases with explicit tails/spike counts.
func run(tree: SceneTree, player: Node3D, capture: String = "") -> Dictionary:
	var report: Dictionary = await super.run(tree, player, capture)
	var progression: Node = tree.root.get_node("ProgressionService")
	var points_before: int = progression.discovery_points
	if not capture.is_empty():
		_title = Label.new(); _title.position = Vector2(16, 200)
		_title.add_theme_font_size_override("font_size", 18); tree.root.add_child(_title)
	var animal: Node3D = _animal(2771337, 980)
	animal.global_position = player.global_position + Vector3(0, 0, -5)
	await _settle()
	_camera.look_at(animal.global_position + Vector3.UP * 0.56)
	_scanner.reset()
	for tick in range(85):
		await _settle(1)
		animal._preview._process(1.0 / 30.0)
		_scanner._physics_process(1.0 / 30.0)
		_check(_scanner.target == animal, "Centered production species scan lost animal")
		await _record("Species discovery / %d%%" % roundi(_scanner.ratio() * 100))
	_check(_scanner.known and progression.has_species_scan(2771337), "Visible production species scan did not register")
	_check(progression.discovery_points == points_before + progression.SPECIES_DISCOVERY_POINTS, "Species scan reward missing/duplicated")
	var another: Node3D = _animal(2771337, 981)
	animal.global_position.x += 30
	another.global_position = player.global_position + Vector3(0, 0, -5)
	await _settle()
	for tick in range(20):
		_scanner._physics_process(1.0 / 30.0)
		_check(_scanner.target == another and _scanner.known and _scanner.ratio() == 1.0, "Another individual of known species restarted discovery")
		await _record("Known species / another individual / one reward")
	_check(progression.discovery_points == points_before + progression.SPECIES_DISCOVERY_POINTS, "Known species paid another discovery reward")
	measurements.append({"case": "known_species", "species_seed": 2771337, "points_before": points_before, "points_after": progression.discovery_points, "expected_one_reward": progression.SPECIES_DISCOVERY_POINTS})
	animal.queue_free(); another.queue_free()
	if _title != null: _title.queue_free()
	_scanner.reset(); await _settle()
	report.failures = failures; report.measurements = measurements
	return report

func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"samples": values.size(), "median": values[values.size() / 2], "p50": values[values.size() / 2],
		"p95": values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)],
		"p99": values[mini(values.size() - 1, ceili(values.size() * 0.99) - 1)], "max": values.back(),
		"over_33_ms": values.filter(func(value: float) -> bool: return value > 33).size(),
		"over_50_ms": values.filter(func(value: float) -> bool: return value > 50).size(),
		"over_100_ms": values.filter(func(value: float) -> bool: return value > 100).size()}
