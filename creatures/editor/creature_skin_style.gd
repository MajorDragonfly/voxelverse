extends RefCounted
## Cosmetic surface detail. No displacement, extra geometry or gameplay stats.

const TYPES: Dictionary = {"smooth": "Glatt", "scales": "Schuppen", "fur": "Kurzes Fell", "leather": "Leder", "chitin": "Chitin"}
const SWATCHES: Array[String] = ["f3ead6", "d7c39e", "a57952", "62402e", "252c30", "10151e", "b9dbab", "73b696", "318f71", "204d46", "d7df6a", "9eac42", "f6cf67", "e99748", "c9513b", "883545", "e9b4b9", "ca719c", "92569b", "574578", "a3d9dc", "53a8bf", "326b9e", "263a68"]
const PALETTES: Array[Dictionary] = [
	{"name": "Wald", "base_color": "73b696", "accent_color": "244e46", "belly_color": "d4dfac", "eye_color": "d99a37", "horn_color": "eee1bd"},
	{"name": "Wüste", "base_color": "cfa86a", "accent_color": "704b39", "belly_color": "f1dbad", "eye_color": "448e9c", "horn_color": "e5dcc8"},
	{"name": "Ozean", "base_color": "548faf", "accent_color": "233c6e", "belly_color": "c5e7dc", "eye_color": "eebc58", "horn_color": "dddfe5"},
	{"name": "Glut", "base_color": "c75b45", "accent_color": "512f43", "belly_color": "e5b676", "eye_color": "ebd966", "horn_color": "24262f"},
	{"name": "Dämmerung", "base_color": "987bb4", "accent_color": "413d6e", "belly_color": "dcc5d1", "eye_color": "8ed2ac", "horn_color": "ece4d4"},
	{"name": "Polar", "base_color": "d4e4dd", "accent_color": "667e90", "belly_color": "f2ead8", "eye_color": "4eadd0", "horn_color": "424956"},
]
static var _textures: Dictionary = {}


static func normalize(blueprint: Dictionary) -> void:
	var appearance: Dictionary = blueprint.get("appearance", {}) if blueprint.get("appearance", {}) is Dictionary else {}
	var kind: String = str(appearance.get("skin_type", "smooth"))
	appearance["skin_type"] = kind if TYPES.has(kind) else "smooth"
	appearance["skin_strength"] = clampf(float(appearance.get("skin_strength", 0.65)), 0.0, 1.0)
	appearance["skin_scale"] = clampf(float(appearance.get("skin_scale", 1.0)), 0.4, 2.5)
	blueprint["appearance"] = appearance


static func color(blueprint: Dictionary, key: String, fallback: Color) -> Color:
	return Color.from_string(str(blueprint.get("appearance", {}).get(key, fallback.to_html(false))), fallback)


static func apply(material: StandardMaterial3D, blueprint: Dictionary) -> void:
	var appearance: Dictionary = blueprint.get("appearance", {})
	var kind: String = str(appearance.get("skin_type", "smooth"))
	var strength: float = clampf(float(appearance.get("skin_strength", 0.65)), 0.0, 1.0)
	if kind == "smooth" or not TYPES.has(kind) or strength <= 0.001:
		return
	# A small grayscale tile multiplies the authored skin color. Triplanar
	# projection keeps the pattern continuous across the six voxel face axes.
	material.albedo_texture = texture(kind, snappedf(strength, 0.05))
	material.uv1_triplanar = true
	material.uv1_triplanar_sharpness = 8.0
	material.uv1_scale = Vector3.ONE * 3.0 * clampf(float(appearance.get("skin_scale", 1.0)), 0.4, 2.5)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


static func texture(kind: String, strength: float) -> ImageTexture:
	var key: String = "%s:%.2f" % [kind, strength]
	if _textures.has(key):
		return _textures[key]
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var grain: float = float(posmod(x * 37 + y * 67 + x * y * 13, 19)) / 18.0
			var mark: float = 0.0
			match kind:
				"scales":
					var row: int = y / 8
					var u: float = float(posmod(x + (row % 2) * 4, 8)) - 3.5
					var v: float = float(y % 8) - 1.0
					mark = 0.55 if absf(sqrt(u * u + v * v) - 5.0) < 0.8 else 0.06 * grain
				"fur":
					var strand: int = posmod(x + y / 3 + (y / 16) * 3, 8)
					mark = (0.45 if strand < 2 else 0.05) * (0.55 + grain * 0.45)
				"leather":
					mark = 0.20 * grain + (0.24 if posmod(x * 3 + y * 5, 23) == 0 else 0.0)
				"chitin":
					mark = 0.50 if y % 16 < 2 or posmod(x + (y / 16) * 8, 16) < 1 else 0.05 * grain
			image.set_pixel(x, y, Color.WHITE.darkened(mark * strength))
	var result: ImageTexture = ImageTexture.create_from_image(image)
	if _textures.size() >= 32:
		_textures.clear()
	_textures[key] = result
	return result
