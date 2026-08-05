@tool
class_name SurfaceDefinition
extends Resource

const GENERIC_OBJECT_SHADER := preload(
	"res://map_editor/generic_object_wall_shader.gdshader")
const DEFAULT_BLOOD_NOISE_TEXTURE := preload(
	"res://content/fx/blood_noise_texture.tres")

@export_group("Identity")
@export var id: StringName:
	set(value): id = value; emit_changed()
@export var display_name: String:
	set(value): display_name = value; emit_changed()
@export var thumbnail: Texture2D:
	set(value): thumbnail = value; emit_changed()

@export_group("Material - Base")
@export var albedo: Texture2D:
	set(value): albedo = value; emit_changed()
@export var modulate := Color.WHITE:
	set(value): modulate = value; emit_changed()
@export var texture_aoe: Texture2D:
	set(value): texture_aoe = value; emit_changed()
@export_range(0.0, 1.0, 0.01) var metallic := 0.0:
	set(value): metallic = value; emit_changed()
@export_range(0.0, 1.0, 0.01) var specular := 0.5:
	set(value): specular = value; emit_changed()
@export_range(0.0, 1.0, 0.01) var roughness := 0.8:
	set(value): roughness = value; emit_changed()
@export_range(0.0, 1.0, 0.001) var random_hue := 0.0:
	set(value): random_hue = value; emit_changed()

@export_group("Material - Detail")
@export_range(0.0, 1.0, 0.01) var detail := 0.0:
	set(value): detail = value; emit_changed()
@export var texture_detail: Texture2D:
	set(value): texture_detail = value; emit_changed()
@export var detail_uv_scale := Vector2.ONE:
	set(value): detail_uv_scale = value; emit_changed()

@export_group("Material - Tiles")
@export var tile_size := Vector2.ZERO:
	set(value): tile_size = value; emit_changed()
@export var tile_bricks := false:
	set(value): tile_bricks = value; emit_changed()
@export var tile_seam_thickness := Vector2.ZERO:
	set(value): tile_seam_thickness = value; emit_changed()
@export var tile_outline_width := Vector2.ZERO:
	set(value): tile_outline_width = value; emit_changed()
@export var tile_outline_color := Color.TRANSPARENT:
	set(value): tile_outline_color = value; emit_changed()
@export_range(0.0, 1.0, 0.001) var tile_outline_distortion := 0.0:
	set(value): tile_outline_distortion = value; emit_changed()
@export var tile_outline_distortion_scale := Vector2.ONE:
	set(value): tile_outline_distortion_scale = value; emit_changed()
@export var tile_modulate := Color.TRANSPARENT:
	set(value): tile_modulate = value; emit_changed()
@export_range(0.0, 1.0, 0.01) var tile_variance := 0.0:
	set(value): tile_variance = value; emit_changed()

@export_group("Material - Surface Outline")
@export var quad_outline_width := Vector2.ZERO:
	set(value): quad_outline_width = value; emit_changed()
@export var quad_outline_color := Color.TRANSPARENT:
	set(value): quad_outline_color = value; emit_changed()
@export_range(0.0, 1.0, 0.001) var quad_outline_distortion := 0.0:
	set(value): quad_outline_distortion = value; emit_changed()
@export var quad_outline_distortion_scale := Vector2.ONE:
	set(value): quad_outline_distortion_scale = value; emit_changed()
@export var disorder: Texture2D:
	set(value): disorder = value; emit_changed()

@export_group("Material - Contact")
@export var contact_height := -999.0:
	set(value): contact_height = value; emit_changed()
@export var contact_amp := Vector2.ZERO:
	set(value): contact_amp = value; emit_changed()

@export_group("Material - Damage Appearance")
@export var hole_atlas: Texture2D:
	set(value): hole_atlas = value; emit_changed()
@export var edge_noise_texture: Texture2D:
	set(value): edge_noise_texture = value; emit_changed()
@export var blood_noise_texture: Texture2D = DEFAULT_BLOOD_NOISE_TEXTURE:
	set(value): blood_noise_texture = value; emit_changed()
@export var hole_atlas_grid := Vector2i.ONE:
	set(value): hole_atlas_grid = value; emit_changed()
@export var hole_uv_size := Vector2(0.08, 0.08):
	set(value): hole_uv_size = value; emit_changed()
@export var hole_size_random_range := Vector2(0.85, 1.2):
	set(value): hole_size_random_range = value; emit_changed()
@export_range(0.0, 0.5, 0.001) var bullet_hole_merge_distance := 0.06:
	set(value): bullet_hole_merge_distance = value; emit_changed()
@export_range(0.001, 1.0, 0.001) var break_edge_width := 0.12:
	set(value): break_edge_width = value; emit_changed()
@export var edge_noise_scale := Vector2(5.0, 5.0):
	set(value): edge_noise_scale = value; emit_changed()
@export_range(0.0, 1.0, 0.001) var edge_noise_strength := 0.08:
	set(value): edge_noise_strength = value; emit_changed()

@export_group("Penetration")
@export_range(0.0, 1000.0, 0.1) var bullet_stopping_power := 1.0:
	set(value): bullet_stopping_power = value; emit_changed()
@export_range(1, 10000, 1) var max_health := 5:
	set(value): max_health = value; emit_changed()
@export var can_run_through := false:
	set(value): can_run_through = value; emit_changed()
@export var opaque := true:
	set(value): opaque = value; emit_changed()

@export_group("Effects")
@export var impact_effect: PackedScene:
	set(value): impact_effect = value; emit_changed()
@export var break_sound: AudioStream:
	set(value): break_sound = value; emit_changed()

var _shared_material: ShaderMaterial


func get_shared_material() -> ShaderMaterial:
	if not _shared_material:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = GENERIC_OBJECT_SHADER
	apply_to_material(_shared_material)
	return _shared_material


func apply_to_material(material: ShaderMaterial) -> void:
	_set_texture_if_present(material, "albedo", albedo)
	_set_texture_if_present(material, "texture_aoe", texture_aoe)
	_set_texture_if_present(material, "texture_detail", texture_detail)
	_set_texture_if_present(material, "disorder", disorder)
	_set_texture_if_present(material, "hole_atlas", hole_atlas)
	_set_texture_if_present(material, "edge_noise_texture", edge_noise_texture)
	_set_texture_if_present(material, "blood_noise_texture", blood_noise_texture)
	material.set_shader_parameter("metalic", metallic)
	material.set_shader_parameter("specular", specular)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("random_hue", random_hue)
	material.set_shader_parameter("detail", detail)
	material.set_shader_parameter("detail_uv_scale", detail_uv_scale)
	material.set_shader_parameter("tile_size", tile_size)
	material.set_shader_parameter("tile_bricks", tile_bricks)
	material.set_shader_parameter("tile_seam_thickness", tile_seam_thickness)
	material.set_shader_parameter("tile_outline_width", tile_outline_width)
	material.set_shader_parameter("tile_outline_color", tile_outline_color)
	material.set_shader_parameter(
		"tile_outline_distortion", tile_outline_distortion)
	material.set_shader_parameter(
		"tile_outline_distortion_scale", tile_outline_distortion_scale)
	material.set_shader_parameter("tile_modulate", tile_modulate)
	material.set_shader_parameter("tile_variance", tile_variance)
	material.set_shader_parameter("quad_outline_width", quad_outline_width)
	material.set_shader_parameter("quad_outline_color", quad_outline_color)
	material.set_shader_parameter(
		"quad_outline_distortion", quad_outline_distortion)
	material.set_shader_parameter(
		"quad_outline_distortion_scale", quad_outline_distortion_scale)
	material.set_shader_parameter("contact_height", contact_height)
	material.set_shader_parameter("contact_amp", contact_amp)
	material.set_shader_parameter("hole_atlas_grid", hole_atlas_grid)
	material.set_shader_parameter("hole_uv_size", hole_uv_size)
	material.set_shader_parameter(
		"hole_size_random_range", hole_size_random_range)
	material.set_shader_parameter("break_edge_width", break_edge_width)
	material.set_shader_parameter("edge_noise_scale", edge_noise_scale)
	material.set_shader_parameter("edge_noise_strength", edge_noise_strength)


func _set_texture_if_present(
		material: ShaderMaterial,
		parameter: StringName,
		texture: Texture2D
	) -> void:
	material.set_shader_parameter(parameter, texture)
