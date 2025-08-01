@tool
extends Node3D
class_name NPC

signal died
signal heard
signal told_enemy_position

@export var moving_to:Node3D
@export var looking_at:Vector3
@export var target:Node3D : 
	set = set_target
@export var speed := 1.0
@export var max_health := 5
@export var health := 5 :
	set = set_health
@export var holes:int :
	set = set_holes
@export var cuts:int :
	set = set_cuts
var speed_scale := 1.0
var speed_scale_knock_back := 1.0
var knock_back_force := Vector3.ZERO

@onready var animation_tree:AnimationTree = $AnimationTree

func set_health(value:float) -> void:
	var diff = health - value
	
	health = value

	if not Engine.is_editor_hint():
		if health <= 0:
			died.emit()
			if not animation_tree:
				printerr("something wrong in npc.gd")
				return
			animation_tree.set("parameters/Special/transition_request", "Died")


func set_holes(value:int) -> void:
	holes = value
	if has_node("Armature/Skeleton3D/Skin"):
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("hole_damage", holes / 255.0)


func set_cuts(value:int) -> void:
	cuts = value
	if has_node("Armature/Skeleton3D/Skin"):
		if cuts == 0:
			$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_0", Vector4())
			$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_1", Vector4())
		if cuts == 1:
			$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_0", Vector4(randf(), randf(), randf(), randf()))
		elif cuts == 2:
			$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_1", Vector4(randf(), randf(), randf(), randf()))


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
	else:
		%LookAtModifier3D.target_node = NodePath("")

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
		else:
			animation_tree.set("parameters/MoveDirection/blend_position", Vector2.ZERO)
		
		look_at_node_y_axis_lerp(target.global_position, delta * 0.5)
	
	if knock_back_force != Vector3.ZERO:
		global_position -= knock_back_force
		knock_back_force = lerp(knock_back_force, Vector3.ZERO, delta)
		
	if not target and looking_at:
		look_at_node_y_axis_lerp(looking_at, delta * 0.5)


func look_at_node_y_axis_lerp(target_position: Vector3, delta: float, speed: float = 5.0) -> void:
	var self_position = global_transform.origin
	
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
	animation_tree.set("parameters/HitHead/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	

func is_node_visible(node) -> bool:
	var query = PhysicsRayQueryParameters3D.new()
	query.from = %Vision.global_position
	query.to = node.global_position + Vector3.UP
	query.collide_with_bodies = true
	query.collision_mask = 1 + 2
	
	var res = get_world_3d().direct_space_state.intersect_ray(query)
	if res and res.collider == node:
		return true

	return false


func _heard(sound_position:Vector3) -> void:
	heard.emit(sound_position)


func _told_enemy_position(enemy) -> void:
	told_enemy_position.emit(enemy)


func melee() -> void:
	health -= 5
	cuts += 1
