extends NPCHumanoid
class_name NPCHumanoidBigGuy

func _ready() -> void:
	super()
	add_child(StateIdle.new())

	scale *= 2.0
