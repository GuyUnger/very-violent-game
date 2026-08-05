class_name ScreenSpaceEffects
extends ColorRect

@export_range(0.0, 0.02) var chromatic_aberration := 0.002

@onready var shader_material: ShaderMaterial = material as ShaderMaterial

var damage_mist := 0.0:
	set(value):
		damage_mist = clampf(value, 0.0, 1.0)
		shader_material.set_shader_parameter("damage_intensity", damage_mist)


func _ready() -> void:
	shader_material.set_shader_parameter("chromatic_aberration", chromatic_aberration)
	damage_mist = 0.0
