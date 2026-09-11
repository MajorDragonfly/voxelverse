extends "res://world/surface/campaign_population.gd"
## Real population storage/service ports without terrain or rendered actors.
func _ready() -> void:
	if not body().has("surface_population"): body().surface_population = Model.create(descriptor.id)
	if not storage.open(self, descriptor): _storage_failed(); return
	add_to_group(&"campaign_surface_population")
	get_node("/root/SaveGameService").save_started.connect(capture)
	set_process(false)

func _storage_failed() -> void:
	# The headless fixture has no SessionFlow loading screen. Keep the real
	# shared-writer protection and expose the error to assertions instead.
	storage_error = storage.store.last_error
	get_node("/root/SaveGameService")._write_blocked = true
