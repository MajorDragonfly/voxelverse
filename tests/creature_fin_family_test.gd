extends "res://tests/creature_appendage_family_checks.gd"

func run() -> void:
	Profiles = preload("res://creatures/catalog/creature_fin_catalog.gd")
	Shapes = preload("res://creatures/editor/creature_fin_geometry.gd")
	family = "fins"
	channel = "fin"
	action = "fin_flex"
	prefix = "Fin"
	button_name = "FlexFins"
	stats_source = "tail_fin"
	entry_script = "res://tests/creature_fin_family_test.gd"
	IDS.assign(["fins_broad_paddle", "fins_slender_steering", "fins_round_side", "fins_tall_dorsal", "fins_long_fringe", "fins_small_stabilizer"])
	ENGLISH.assign(["Broad paddle fin", "Slender steering fin", "Small round fin", "Tall dorsal fin", "Long fin fringe", "Small stabilizer fin"])
	await super.run()
