extends Node3D

@export var speed := 1.0

func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	var direction = global_transform.basis.z.normalized()
	global_position += direction * delta * speed
