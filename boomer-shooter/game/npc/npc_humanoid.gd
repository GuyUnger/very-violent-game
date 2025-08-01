extends NPC
class_name NPCHumanoid

@onready var animation_tree:AnimationTree = $AnimationTree

func set_holes(value:int) -> void:
	holes = value
	
	if not is_node_ready():
		return
	
	$Armature/Skeleton3D/Skin.set_instance_shader_parameter("hole_damage", holes / 255.0)


func set_cuts(value:int) -> void:
	cuts = value
	
	if not is_node_ready():
		return
	
	if cuts == 0:
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_0", Vector4())
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_1", Vector4())
	if cuts == 1:
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_0", Vector4(randf(), randf(), randf(), randf()))
	elif cuts == 2:
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("cut_1", Vector4(randf(), randf(), randf(), randf()))

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


func knock_back(force:Vector3) -> void:
	force.y *= 0.0

	knock_back_force += force
	
	if knock_back_tween_:
		knock_back_tween_.kill()

	knock_back_tween_ = create_tween()
	knock_back_tween_.tween_property(self, "speed_scale_knock_back", 0.1, 0.1)
	knock_back_tween_.tween_property(self, "speed_scale_knock_back", 1.0, 1.0)
	animation_tree.set("parameters/HitHead/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func melee() -> void:
	super()
	
	var x := preload("res://game/fx/bloot_line.tscn").instantiate()
	$CollisionShape3D.add_child(x)
	x.position.y += 0.5
	x.look_at(Main.instance.player.global_position + Vector3.UP * 2.0, Vector3.UP, true)


func hit(from:Node3D) -> void:
	super(from)


func die() -> void:
	super()

	animation_tree.set("parameters/Special/transition_request", "Died")

	if randf() > 0.5:
		head_pop()


func head_pop() -> void:
	if has_node("Armature/Skeleton3D/Skin"):
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("head_pop", 1.0)
		
		var x := preload("res://game/fx/bloot_line.tscn").instantiate()
		$CollisionShape3D.add_child(x)
		x.position.y += 0.5
		x.look_at(global_position + Vector3.UP)
