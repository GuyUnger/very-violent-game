@tool
extends NPCEnemy
class_name NPCHumanoidGirl

@onready var physical_bone_hips = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/Hips
@onready var physical_bone_head = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/Head
@onready var physical_bone_left_arm = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/LeftArm
@onready var physical_bone_left_fore_arm = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/LeftForeArm
@onready var physical_bone_right_arm = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/RightArm
@onready var physical_bone_right_fore_arm = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/RightForeArm
@onready var physical_bone_left_leg_upper = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/LeftLegUpper
@onready var physical_bone_left_leg = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/LeftLeg
@onready var physical_bone_right_leg_upper = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/RightLegUpper
@onready var physical_bone_right_leg = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D/RightLeg

@onready var hit_head: CollisionShape3D = $Head
@onready var hit_body: CollisionShape3D = $Body
@onready var hit_left_leg_upper: CollisionShape3D = $LeftLegUpper
@onready var hit_left_leg: CollisionShape3D = $LeftLeg
@onready var hit_right_leg_upper: CollisionShape3D = $RightLegUpper
@onready var hit_right_leg: CollisionShape3D = $RightLeg

@onready var look_at_spine = $Characters/Armature/Skeleton3D/LookAtModifierSpine
@onready var look_at_head = $Characters/Armature/Skeleton3D/LookAtModifierHead
@onready var look_at_right_hand = $Characters/Armature/Skeleton3D/LookAtModifierRightHand
@onready var right_arm_ik = $Characters/Armature/Skeleton3D/TwoBoneIK3D
@onready var target_marker = $TargetMarker
@onready var right_arm_attachment = $Characters/Armature/Skeleton3D/BoneAttachmentRightHand
@onready var physics_bone_simulator = $Characters/Armature/Skeleton3D/PhysicalBoneSimulator3D
@onready var skeleton = $Characters/Armature/Skeleton3D
@onready var animation_tree: AnimationTree = $AnimationTree

@export_range(0.0, 180.0, 1.0) var left_aim_limit_degrees := 140.0
@export_range(0.0, 180.0, 1.0) var right_aim_limit_degrees := 40.0

var delta_sum_ := 0.0
var hitbox_to_physical_bone: Dictionary

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	combat_posture_changed.connect(_on_combat_posture_changed)

	hitbox_to_physical_bone = {
		hit_head: physical_bone_head,
		hit_body: physical_bone_hips,
		hit_left_leg_upper: physical_bone_left_leg_upper,
		hit_left_leg: physical_bone_left_leg,
		hit_right_leg_upper: physical_bone_right_leg_upper,
		hit_right_leg: physical_bone_right_leg,
	}
	hitbox_to_body_part = {
		hit_head: BodyPart.HEAD,
		hit_body: BodyPart.TORSO,
		hit_left_leg_upper: BodyPart.UPPER_LEG,
		hit_left_leg: BodyPart.LOWER_LEG,
		hit_right_leg_upper: BodyPart.UPPER_LEG,
		hit_right_leg: BodyPart.LOWER_LEG,
	}

	super()
	_on_combat_posture_changed(combat_posture)


func set_holes(value: int) -> void:
	holes = value


func set_cuts(value: int) -> void:
	cuts = value


func set_target(node: Node3D) -> void:
	target = node


func _physics_process(delta: float) -> void:
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if not flat_velocity.is_zero_approx():
		var world_direction := flat_velocity.normalized()
		var forward := global_transform.basis.z
		var right := global_transform.basis.x
		var local_x := right.dot(world_direction)
		var local_y := forward.dot(world_direction)
		var blend_vector := Vector2(local_x, local_y)
		blend_vector *= clampf(
			flat_velocity.length() / maxf(speed, 0.001), 0.0, 1.0)
		animation_tree.set("parameters/MoveDirection/blend_position", blend_vector)
	else:
		animation_tree.set("parameters/MoveDirection/blend_position", Vector2.ZERO)

	if knock_back_force != Vector3.ZERO:
		global_position -= knock_back_force
		knock_back_force = lerp(knock_back_force, Vector3.ZERO, delta)

	if target:
		target_marker.position = to_local(target.get_center_pos())


func look_at_node_y_axis_lerp(
		target_position: Vector3,
		delta: float,
		speed: float = 5.0) -> void:
	var direction := target_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if direction.is_zero_approx():
		return

	var target_yaw := atan2(direction.x, direction.z)
	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_yaw,
		clamp(delta * speed, 0.0, 1.0))


func head_pop() -> void:
	if has_node("Armature/Skeleton3D/Skin"):
		$Armature/Skeleton3D/Skin.set_instance_shader_parameter("head_pop", 1.0)

		var blood_line := preload("res://content/fx/bloot_line.tscn").instantiate()
		$CollisionShape3D.add_child(blood_line)
		blood_line.position.y += 0.5
		blood_line.look_at(global_position + Vector3.UP)


func _process(delta: float) -> void:
	delta_sum_ += delta

	if health <= 0:
		return
	
	var d: float = target_marker.global_position.distance_to(right_arm_attachment.global_position)
	
	right_arm_ik.set_indexed("settings/0/end_bone/length", lerp(0.33, 0.0, d * 0.1))

	if Engine.is_editor_hint():
		return
		
		
	skeleton.scale.y = 1.0 + sin(delta_sum_ * 15.0) * 0.05

	if target:
		var target_angle := get_yaw_angle_to_target()
		var aim_limit_degrees := (
			right_aim_limit_degrees
			if target_angle >= 0.0
			else left_aim_limit_degrees)
		if absf(target_angle) > deg_to_rad(aim_limit_degrees):
			tween_look_at_target()


func _on_combat_posture_changed(posture: CombatPosture) -> void:
	match posture:
		CombatPosture.SITTING:
			$Characters/AnimationPlayer.play(
				"npc_girl_skinny/Sitting Idle",
				0.5)
		CombatPosture.CROUCHING:
			$Characters/AnimationPlayer.play(
				"npc_girl_skinny/Crouch Idle",
				0.5)
		_:
			$Characters/AnimationPlayer.play(
				"npc_girl_skinny/Cross Jumps Rotation",
				0.5)


func set_ik_enabled(value: bool) -> void:
	look_at_spine.active = value
	look_at_head.active = false
	look_at_right_hand.active = value
	right_arm_ik.active = value


func die(normal := Vector3.ZERO, hit_shape: CollisionShape3D = null) -> void:
	super(normal, hit_shape)
	
	begin_rag_doll(normal, hit_shape)


func begin_rag_doll(normal, hit_shape) -> void:
	set_ik_enabled(false)
	
	var impact_bone: PhysicalBone3D = hitbox_to_physical_bone.get(hit_shape, physical_bone_hips)

	physics_bone_simulator.active = true
	physics_bone_simulator.physical_bones_add_collision_exception(get_rid())
	physics_bone_simulator.physical_bones_start_simulation()

	await get_tree().physics_frame
	impact_bone.apply_central_impulse(-normal * 10.0)

	await get_tree().create_timer(2.0).timeout
	physics_bone_simulator.physical_bones_stop_simulation()
