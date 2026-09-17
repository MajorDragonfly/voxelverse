extends "res://world/surface/campaign_population.gd"
## Real population spawning against physical obstacles without campaign loading.
var fixture_body: Dictionary = {"fauna_catalog": {"species": []}}

func _ready() -> void: set_process(false)
func body() -> Dictionary: return fixture_body
