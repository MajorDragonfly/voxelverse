extends "res://tools/review_int30_drink_contract.gd"
## Reuse the existing real water/player/HUD contract, explicitly a terrain
## publication fixture. Add swimming through the production primary action.
var swim_rows: Array[Dictionary] = []

func _check(ok: bool, message: String) -> void:
	super._check(ok, message)
	if message not in ["Actual freshwater source did not resolve.", "Dry/saltwater advertised drinking."]: return
	var player: Node = get_first_node_in_group(&"player")
	if player == null: return
	var point: Vector3 = player.global_position
	var source: Dictionary = player.reachable_drink_source(point)
	var context: Node = player.get_node("ContextActionHUD")
	player.is_swimming = true
	player.current_thirst = 20.0
	var advertised: bool = context.drink_prompt_at(point)
	player._try_primary_action()
	var drank: bool = player.current_thirst > 20.0
	var expected: bool = not source.is_empty()
	super._check(advertised == expected and drank == expected, "Swimming primary action/HUD disagrees with the same reachable freshwater source.")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		context._update_context()
		super._check(("trinken" in context._label.text) == expected, "Visible swimming HUD advertises a different source from primary action.")
	var sample: Dictionary = Space.sample(player, point)
	swim_rows.append({"kind":sample.get("water_kind", "ocean") if sample.water else "dry", "water":sample.water, "source":not source.is_empty(), "advertised":advertised, "drank":drank})
	player.is_swimming = false

func _finish() -> void:
	_check(swim_rows.size() == 3, "Did not cover all real-sampler dry/fresh/salt swimming cases.")
	print("R32_04_SWIMMING_DRINK ", JSON.stringify(swim_rows))
	await super._finish()
