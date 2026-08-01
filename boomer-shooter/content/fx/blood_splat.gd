extends Node3D

func _ready() -> void:
	$GPUParticles3D.emitting = true
	$GPUParticles3D.finished.connect(queue_free)
