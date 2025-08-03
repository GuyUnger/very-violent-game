extends NPCHumanoid
class_name NPCHumanoidGrunt

func _ready() -> void:
	super()
	add_child(StateIdle.new())
	scale *= 1.2
	animation_tree.set("parameters/TimeScale/scale", randf_range(0.5, 0.8))
	
func _physics_process(delta: float) -> void:
	if animation_tree.active:
		$Armature.position = animation_tree.get_root_motion_position_accumulator()
