extends Node3D

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	$GPUParticles3D.emitting = false
	await get_tree().create_timer(2.0).timeout
	queue_free()
	
