extends Node

const ShellScene = preload("res://game/weapons/shell.tscn")
const ARM_NEUTRAL_POS := -0.035
const ARM_END_POS := -0.114
const LEVER_NEUTRAL_POS := 0.008
const LEVER_END_POS := -0.064

@onready var audio_reload: AudioStreamPlayer = %AudioReload
@onready var shell_ejection: Marker3D = %ShellEjection
@onready var handle: MeshInstance3D = $"../WorldModel/ShotgunContainer/weapon_shotgun/Shotty/ShottyHandle"
@onready var world_model: Node3D = %WorldModel
@onready var shotgun_container: Node3D = %ShotgunContainer
@onready var weapon_arm: Node3D = $"../WorldModel/ShotgunContainer/Hand/weapon_shotgun_arm_l"
@onready var shotty_lever: MeshInstance3D = $"../WorldModel/ShotgunContainer/weapon_shotgun/Shotty/ShottyReloadThingy"


var anim_tween : Tween

func shoot():
	if anim_tween:
		anim_tween.kill()
	anim_tween = create_tween().set_parallel()
	anim_tween.tween_property(shotgun_container, "position", Vector3(0.0, 0.0, -0.2), 0.05)
	anim_tween.tween_property(shotgun_container, "position", Vector3(0.0, 0.0, 0.0), 0.25).set_delay(0.05)
	anim_tween.tween_property(world_model, "position", Vector3(0.0, -0.05, 0.0), 0.25).set_delay(0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
	anim_tween.tween_property(world_model, "rotation", Vector3(-0.5, -0.2, -0.1), 0.25).set_delay(0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CIRC)
	anim_tween.tween_property(weapon_arm, "position:z", ARM_END_POS, 0.15).set_delay(0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	anim_tween.tween_property(shotty_lever, "position:z", LEVER_END_POS, 0.15).set_delay(0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	anim_tween.tween_property(shotgun_container, "position:z", -0.1, 0.15).set_delay(0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	anim_tween.tween_property(handle, "position:z", -0.2, 0.15).set_delay(0.4)
	anim_tween.tween_callback(eject_shell).set_delay(0.45)
	anim_tween.tween_callback(audio_reload.play).set_delay(0.45)
	anim_tween.tween_property(handle, "position:z", 0.0, 0.15).set_delay(0.6)
	anim_tween.tween_property(shotgun_container, "position:z", 0.0, 0.15).set_delay(0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	anim_tween.tween_property(weapon_arm, "position:z", ARM_NEUTRAL_POS, 0.15).set_delay(0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	anim_tween.tween_property(shotty_lever, "position:z", LEVER_NEUTRAL_POS, 0.15).set_delay(0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	anim_tween.tween_property(world_model, "rotation", Vector3(0.0, 0.0, 0.0), 0.3).set_delay(0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	anim_tween.tween_property(world_model, "position", Vector3(0.0, 0.0, 0.0), 0.45).set_delay(0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	

func eject_shell():
	var new_shell := ShellScene.instantiate()
	new_shell.transform = shell_ejection.global_transform
	Main.instance.add_child(new_shell)
	new_shell.apply_central_impulse((Vector3.UP+shotgun_container.global_transform.basis.x)*randf_range(1.4, 2.2)+shell_ejection.global_transform.basis.z*randf_range(0.5, 1.1))
	new_shell.apply_torque(Vector3(randf(), randf(), randf())*randf_range(0.0, 1.0))
