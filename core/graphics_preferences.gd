extends RefCounted
## Presentation preferences only; independent of campaigns and weather simulation.
const SCHEMA := 1
const CUSTOM := 3
const FIELDS := {
	"clouds_enabled": {"default": true},
	"cloud_quality": {"default": 1, "min": 0, "max": 2},
	"haze_strength": {"default": 1.0, "min": 0.0, "max": 2.0},
	"fog_enabled": {"default": false},
	"fog_quality": {"default": 1, "min": 0, "max": 2},
	"fog_strength": {"default": 1.0, "min": 0.0, "max": 2.0},
	"shadows_enabled": {"default": true},
	"shadow_quality": {"default": 1, "min": 0, "max": 2},
	"shadow_softness": {"default": 0.6, "min": 0.0, "max": 2.0},
	"shadow_distance": {"default": 220.0, "min": 50.0, "max": 500.0},
	"ssao_enabled": {"default": true},
	"ssao_quality": {"default": 1, "min": 0, "max": 2},
	"ssao_strength": {"default": 0.9, "min": 0.0, "max": 2.0},
	"bloom_enabled": {"default": true},
	"bloom_strength": {"default": 0.16, "min": 0.0, "max": 0.8},
	"exposure": {"default": 1.0, "min": 0.5, "max": 1.5},
	"contrast": {"default": 1.0, "min": 0.75, "max": 1.25},
	"saturation": {"default": 1.0, "min": 0.0, "max": 1.5},
}

static func preset(index: int) -> Dictionary:
	var result: Dictionary = {}
	for key: String in FIELDS:
		result[key] = FIELDS[key].default
	if index == 0:
		for key: String in ["cloud_quality", "fog_quality", "shadow_quality", "ssao_quality"]:
			result[key] = 0
		result.ssao_enabled = false
		result.bloom_enabled = false
		result.shadow_softness = 0.0
	elif index == 2:
		for key: String in ["cloud_quality", "fog_quality", "shadow_quality", "ssao_quality"]:
			result[key] = 2
		result.fog_enabled = true
		result.shadow_distance = 300.0
	return result

static func normalize(raw: Variant, fallback: int = 1) -> Dictionary:
	var result := preset(fallback)
	if not raw is Dictionary:
		return result
	for key: String in FIELDS:
		var value: Variant = raw.get(key, result[key])
		var rule: Dictionary = FIELDS[key]
		if rule.default is bool:
			if value is bool: result[key] = value
		elif (value is int or value is float) and is_finite(float(value)):
			var bounded: float = clampf(float(value), float(rule.min), float(rule.max))
			result[key] = int(bounded) if rule.default is int else bounded
	return result

static func supported(key: String, renderer: String) -> bool:
	if key.begins_with("fog_") or key.begins_with("ssao_") or key.begins_with("bloom_"):
		return renderer == "forward_plus"
	# Godot's angular-distance soft shadows require Forward+ or Mobile.
	return key != "shadow_softness" or renderer != "gl_compatibility"

static func apply_renderer(values: Dictionary) -> void:
	# The display autoload is the sole owner of these process-wide quality settings.
	var q: int = values.shadow_quality
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][q], true)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility": return
	RenderingServer.directional_soft_shadow_filter_set_quality([
		RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])
	if RenderingServer.get_current_rendering_method() != "forward_plus": return
	q = values.ssao_quality
	RenderingServer.environment_set_ssao_quality([
		RenderingServer.ENV_SSAO_QUALITY_LOW, RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		RenderingServer.ENV_SSAO_QUALITY_HIGH][q], q == 0, 0.5, 2, 50.0, 300.0)
	q = values.fog_quality
	RenderingServer.environment_set_volumetric_fog_volume_size([32, 64, 128][q], [32, 64, 128][q])
	RenderingServer.environment_set_volumetric_fog_filter_active(true)

static func apply_image(environment: Environment, values: Dictionary, exposure_scale: float = 1.0) -> void:
	environment.tonemap_exposure = float(values.exposure) * exposure_scale
	environment.adjustment_enabled = true
	environment.adjustment_contrast = values.contrast
	environment.adjustment_saturation = values.saturation
