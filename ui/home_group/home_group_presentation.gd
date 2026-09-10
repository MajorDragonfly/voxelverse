extends RefCounted
## Presentation only; no mutation of residents, orders or stored names.
const Text = preload("res://core/localization/ui_text.gd")
const RESULT_KEYS := {
	"home.unavailable": "HOME_UNAVAILABLE",
	"home.flat_ground_required": "HOME_FLAT_GROUND_REQUIRED",
	"home.dry_ground_required": "HOME_DRY_GROUND_REQUIRED",
	"home.insufficient_space": "HOME_INSUFFICIENT_SPACE",
	"home.obstructed": "HOME_OBSTRUCTED",
	"home.order_unavailable": "HOME_ORDER_UNAVAILABLE",
	"home.required": "HOME_REQUIRED",
	"home.member_unavailable": "HOME_MEMBER_UNAVAILABLE",
	"home.established": "HOME_ESTABLISHED",
	"home.order_saved": "HOME_ORDER_SAVED",
	"home.save_failed": "HOME_SAVE_FAILED",
	"home.invalid_record": "HOME_INVALID_RECORD",
	"home.unsupported_version": "HOME_UNSUPPORTED_VERSION",
	"home.radial_surface_required": "HOME_RADIAL_SURFACE_REQUIRED",
	"home.surface_mismatch": "HOME_SURFACE_MISMATCH",
	"home.invalid_anchor": "HOME_INVALID_ANCHOR",
	"home.invalid_members": "HOME_INVALID_MEMBERS",
	"home.invalid_member_record": "HOME_INVALID_MEMBER_RECORD",
	"home.invalid_member_order": "HOME_INVALID_MEMBER_ORDER",
	"home.invalid_member_place": "HOME_INVALID_MEMBER_PLACE",
}
const ORDER_KEYS := {"follow": "HOME_FOLLOW", "wait": "HOME_WAIT", "home": "HOME_RETURN"}

static func result_text(result: Dictionary) -> String:
	return "" if result.is_empty() else Text.format_text(RESULT_KEYS.get(result.get("code", ""), "HOME_UNAVAILABLE"), result.get("params", {}))

static func member_text(member: Dictionary) -> String:
	return Text.format_text("HOME_MEMBER_ORDER", {"name": member.name, "order": Text.text(ORDER_KEYS.get(member.order, "HOME_ORDER_UNAVAILABLE"))})

static func hud_text(distance: float, waiting: int, members: int) -> String:
	var result := Text.format_text("HOME_HUD_STATUS", {"distance": roundi(distance), "members": members})
	return result + Text.plural("HOME_HUD_WAITING", "HOME_HUD_WAITING_PLURAL", waiting) if waiting > 0 else result
