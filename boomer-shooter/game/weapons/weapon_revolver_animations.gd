extends Node
var anim_tween : Tween

@onready var revolver: Node3D = $"../WorldModel/Revolver"

func shoot():
	if anim_tween:
		anim_tween.kill()
	anim_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	anim_tween.tween_property(revolver, "position:z", -0.15, 0.05)
	anim_tween.tween_property(revolver, "rotation:x", -0.7, 0.05)
	anim_tween.tween_property(revolver, "rotation:x", 0.0, 0.45).set_delay(0.05)
	anim_tween.tween_property(revolver, "position:z", 0.00, 0.45).set_delay(0.05)
