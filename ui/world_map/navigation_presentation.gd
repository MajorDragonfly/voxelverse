extends RefCounted
## Guidance reads the physical explorer and current D2 projection, never camera
## focus or a cached animal position stored alongside a navigation target.
const Map = preload("res://ui/world_map/atlas_presentation.gd")
const MapProjection = preload("res://core/map/surface_map_projection.gd")
const Text = preload("res://core/localization/ui_text.gd")

static func origin(data: Dictionary) -> Dictionary:
	var explorers: Array = data.get("explorers", [])
	if data.get("group_view", false):
		for marker: Dictionary in data.get("markers", []):
			if marker.get("kind") == "resident" and marker.get("selected", false) and marker.get("address") in explorers:
				return marker.address
	return explorers[0] if not explorers.is_empty() else {}

static func name_of(target: Dictionary) -> String:
	if target.get("kind") == "owned_animal" and str(target.get("name", "")).is_empty(): return Text.text("NAV_ANIMAL_UNNAMED")
	return Map.place_name(target)

static func distance_to(target: Dictionary, address: Dictionary, radius: float) -> float:
	var local := MapProjection.new()
	if not local.configure(address, radius): return -1.0
	var offset: Vector2 = local.project(target.get("address", {}))
	return offset.length() if offset.is_finite() else PI * radius

static func guidance(target: Dictionary, distance: float) -> String:
	var key: String = "NAV_ARRIVED" if distance <= 6.0 else "NAV_GUIDANCE"
	if target.get("kind") == "owned_animal" and not target.get("live", false): key = "NAV_ANIMAL_LAST_GUIDANCE"
	return Text.format_text(key, {"name": name_of(target), "distance": Map.distance_text(distance)})

static func animal_detail(target: Dictionary, address: Dictionary, radius: float) -> String:
	if target.is_empty(): return Text.text("NAV_ANIMAL_UNAVAILABLE")
	var status: String = Text.text("NAV_ANIMAL_LIVE" if target.get("live", false) else "NAV_ANIMAL_LAST_KNOWN")
	var distance: float = distance_to(target, address, radius)
	return status if distance < 0.0 else status + " · " + Map.distance_text(distance)
