extends Node

@onready var handle: MeshInstance3D = $"../WorldModel/weapon_shotgun/Shotty/ShottyHandle"

var anim_tween : Tween

func shoot():
	handle.position.z = -0.061
	if anim_tween:
		anim_tween.kill()
	anim_tween = create_tween()
	anim_tween.tween_property(handle, "position:z", 0.0, 0.15)
