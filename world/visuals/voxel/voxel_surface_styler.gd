extends MeshInstance3D
class_name VoxelSurfaceStyler


const VOXEL_SURFACE_MATERIAL: ShaderMaterial = preload(
	"res://world/visuals/voxel/voxel_surface_material.tres"
)


@export_category("Voxel Surface")

@export_range(0, 20, 1)
var initial_delay_frames: int = 4

@export
var keep_monitoring: bool = false

@export_range(0.1, 5.0, 0.1)
var monitoring_interval: float = 0.5


@export_category("Pixel Texture")

@export
var use_pixel_texture: bool = false

@export
var voxel_texture: Texture2D

@export_range(0.25, 16.0, 0.25)
var texture_scale: float = 2.0

@export_range(2, 8, 1)
var palette_steps: int = 4


var _voxel_material: ShaderMaterial = null

var _remaining_delay_frames: int = 0
var _monitor_timer: float = 0.0
var _initial_style_applied: bool = false


func _ready() -> void:
	_remaining_delay_frames = maxi(
		initial_delay_frames,
		0
	)

	_voxel_material = (
		VOXEL_SURFACE_MATERIAL.duplicate()
		as ShaderMaterial
	)

	if _voxel_material == null:
		push_error(
			"Voxel surface material could not be duplicated."
		)

		set_process(false)
		return

	_apply_texture_parameters()

	set_process(true)


func _process(
	delta: float
) -> void:
	if _remaining_delay_frames > 0:
		_remaining_delay_frames -= 1
		return

	if not _initial_style_applied:
		if _apply_voxel_surface_material():
			_initial_style_applied = true

			if not keep_monitoring:
				set_process(false)

		return

	if not keep_monitoring:
		set_process(false)
		return

	_monitor_timer += delta

	if (
		_monitor_timer
		< maxf(
			monitoring_interval,
			0.1
		)
	):
		return

	_monitor_timer = 0.0

	if material_override != _voxel_material:
		_apply_voxel_surface_material()


func _apply_voxel_surface_material() -> bool:
	if mesh == null:
		return false

	if _voxel_material == null:
		return false

	if material_override == _voxel_material:
		return true

	var source_tint: Color = Color.WHITE

	if material_override is StandardMaterial3D:
		var source_material := (
			material_override
			as StandardMaterial3D
		)

		source_tint = (
			source_material.albedo_color
		)

	elif material_override is ShaderMaterial:
		var source_shader_material := (
			material_override
			as ShaderMaterial
		)

		var stored_tint: Variant = (
			source_shader_material
			.get_shader_parameter(
				&"object_tint"
			)
		)

		if stored_tint is Color:
			source_tint = stored_tint

	_voxel_material.set_shader_parameter(
		&"object_tint",
		source_tint
	)

	_apply_texture_parameters()

	material_override = _voxel_material

	return true


func _apply_texture_parameters() -> void:
	if _voxel_material == null:
		return

	var texture_is_available := (
		use_pixel_texture
		and voxel_texture != null
	)

	_voxel_material.set_shader_parameter(
		&"use_pixel_texture",
		texture_is_available
	)

	if voxel_texture != null:
		_voxel_material.set_shader_parameter(
			&"pixel_texture",
			voxel_texture
		)

	_voxel_material.set_shader_parameter(
		&"texture_scale",
		maxf(
			texture_scale,
			0.25
		)
	)

	_voxel_material.set_shader_parameter(
		&"palette_steps",
		float(
			clampi(
				palette_steps,
				2,
				8
			)
		)
	)
