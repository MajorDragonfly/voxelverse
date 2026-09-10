extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void: root.add_child(load("res://tools/egg_species_campaign_probe.gd").new())
