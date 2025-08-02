extends Node

const ShellScene = preload("res://game/weapons/shellsmg.tscn")

var anim_tween : Tween

@onready var handle: MeshInstance3D = $"../WorldModel/weapon_smg/SMG/Handle"
@onready var shell_ejection: Marker3D = %ShellEjection


func shoot():
	eject_shell()
	handle.position.z = -0.055
	if anim_tween:
		anim_tween.kill()
	anim_tween = create_tween()
	anim_tween.tween_property(handle, "position:z", 0.0, 0.15)

func eject_shell():
	var new_shell := ShellScene.instantiate()
	new_shell.transform = shell_ejection.global_transform
	Main.instance.add_child(new_shell)
	new_shell.apply_central_impulse(Vector3.UP*0.7+shell_ejection.global_transform.basis.x*randf_range(1.2, 2.2)+shell_ejection.global_transform.basis.z*randf_range(1.2, 2.2))
	new_shell.apply_torque(Vector3(randf(), randf(), randf())*randf_range(0.0, 1.0))
