extends Node

@onready var world_model: Node3D = $"../WorldModel"

var anim_tween: Tween


func shoot() -> void:
	if anim_tween:
		anim_tween.kill()

	anim_tween = create_tween().set_parallel()
	anim_tween.tween_property(
		world_model,
		"position",
		Vector3(0.0, 0.0, -0.5),
		0.05)
	anim_tween.tween_property(
		world_model,
		"position",
		Vector3.ZERO,
		0.25).set_delay(0.05)
	
