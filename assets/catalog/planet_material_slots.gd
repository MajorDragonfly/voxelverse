extends RefCounted

# Append only. GLB UV.x encodes (slot_index + 0.5) / TEXTURE_WIDTH.
const TEXTURE_WIDTH: int = 32
const NAMES: Array[String] = [
	"foliage_highlight", "foliage_base", "foliage_shadow", "foliage_deep",
	"bark_highlight", "bark_base", "bark_shadow",
	"ground_base", "ground_shadow", "ground_dry",
	"flower_primary", "flower_accent", "rock_light", "rock_base", "rock_dark",
	"coast", "water_shallow", "water_deep", "ground_highlight", "soil_base",
	"shrub_base", "shrub_highlight", "shrub_shadow",
]


static func validate(slots: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in NAMES:
		var value: Variant = slots.get(key)
		if not value is Color:
			errors.append("Missing Color material slot: %s" % key)
			continue
		var color: Color = value
		if not color.is_equal_approx(color.clamp()) or not is_finite(color.r + color.g + color.b + color.a):
			errors.append("Invalid material slot: %s" % key)
	return errors


static func create_texture(slots: Dictionary) -> ImageTexture:
	return create_atlas([slots])


static func create_atlas(palettes: Array[Dictionary]) -> ImageTexture:
	var image := Image.create(TEXTURE_WIDTH, maxi(palettes.size(), 1), false, Image.FORMAT_RGBA8)
	image.fill(Color.MAGENTA)
	for row in range(palettes.size()):
		for index in range(NAMES.size()):
			image.set_pixel(index, row, palettes[row].get(NAMES[index], Color.MAGENTA))
	return ImageTexture.create_from_image(image)
