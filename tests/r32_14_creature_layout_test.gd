extends "res://tests/hud_layout_test.gd"
## Fast widget/lifecycle regression only; the full campaign is a separate consumer.
func _sphere() -> void:
	print("R32_14_CREATURE_FIXTURE_ONLY: full spherical consumer not run here")
