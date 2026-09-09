extends RefCounted
class_name CampaignIds

## IDs are opaque identities. Seeds, names and catalogue indices are not IDs.
static func create(kind: String) -> String:
	return kind + "_" + Crypto.new().generate_random_bytes(16).hex_encode()


## Only for reproducible migration/procedural identity within an explicit owner.
static func scoped(kind: String, owner_id: String, legacy_key: String) -> String:
	return kind + "_" + JSON.stringify([owner_id, legacy_key]).sha256_text().left(32)


static func ensure_design(blueprint: Dictionary, legacy_key: String = "") -> void:
	if str(blueprint.get("design_id", "")).is_empty():
		blueprint["design_id"] = create("design") if legacy_key.is_empty() else scoped("design", "legacy-design-v1", legacy_key)
