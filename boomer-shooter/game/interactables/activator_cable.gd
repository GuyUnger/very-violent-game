extends MeshInstance3D

const ACTIVATE_MAT := preload("res://content/environment/materials/surface_green_activate.tres")


func _ready() -> void:
	if get_parent() is MeleeActivator:
		get_parent().activated.connect(activate)

func activate() -> void:
	set_surface_override_material(1, ACTIVATE_MAT)
