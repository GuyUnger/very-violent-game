extends NPCHumanoid
class_name NPCHumanoidGrunt

func _ready() -> void:
	super()
	add_child(StateIdle.new())
