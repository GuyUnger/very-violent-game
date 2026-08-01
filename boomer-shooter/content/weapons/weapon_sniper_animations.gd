extends Node

const ShellScene = preload("res://content/weapons/shellsmg.tscn")
@onready var world_model: Node3D = $"../WorldModel"
@onready var reload_hand = $"../WorldModel/Hand/weapon_shotgun_arm_r"


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
		
	anim_tween.tween_property(reload_hand, "position:z", 0.1, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	anim_tween.tween_property(%AudioBoltPullBack, "playing", true, 0.0).set_delay(0.5)
	anim_tween.tween_property(%AudioBoltRelease, "playing", true, 0.0).set_delay(0.8)
	anim_tween.tween_property(reload_hand, "position:z", -0.05, 0.1).set_delay(0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	anim_tween.tween_callback(eject_shell).set_delay(0.8)


func eject_shell():
	var new_shell := ShellScene.instantiate()
	new_shell.scale *= 3.0
	new_shell.transform = %ShellEjection.global_transform
	Main.instance.add_child(new_shell)
	new_shell.apply_central_impulse(Vector3.UP*0.7+%ShellEjection.global_transform.basis.x*randf_range(1.2, 2.2)+%ShellEjection.global_transform.basis.z*randf_range(1.2, 2.2))
	new_shell.apply_torque(Vector3(randf(), randf(), randf())*randf_range(0.0, 1.0))
