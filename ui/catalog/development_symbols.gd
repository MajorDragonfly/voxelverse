extends RefCounted
## Development keeps its unlocked/locked API while sharing the Expedition family.
## A locked chapter is a quiet single-tone pictogram, never an invented unlock.

const Design = preload("res://ui/design/design_system.gd")
const Family = preload("res://ui/design/game_symbols.gd")
const ALIASES := {"legacy": "tribe", "teamwork": "workers", "practice": "support"}


static func texture(id: String, unlocked: bool = true) -> Texture2D:
	return Family.texture(str(ALIASES.get(id, id)), Design.ACCENT if unlocked else Design.MUTED, 128)


static func view(id: String, unlocked: bool, extent: int = 64) -> TextureRect:
	var result := Family.view(str(ALIASES.get(id, id)), extent, Design.ACCENT if unlocked else Design.MUTED)
	return result
