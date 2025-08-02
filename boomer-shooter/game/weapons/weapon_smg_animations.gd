extends Node

var anim_tween : Tween

@onready var handle: MeshInstance3D = $"../WorldModel/weapon_smg/SMG/Handle"


func shoot():
	handle.position.z = -0.055
	if anim_tween:
		anim_tween.kill()
	anim_tween = create_tween()
	anim_tween.tween_property(handle, "position:z", 0.0, 0.15)
