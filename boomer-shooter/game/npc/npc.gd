@tool
extends Node3D
class_name NPC

@export var moving_to:Node3D
@export var target:Node3D : 
	set = set_target
@export var speed := 1.0
@export var max_health := 100
@export var health := 100

var speed_scale := 1.0
var speed_scale_knock_back := 1.0
var knock_back_force := Vector3.ZERO

@onready var animation_tree:AnimationTree = $AnimationTree

var center_pos: Vector3:
	get:
		return global_position + Vector3.UP * 1.0

func set_target(node:Node3D) -> void:
	target = node
	if not is_node_ready():
		return
	
	if target:
		if target.has_node("%Head"):
			%LookAtModifier3D.target_node = target.get_node("%Head").get_path()
		else:
			%LookAtModifier3D.target_node = target.get_path()


func _physics_process(delta: float) -> void:
	if moving_to:
		global_position = global_position.move_toward(moving_to.global_position, delta * speed * speed_scale * speed_scale_knock_back)
	
	if target:
		if moving_to:
			var world_direction = global_position.direction_to(moving_to.global_position)
			var forward = global_transform.basis.z
			var right = global_transform.basis.x
			var local_x = right.dot(world_direction)
			var local_y = forward.dot(world_direction)
			var blend_vector = Vector2(local_x, local_y)
			blend_vector *= speed_scale * speed_scale_knock_back
			animation_tree.set("parameters/MoveDirection/blend_position", blend_vector)
		
		look_at_node_y_axis_lerp(target, delta * 0.5)
	
	if knock_back_force != Vector3.ZERO:
		global_position -= knock_back_force
		knock_back_force = lerp(knock_back_force, Vector3.ZERO, delta)


func look_at_node_y_axis_lerp(target_node: Node3D, delta: float, speed: float = 5.0) -> void:
	var self_position = global_transform.origin
	var target_position = target_node.global_transform.origin
	
	# Get direction to target on the XZ plane
	var direction = target_position - self_position
	direction.y = 0
	direction = direction.normalized()
	
	if direction.length() == 0:
		return  # Avoid NaN if both nodes are in the same place
	
	# Calculate desired yaw
	var target_yaw = atan2(direction.x, direction.z)
	var current_yaw = global_rotation.y
	
	# Smoothly interpolate towards target yaw
	var new_yaw = lerp_angle(current_yaw, target_yaw, clamp(delta * speed, 0.0, 1.0))
	global_rotation.y = new_yaw

var knock_back_tween_:Tween

func knock_back(force:Vector3) -> void:
	force.y *= 0.0

	knock_back_force += force
	
	if knock_back_tween_:
		knock_back_tween_.kill()

	knock_back_tween_ = create_tween()
	knock_back_tween_.tween_property(self, "speed_scale_knock_back", 0.1, 0.1)
	knock_back_tween_.tween_property(self, "speed_scale_knock_back", 1.0, 1.0)
	animation_tree.set("parameters/HitBody/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	print("HITs")
