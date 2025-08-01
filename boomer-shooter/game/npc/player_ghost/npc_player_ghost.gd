extends NPCHumanoid
class_name NPCPlayerGhost

var source_id:int
var last_position := Vector3.ZERO
var dead:int = 0: 
	set = set_dead


var jump:
	set(value):
		$AudioJump.play()

func set_dead(value:int) -> void:
	set_physics_process(false)
	collision_layer = 0
	animation_tree.set("parameters/Special/transition_request", "Died")
	$AudioDie.stream = Player.DEAD_SOUNDS[value]
	$AudioDie.play()


func _ready() -> void:
	if source_id:
		EventStore.register_source(source_id, self)

	animation_tree.set("parameters/TimeScale/scale", 2.0)


func _physics_process(delta: float) -> void:
	var world_direction = -global_position.direction_to(last_position)
	var forward = global_transform.basis.z
	var right = global_transform.basis.x
	var local_x = right.dot(world_direction)
	var local_y = forward.dot(world_direction)
	var blend_vector = Vector2(local_x, local_y)
	animation_tree.set("parameters/MoveDirection/blend_position", blend_vector)
	last_position = global_position

func hit(from) -> void:
	pass
