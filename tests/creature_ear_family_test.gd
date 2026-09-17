extends "res://tests/creature_appendage_family_checks.gd"

func run() -> void:
	Profiles = preload("res://creatures/catalog/creature_ear_catalog.gd")
	Shapes = preload("res://creatures/editor/creature_ear_geometry.gd")
	family = "ears"
	channel = "ear"
	action = "ear_perk"
	prefix = "Ear"
	button_name = "PerkEars"
	stats_source = "decor_feathers"
	entry_script = "res://tests/creature_ear_family_test.gd"
	IDS.assign(["ears_cat_pointed", "ears_bear_round", "ears_rabbit_long", "ears_dog_floppy", "ears_elephant_broad", "ears_bat_large"])
	ENGLISH.assign(["Pointed cat ear", "Round bear ear", "Long rabbit ear", "Floppy dog ear", "Broad elephant ear", "Large bat ear"])
	await super.run()
