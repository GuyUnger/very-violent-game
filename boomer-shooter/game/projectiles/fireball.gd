extends MeshInstance3D

class_name Fireball
@export var speed: float = 5.0

func _process(delta):
	# Move the fireball forward
	position += Vector3(0, 1, 0) * -speed * delta
