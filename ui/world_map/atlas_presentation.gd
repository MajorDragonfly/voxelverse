extends RefCounted
## Read-only map presentation. Never rewrite saved place names or fog records.
const Text = preload("res://core/localization/ui_text.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const PROBLEM_KEYS := {
	"atlas.collection_full": "ATLAS_BODY_COLLECTION_FULL",
	"atlas.invalid_record": "ATLAS_INVALID_RECORD",
	"atlas.surface_mismatch": "ATLAS_SURFACE_MISMATCH",
}

static func problem_text(code: String) -> String:
	return Text.text(PROBLEM_KEYS.get(code, "ATLAS_UNAVAILABLE"))

static func place_name(place: Dictionary) -> String:
	var title: String = str(place.get("name", ""))
	var address: Dictionary = place.get("address", {})
	var body_id: String = str(address.get("body_id", ""))
	var id: String = str(place.get("id", ""))
	# Translate only the built-in providers' reserved identities AND templates.
	# Arbitrary provider/user names (even translation keys) stay literal.
	if place.get("own", false):
		if place.get("kind") == "nest" and title == "Eigenes Nest":
			var nest_id := body_id + ":nest"
			if address.get("mode") == "legacy_plane_v9":
				var point: Array = address.get("position", [0, 0, 0])
				nest_id = Ids.scoped("place", body_id, "player_nest:%d:%d" % [roundi(point[0]), roundi(point[2])])
			if id == nest_id: return Text.text("ATLAS_OWN_NEST")
		if place.get("kind") == "home" and title == "Heimat deiner Spezies" and id == Ids.scoped("group", body_id, str(place.get("species_id", "")) + ":home"):
			return Text.text("ATLAS_SPECIES_HOME")
	elif place.get("kind") == "friend_habitat" and not str(place.get("object_id", "")).is_empty() and id == str(place.object_id) + ":habitat":
		if title == "Befreundete Kreatur · Lebensraum": return Text.text("ATLAS_FRIEND_HABITAT")
		if title.ends_with(" · Lebensraum"):
			return Text.format_text("ATLAS_NAMED_HABITAT", {"name": title.trim_suffix(" · Lebensraum")})
	return title

static func distance_text(meters: float) -> String:
	return Text.format_text("ATLAS_DISTANCE_M", {"distance": roundi(meters)}) if meters < 1000.0 else Text.format_text("ATLAS_DISTANCE_KM", {"distance": Text.number(meters / 1000.0, 1)})

static func scale_text(meters: float, spherical: bool) -> String:
	return Text.format_text("ATLAS_EQUATOR_WIDTH" if spherical else "ATLAS_WIDTH", {"distance": distance_text(meters)})

static func detail_text(place: Dictionary = {}, full: bool = false) -> String:
	if full: return Text.text("ATLAS_COLLECTION_FULL")
	if place.is_empty(): return Text.text("ATLAS_UNEXPLORED")
	return Text.format_text("ATLAS_OWN_DETAIL" if place.own else "ATLAS_FRIEND_DETAIL", {"name": place_name(place)})
