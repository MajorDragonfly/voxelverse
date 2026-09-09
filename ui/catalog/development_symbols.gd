extends RefCounted
## Code-native angular pictograms; locked variants contain a single flat silhouette.
static var _cache: Dictionary = {}

static func texture(id: String, unlocked: bool = true) -> Texture2D:
	var key := id + str(unlocked)
	if _cache.has(key):
		return _cache[key]
	var primary := "#83d6bf" if unlocked else "#080f18"
	var secondary := "#ecd2a0" if unlocked else primary
	var shape := ""
	match id:
		"creature":
			shape = '<path d="M22 57h55V43h24v29H83v19H70V76H42v15H29V73H16V48h6z"/><path fill="%s" d="M88 49h6v6h-6z"/>' % secondary
		"nest_group", "social", "approach", "support":
			shape = '<path d="M51 24h26v25H51zM44 55h40v40H44zM19 41h18v18H19zM13 65h25v30H13zM91 41h18v18H91zM90 65h25v30H90z"/>'
		"tribe", "legacy":
			shape = '<path d="M16 94L59 26h10l43 68H16z"/><path fill="%s" d="M50 94V71h28v23zM58 38h12v16H58z"/>' % secondary
		"medieval":
			shape = '<path d="M20 30h13v12h12V30h13v65H20zM70 30h13v12h12V30h13v65H70zM48 58h34v37H48z"/><path fill="%s" d="M59 76h12v19H59z"/>' % secondary
		"modern":
			shape = '<path d="M18 95V56l26-15v15l26-15v54zM78 23h18l9 72H76z"/><path fill="%s" d="M27 70h10v12H27zM48 70h10v12H48z"/>' % secondary
		"space":
			shape = '<path d="M51 82V41l13-22 13 22v41H51zM45 58L28 87h17zM83 58l17 29H83zM56 89h16l-8 22z"/><path fill="%s" d="M58 46h12v15H58z"/>' % secondary
		"hunter", "aggression":
			shape = '<path d="M28 94l12-27 48-48 18 18-49 48-29 9zM27 49l52 52-10 10-52-52z"/>'
		"endurance":
			shape = '<path d="M63 16L31 67h24l-9 45 51-64H72l8-32z"/>'
		_:
			shape = '<path d="M64 18l42 46-42 46-42-46z"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="%s">%s</g></svg>' % [primary, shape]
	var image := Image.new()
	image.load_svg_from_string(svg)
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result

static func view(id: String, unlocked: bool, extent: int = 64) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture(id, unlocked)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(extent, extent)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
