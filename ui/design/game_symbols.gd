extends RefCounted
## Original game pictograms. Real SVG silhouettes, never emoji or font glyphs.
## Render once per tint and reuse across menus, HUD and field journals.

const Design := preload("res://ui/design/design_system.gd")

const SHAPES := {
	"play": '<path d="m15 9 24 15-24 15z"/><path d="M8 10v28" fill="none"/>',
	"new_game": '<path d="M6 38 15 17l7 10 7-18 13 29z"/><path d="M35 4v12m-6-6h12" fill="none"/>',
	"save": '<path d="M7 5h30l5 6v31H7z" fill="none"/><path d="M14 5h19v12H14zM14 28h21v14H14z" fill="none"/><path d="M28 7v7" fill="none"/>',
	"settings": '<path d="m20 5 8 0 2 6 5 2 6-1 4 7-4 5 0 5 4 5-4 7-6-1-5 2-2 6h-8l-2-6-5-2-6 1-4-7 4-5v-5l-4-5 4-7 6 1 5-2z" fill="none"/><circle cx="24" cy="26" r="7" fill="none"/>',
	"controls": '<path d="M12 15h24c6 0 10 19 6 23-3 3-8-4-11-7H17c-3 3-8 10-11 7-4-4 0-23 6-23z" fill="none"/><path d="M15 21v10m-5-5h10" fill="none"/><circle cx="32" cy="23" r="2"/><circle cx="37" cy="28" r="2"/>',
	"quit": '<path d="M25 4v20M14 10a18 18 0 1 0 22 0" fill="none"/>',
	"back": '<path d="m20 10-14 14 14 14M6 24h35" fill="none"/>',
	"close": '<path d="m12 12 24 24m0-24L12 36" fill="none"/>',
	"book": '<path d="M5 8c8-3 14-2 19 2 5-4 11-5 19-2v30c-8-3-14-2-19 2-5-4-11-5-19-2z" fill="none"/><path d="M24 10v30m-12-23h6m-6 7h6m12-7h6m-6 7h6" fill="none"/>',
	"journal": '<path d="M11 5h28v38H11z" fill="none"/><path d="M6 12h9M6 22h9M6 32h9m8-21h8m-8 7h8m-8 7h8" fill="none"/><path d="m30 31 8-8 4 4-8 8-5 1z"/>',
	"map": '<path d="m4 10 13-5 14 5 13-5v32l-13 6-14-5-13 5z" fill="none"/><path d="M17 5v33m14-28v33M8 26l5-9 10 12 7-7 9 9" fill="none"/>',
	"creature": '<path d="M9 29c-3-5-2-14 3-17l1-7 8 5h9l8-5 1 8c5 5 5 13 0 17l-5 3-3 9h-6l-1-9-4 9h-6l-1-10z" fill="none"/><circle cx="16" cy="19" r="2"/><circle cx="32" cy="19" r="2"/><path d="m22 25 3 3 3-3" fill="none"/>',
	"tribe": '<path d="m5 38 19-30 19 30z" fill="none"/><path d="m20 6 15 34M28 6 13 40M19 38l5-11 5 11" fill="none"/><path d="M3 42h42" fill="none"/>',
	"medieval": '<path d="M7 42V14h5V7h5v7h5V7h5v7h5V7h5v7h5v28z" fill="none"/><path d="M19 42V29a5 5 0 0 1 10 0v13M13 20v5m22-5v5" fill="none"/>',
	"modern": '<path d="M5 41V23l13-8v8l13-8v8h12v18zM34 23V6h7v17" fill="none"/><path d="M11 31h5m7 0h5m7 0h4M11 36h5m7 0h5m7 0h4" fill="none"/>',
	"space": '<path d="M24 4c9 7 12 17 9 28H15C12 21 15 11 24 4z" fill="none"/><path d="m15 22-8 10v9l9-8m17-11 8 10v9l-9-8M20 36l4 9 4-9" fill="none"/><circle cx="24" cy="19" r="4" fill="none"/>',
	"wood": '<path d="m11 10 30 9v18l-30-9z" fill="none"/><ellipse cx="11" cy="19" rx="7" ry="9" fill="none"/><ellipse cx="11" cy="19" rx="3" ry="5" fill="none"/><path d="m21 17 14 4m-14 5 14 4" fill="none"/>',
	"stone": '<path d="m4 32 7-18 17-7 15 15-6 18-24 3z" fill="none"/><path d="m11 14 12 13 20-5M23 27l-10 16m10-16 14 13" fill="none"/>',
	"food": '<path d="M24 43V19C9 19 5 12 5 5c12 0 19 5 19 14 0-9 7-14 19-14 0 7-4 14-19 14" fill="none"/><path d="M24 33c-12 0-17-6-17-13 11 0 17 5 17 13 0-8 6-13 17-13 0 7-5 13-17 13" fill="none"/>',
	"water": '<path d="M24 4C20 13 9 21 9 30a15 15 0 0 0 30 0c0-9-11-17-15-26z" fill="none"/><path d="M15 30c0 6 3 8 7 9" fill="none"/>',
	"health": '<path d="M24 41 7 25C-2 11 14 2 24 15 34 2 50 11 41 25z" fill="none"/><path d="M9 24h10l4-8 5 15 4-7h8" fill="none"/>',
	"stamina": '<path d="m26 3-18 24h14l-2 18 20-26H26z"/>',
	"tools": '<path d="m8 39 23-23m-9-8 4-4 17 11-5 7-16-10zM5 36l6 6" fill="none"/><path d="m10 8 6 6 18 23-5 5-18-24-6-6z" fill="none"/>',
	"house": '<path d="m3 22 21-17 21 17M8 19v23h32V19M20 42V29h9v13" fill="none"/><path d="M11 10V5h6v2m-3 20h2m17 0h2" fill="none"/>',
	"workers": '<circle cx="24" cy="13" r="6" fill="none"/><circle cx="8" cy="19" r="4" fill="none"/><circle cx="40" cy="19" r="4" fill="none"/><path d="M14 41V31c0-11 20-11 20 0v10M2 39v-9c0-6 8-6 10-3m34 12v-9c0-6-8-6-10-3" fill="none"/>',
	"search": '<circle cx="20" cy="20" r="13" fill="none"/><path d="m30 30 13 13" fill="none"/>',
	"filter": '<path d="M4 8h40L29 25v15l-10 4V25z" fill="none"/>',
	"build": '<path d="M5 42h38M10 42V16l13-9 15 9v26M10 22h28M10 32h28M17 22v10m14 0v10m-7-10v-10" fill="none"/><path d="m4 16 19-13 21 13" fill="none"/>',
	"craft": '<path d="M6 30h36l-5 6H11zM15 36v7m18-7v7m-9-36v20m-7-22h15v8H17z" fill="none"/><path d="m6 17 4-4m29 0 4 4" fill="none"/>',
	"social": '<path d="M4 10h29v19H18l-9 7v-7H4zM33 17h11v22h-5v6l-9-6H20v-6" fill="none"/><circle cx="12" cy="20" r="1.5"/><circle cx="20" cy="20" r="1.5"/><circle cx="28" cy="20" r="1.5"/>',
	"aggression": '<path d="m34 4 10 0 0 10-24 24-10-10zM6 27l15 15M6 42l7-7" fill="none"/><path d="m17 31 21-21" fill="none"/>',
	"warning": '<path d="M24 5 45 42H3z" fill="none"/><path d="M24 17v13" fill="none"/><circle cx="24" cy="36" r="2"/>',
	"check": '<path d="m7 24 11 11L41 12" fill="none"/>',
	"lock": '<path d="M10 21h28v22H10zM16 21v-9a8 8 0 0 1 16 0v9" fill="none"/><circle cx="24" cy="30" r="3"/><path d="M24 30v6" fill="none"/>',
	"nest": '<path d="M4 28c5 15 35 15 40 0M6 32l36-5M8 37l34-4M13 40l28-2M4 27l8-4m24 0 8 4" fill="none"/><ellipse cx="19" cy="22" rx="6" ry="9" fill="none"/><ellipse cx="30" cy="24" rx="5" ry="8" fill="none"/>',
	"fleet": '<path d="M7 30h34l-7 10H14zM24 6v24M24 6 8 25h16zM28 12l11 13H28z" fill="none"/><path d="M3 44c4-4 8-4 12 0 4-4 8-4 12 0 4-4 8-4 12 0 3-3 4-3 6-3" fill="none"/>',
	"sun": '<circle cx="24" cy="24" r="9" fill="none"/><path d="M24 3v6m0 30v6M3 24h6m30 0h6M9 9l5 5m20 20 5 5M9 39l5-5m20-20 5-5" fill="none"/>',
	"copy": '<path d="M17 16h25v27H17zM31 16V5H6v27h11" fill="none"/>',
	"rename": '<path d="m7 32 25-25 9 9-25 25-12 3zM27 12l9 9M7 32l9 9" fill="none"/>',
	"history": '<path d="M8 17a18 18 0 1 1-1 16M8 5v12H20M24 12v12l9 6" fill="none"/>',
	"right": '<path d="m18 8 16 16-16 16" fill="none"/>',
	"left": '<path d="m30 8-16 16 16 16" fill="none"/>',
	"globe": '<circle cx="24" cy="24" r="19" fill="none"/><ellipse cx="24" cy="24" rx="9" ry="19" fill="none"/><path d="M6 17h36M6 31h36M5 24h38" fill="none"/>',
	"shield": '<path d="M24 4 42 11v14c-1 9-9 15-18 20C15 40 7 34 6 25V11z" fill="none"/><path d="M24 11v25m-10-17h20" fill="none"/>',
	"recovery": '<path d="M8 16a17 17 0 1 1-1 15M8 5v11h11M24 17v14m-7-7h14" fill="none"/>',
	"berries": '<path d="m24 18-2-13m2 13 11-11M22 6l-8-1" fill="none"/><circle cx="15" cy="24" r="8" fill="none"/><circle cx="31" cy="24" r="8" fill="none"/><circle cx="23" cy="37" r="8" fill="none"/><circle cx="12" cy="22" r="1.5"/><circle cx="28" cy="22" r="1.5"/><circle cx="21" cy="35" r="1.5"/>',
	"meat": '<path d="M12 10C27-1 44 9 42 23c-1 9-10 18-21 17-9-1-16-9-12-17z" fill="none"/><path d="M17 13c10-5 19 1 18 10-1 6-6 11-12 10-6-1-9-6-6-12z" fill="none"/><circle cx="25" cy="24" r="4" fill="none"/>',
	"swim": '<circle cx="26" cy="10" r="4" fill="none"/><path d="m7 25 12-9 11 4 11 9M19 16l5 13M3 33c4-5 9-5 13 0 4-5 9-5 13 0 4-5 9-5 16 0M3 42c4-5 9-5 13 0 4-5 9-5 13 0 4-5 9-5 16 0" fill="none"/>',
	"speed": '<path d="M7 35a19 19 0 1 1 34 0M24 28l13-14M8 27h5m22 0h5M13 13l4 4m7-11v6M14 42h20" fill="none"/><circle cx="24" cy="28" r="3"/>',
	"scan": '<circle cx="24" cy="24" r="18" fill="none"/><circle cx="24" cy="24" r="10" fill="none"/><path d="M24 24 36 11M24 6v8M6 24h8m10 10v8m10-18h8" fill="none"/><circle cx="24" cy="24" r="2"/>',
	"approach": '<path d="M6 30h22M20 22l8 8-8 8" fill="none"/><circle cx="35" cy="10" r="5" fill="none"/><path d="M27 22c0-8 16-8 16 0v20M35 22v20" fill="none"/>',
	"support": '<path d="M4 31h7l9 7h14l9-10-5-4-8 6H18M4 24h7l9 7h10M4 22v18" fill="none"/><path d="M24 22 14 13c-5-7 5-12 10-5 5-7 15-2 10 5z" fill="none"/>',
	"hunter": '<path d="M12 4c30 10 30 30 0 40V4M8 24h35M35 17l8 7-8 7" fill="none"/>',
	"endurance": '<path d="M14 43V28l6-8-1-8 6-5 7 2 2 9-5 8v8l-6 9z" fill="none"/><path d="m6 26 5-10m28 10 4-10M3 37h5m30 0h7" fill="none"/>',
	"part": '<path d="m9 6 26 3 4 20-7 14-10-4-2-13-9-7z" fill="none"/><path d="m22 26 8-6 9 9M11 19l11-8m0 28 10-9" fill="none"/>',
	"research": '<path d="M18 4h12m-10 0v14L7 38c-2 4 1 6 5 6h24c4 0 7-2 5-6L28 18V4M14 29h20" fill="none"/><circle cx="23" cy="35" r="2"/><circle cx="30" cy="39" r="1.5"/>',
	"pin": '<path d="M24 44C20 35 10 28 10 19a14 14 0 0 1 28 0c0 9-10 16-14 25z" fill="none"/><circle cx="24" cy="19" r="5" fill="none"/>',
	"star": '<path d="m24 4 6 13 14 2-10 10 2 15-12-7-12 7 2-15L4 19l14-2z" fill="none"/>',
	"compare": '<path d="M8 12h32M24 5v35M16 43h16M8 12 2 28h12zM40 12 34 28h12z" fill="none"/>',
	"jump": '<path d="M8 42h32M12 35c-5-21 18-29 27-12M30 22l9 1 2-9" fill="none"/><path d="m17 32 9-4 6 6-9 3z"/>',
	"perception": '<path d="M3 24c12-19 30-19 42 0-12 19-30 19-42 0z" fill="none"/><circle cx="24" cy="24" r="8" fill="none"/><circle cx="24" cy="24" r="3"/>',
	"grip": '<path d="M10 37V20c0-4 5-4 5 0v5-14c0-4 5-4 5 0v11-16c0-4 5-4 5 0v16-12c0-4 5-4 5 0v18l5-9c2-4 7-2 6 2l-7 18-5 6H16z" fill="none"/>',
	"flight": '<path d="M24 30C15 15 7 10 3 10c0 15 5 25 15 28l6-8 6 8c10-3 15-13 15-28-4 0-12 5-21 20z" fill="none"/><path d="m6 19 12 10M8 28l9 7m25-16L30 29m10-1-9 7" fill="none"/>',
	"hunger_drain": '<path d="M15 4v13M6 4v10c0 6 18 6 18 0V4M15 19v24M34 5v21h8V5c-7 1-8 9-8 21m8 0v17" fill="none"/><path d="M24 29v12m-5-5 5 5 5-5" fill="none"/>',
	"gallery": '<path d="M5 10h38v30H5zM12 40v5m24-5v5M16 4h16M24 4v6m-13 24 9-12 8 9 5-5 6 8" fill="none"/><circle cx="33" cy="18" r="3" fill="none"/>',
	"import": '<path d="M24 4v25m-10-10 10 10 10-10M7 25v18h34V25M7 36h34" fill="none"/>',
	"export": '<path d="M24 29V4M14 14 24 4l10 10M7 25v18h34V25M7 36h34" fill="none"/>',
	"delete": '<path d="M6 11h36M18 11V5h12v6M11 11l3 32h20l3-32M20 19v16m8-16v16" fill="none"/>',
	"palette": '<path d="M26 5C11 3 1 18 7 32c6 13 22 15 23 6 0-4-8-4-4-9 3-3 13 3 16-3 4-8-5-19-16-21z" fill="none"/><circle cx="15" cy="16" r="3"/><circle cx="26" cy="13" r="3"/><circle cx="35" cy="19" r="3"/><circle cx="12" cy="28" r="3"/>',
	"undo": '<path d="M7 22h22a12 12 0 1 1 0 24M17 10 5 22l12 12" fill="none"/>',
	"redo": '<path d="M41 22H19a12 12 0 1 0 0 24M31 10l12 12-12 12" fill="none"/>',
	"pause": '<path d="M12 7h8v34h-8zM28 7h8v34h-8z"/>',
	"speaker": '<path d="M5 17h9L26 6v36L14 31H5zM32 15c7 6 7 12 0 18m6-26c13 10 13 24 0 34" fill="none"/>',
	"music": '<path d="M18 35V10l24-6v25M18 17l24-6" fill="none"/><ellipse cx="11" cy="37" rx="7" ry="5"/><ellipse cx="35" cy="31" rx="7" ry="5"/>',
	"leaf": '<path d="M8 40C-1 20 18 3 43 5c1 25-14 42-35 35zM8 40 34 14m-16 15 15 1M23 24l-1-12" fill="none"/>',
	"fiber": '<path d="M11 7h26v5H11zM11 36h26v5H11zM16 12v24m16-24v24M16 17l16 5-16 5 16 5" fill="none"/><path d="M32 27c10-1 8 13 15 15" fill="none"/>',
	"milk": '<path d="M19 4h10v9l6 9v20H13V22l6-9zM13 25h22m-16-12h10" fill="none"/>',
	"egg": '<path d="M24 4C18 4 8 22 8 31a16 16 0 0 0 32 0C40 22 30 4 24 4z" fill="none"/><path d="m14 29 5-4 5 6 6-3 5 5" fill="none"/>',
	"route": '<circle cx="8" cy="8" r="4" fill="none"/><circle cx="40" cy="40" r="4" fill="none"/><path d="M12 8h12c13 0 13 15 1 15h-6c-12 0-12 17 1 17h16" fill="none"/>',
}

const ALIASES := {
	"continue": "play", "create": "new_game", "new": "new_game", "world": "globe",
	"forward": "right", "development": "book", "thirst": "water", "attack": "aggression",
	"defense": "shield", "diet_plant": "food", "diet_meat": "meat", "nest_group": "nest",
	"population": "workers", "equipment": "tools", "flint": "stone", "residents": "workers",
	"favorite": "star", "next": "right", "building": "house", "resume": "play",
	"eggs": "egg", "tool": "tools",
}

static var _textures: Dictionary = {}


static func texture(id: String, tone: Color = Design.ACCENT, extent: int = 24) -> Texture2D:
	var key_id: String = str(ALIASES.get(id, id))
	if not SHAPES.has(key_id):
		key_id = "warning"
	var pixels := maxi(extent, 1)
	var key := key_id + ":" + tone.to_html() + ":" + str(pixels)
	if _textures.has(key):
		return _textures[key] as Texture2D
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 48 48"><g fill="#%s" stroke="#%s" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" opacity="%s">%s</g></svg>' % [str(pixels), str(pixels), tone.to_html(false), tone.to_html(false), str(tone.a), SHAPES[key_id]]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	var result := ImageTexture.create_from_image(image)
	_textures[key] = result
	return result


static func view(id: String, extent: int = 28, tone: Color = Design.ACCENT) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture(id, tone, maxi(48, extent * 2))
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(extent, extent)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func apply(button: Button, id: String, extent: int = 24) -> void:
	button.icon = texture(id, Design.ACCENT, extent * 2)
	# Reserve the symbol at minimum width, including in wrapping toolbars.
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", extent)
	button.add_theme_constant_override("h_separation", 12)
