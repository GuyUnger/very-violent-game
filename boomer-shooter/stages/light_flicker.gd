extends OmniLight3D


func _physics_process(delta: float) -> void:
	if randf() < 0.1:
		visible = not visible