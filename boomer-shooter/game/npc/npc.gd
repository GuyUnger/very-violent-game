@tool
extends Character
class_name NPC

signal died
signal heard
signal told_enemy_position
signal spotted_enemy

@export var poll_vision_checks := false

@export var moving_to:Node3D
@export var looking_at:Vector3
@export var target:Node3D : 
	set = set_target
@export var speed := 1.0
@export var holes:int :
	set = set_holes
@export var cuts:int :
	set = set_cuts
var speed_scale := 1.0
var speed_scale_knock_back := 1.0
var knock_back_force := Vector3.ZERO

func set_holes(value:int) -> void:
	holes = value

func set_cuts(value:int) -> void:
	cuts = value

func set_target(node:Node3D) -> void:
	target = node
	
func _ready() -> void:
	if poll_vision_checks:
		%Vision.body_entered.connect(_body_entered_vision)

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
	pass
	

func is_node_visible(node) -> bool:
	var query = PhysicsRayQueryParameters3D.new()
	query.from = %Vision.global_position
	query.to = node.global_position + Vector3.UP
	query.collide_with_bodies = true
	query.collision_mask = 1 + 2 + 8
	
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


func hit(from:Node3D) -> void:
	holes += 1
	
	if health <= 0:
		return

	knock_back(from.knock_back * 0.01 * from.transform.basis.z)
	
	$AudioHurt.play()
	
	health -= from.damage

	if health <= 0:

		die()


func die() -> void:
	set_physics_process(false)
	remove_from_group("aimables")
	died.emit()


func _body_entered_vision(body) -> void:
	if is_node_visible(body):
		spotted_enemy.emit(body)

func poll_vision() -> void:
	while true:
		var bodies = %Vision.get_overlapping_bodies()
		for node in bodies:
			if is_node_visible(node):
				spotted_enemy.emit(node)
			await get_tree().process_frame
