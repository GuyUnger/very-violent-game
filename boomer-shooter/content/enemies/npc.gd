extends Character
class_name NPC

enum CombatPosture {
	STANDING,
	CROUCHED,
	PRONE,
}

enum BodyPart {
	TORSO,
	HEAD,
	ARM,
	UPPER_LEG,
	LOWER_LEG,
}

const NPC_BRAIN_SCRIPT = preload("res://content/enemies/ai/npc_brain.gd")
const NPC_COMBAT_SCRIPT = preload("res://content/enemies/ai/npc_combat.gd")
const NPC_PERCEPTION_SCRIPT = preload("res://content/enemies/ai/npc_perception.gd")
const NPC_NAVIGATION_SCRIPT = preload("res://content/enemies/ai/npc_navigation.gd")
const VISION_OPAQUE_COLLISION_LAYER := 1 << 4

signal died
signal heard(sound_position: Vector3)
signal told_enemy_position(position: Vector3)
signal spotted_enemy(enemy: Character)
signal combat_posture_changed(posture: CombatPosture)

@export var target_lock_time := 0.3
@export var heard_enemy_attack_time := 1.2
@export var attack_shot_delay_range := Vector2(0.4, 0.9)
@export var move_attack_burst_interval_range := Vector2(4.0, 6.0)
@export var surprised_time := 1.0
@export_range(0.0, 2.0, 0.01) var attack_vertical_spread := 0.35
@export_range(0, 100, 1) var intentional_misses_remaining := 1
@export_range(0.0, 1.0, 0.01) var blind_fire_miss_chance := 0.5
@export var auto_burst_shot_range := Vector2i(3, 6)
@export var ignore_player_hearing := false
@export var draw_debug_vision_ray := false
@export_range(0.0, 1000.0, 0.1) var bullet_stopping_power := 0.0
@export_range(0.0, 20.0, 0.1) var prone_distance_threshold := 1.0
@export_range(0.0, 20.0, 0.1) var crouched_distance_threshold := 2.0
@export_group("Navigation")
@export var navigation_enabled := true
@export_group("Damage Multipliers")
@export_range(0.0, 10.0, 0.05) var damage_multiplier_head := 4.0
@export_range(0.0, 10.0, 0.05) var damage_multiplier_torso := 3.0
@export_range(0.0, 10.0, 0.05) var damage_multiplier_arm := 0.5
@export_range(0.0, 10.0, 0.05) var damage_multiplier_upper_leg := 2.0
@export_range(0.0, 10.0, 0.05) var damage_multiplier_lower_leg := 2.0
@export_group("")
@export var moving_to: Node3D
@export var looking_at: Vector3
@export var target: Node3D:
	set = set_target
@export var speed := 1.0
@export var holes: int:
	set = set_holes
@export var cuts: int:
	set = set_cuts

var speed_scale := 1.0
var speed_scale_knock_back := 1.0
var knock_back_force := Vector3.ZERO
var knock_back_tween_: Tween
var target_turn_tween: Tween
var hit_tween_: Tween
var combat_posture := CombatPosture.STANDING:
	set = set_combat_posture
var brain
var perception
var combat
var navigation
var hitbox_to_body_part: Dictionary = {}
var right_hand_obstruction_timer: Timer
var right_hand_ik_obstruction_latched := false


func _ready() -> void:
	perception = NPC_PERCEPTION_SCRIPT.new()
	perception.name = "Perception"
	add_child(perception)
	perception.setup(self)
	perception.spotted_enemy.connect(_on_spotted_enemy)

	combat = NPC_COMBAT_SCRIPT.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self)

	navigation = NPC_NAVIGATION_SCRIPT.new()
	navigation.name = "Navigation"
	add_child(navigation)
	navigation.setup(self)

	brain = NPC_BRAIN_SCRIPT.new()
	brain.name = "Brain"
	add_child(brain)
	brain.setup(self, perception, combat)

	right_hand_obstruction_timer = Timer.new()
	right_hand_obstruction_timer.name = "RightHandObstructionTimer"
	right_hand_obstruction_timer.wait_time = 1.0
	right_hand_obstruction_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	right_hand_obstruction_timer.timeout.connect(
		_poll_right_hand_ik_obstruction)
	add_child(right_hand_obstruction_timer)
	if is_instance_valid(target):
		right_hand_obstruction_timer.start()


func set_holes(value: int) -> void:
	holes = value


func set_cuts(value: int) -> void:
	cuts = value


func set_target(node: Node3D) -> void:
	if target == node:
		return
	target = node
	clear_right_hand_ik_collision()
	if is_instance_valid(right_hand_obstruction_timer):
		if is_instance_valid(target):
			right_hand_obstruction_timer.start()
		else:
			right_hand_obstruction_timer.stop()


func set_combat_posture(value: CombatPosture) -> void:
	if combat_posture == value:
		return
	combat_posture = value
	combat_posture_changed.emit(combat_posture)


func look_at_node_y_axis_lerp(
		target_position: Vector3,
		delta: float,
		speed_value: float = 5.0) -> void:
	var direction := target_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if direction.is_zero_approx():
		return

	var target_yaw := atan2(direction.x, direction.z)
	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_yaw,
		clamp(delta * speed_value, 0.0, 1.0))


func get_yaw_angle_to_target() -> float:
	if not is_instance_valid(target):
		return 0.0
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		return 0.0
	var target_yaw := atan2(direction.x, direction.z)
	return angle_difference(global_rotation.y, target_yaw)


func get_angle_to_target() -> float:
	return get_yaw_angle_to_target()


func tween_look_at_target(duration := 0.12) -> void:
	if not is_instance_valid(target):
		return
	if target_turn_tween and target_turn_tween.is_running():
		return

	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		return

	var start_yaw := global_rotation.y
	var target_yaw := atan2(direction.x, direction.z)
	target_turn_tween = create_tween()
	target_turn_tween.set_trans(Tween.TRANS_QUAD)
	target_turn_tween.set_ease(Tween.EASE_OUT)
	target_turn_tween.tween_method(
		func(weight: float) -> void:
			global_rotation.y = lerp_angle(start_yaw, target_yaw, weight),
		0.0,
		1.0,
		duration)


func knock_back(_force: Vector3) -> void:
	pass


func is_node_visible(node: Node3D) -> bool:
	return perception.is_node_visible(node) if perception else false


func poll_vision() -> void:
	if perception:
		perception.poll()


func _heard(sound_position: Vector3) -> void:
	if ignore_player_hearing:
		return
	heard.emit(sound_position)


func _told_enemy_position(position: Vector3) -> void:
	if ignore_player_hearing:
		return
	told_enemy_position.emit(position)


func alert_other_enemies(position: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(&"npc_enemies"):
		var other := node as NPC
		if (
			not other
			or other == self
			or other.health <= 0.0
			or other.get_viewport() != get_viewport()
		):
			continue
		other._told_enemy_position(position)


func _on_spotted_enemy(enemy: Character) -> void:
	spotted_enemy.emit(enemy)


func play_alert_sound() -> void:
	var alert_sound := get_node_or_null("AlertSound")
	if alert_sound and alert_sound.has_method("play"):
		alert_sound.play()


func start_move_and_attack(enemy: Node3D) -> void:
	if brain:
		brain.start_move_and_attack(enemy)


func set_right_hand_ik_collision_point(_collision_point: Vector3) -> void:
	right_hand_ik_obstruction_latched = true


func clear_right_hand_ik_collision() -> void:
	right_hand_ik_obstruction_latched = false


func raycast_weapon_emit_to_vision() -> Dictionary:
	if (
		not perception
		or not is_instance_valid(perception.vision)
		or not combat
		or not is_instance_valid(combat.weapon)
	):
		return {}

	var emit_position: Vector3 = (
		combat.weapon.global_position + Vector3.UP * 0.1)
	var vision_position: Vector3 = perception.vision.global_position
	if emit_position.is_equal_approx(vision_position):
		return {}

	var query := PhysicsRayQueryParameters3D.create(
		emit_position,
		vision_position)
	query.collision_mask = VISION_OPAQUE_COLLISION_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _poll_right_hand_ik_obstruction() -> void:
	if health <= 0.0 or not is_instance_valid(target):
		clear_right_hand_ik_collision()
		right_hand_obstruction_timer.stop()
		return
	if right_hand_ik_obstruction_latched:
		return

	var obstruction := raycast_weapon_emit_to_vision()
	if obstruction.is_empty():
		clear_right_hand_ik_collision()
	else:
		set_right_hand_ik_collision_point(obstruction.position)
		right_hand_obstruction_timer.stop()


func get_bullet_stopping_power() -> float:
	return bullet_stopping_power


func melee() -> void:
	health = 0
	if has_node("%AudioMeleeSlash"):
		%AudioMeleeSlash.play()
	die()
	cuts += 1


func hit(
		damage: float,
		normal := Vector3.ZERO,
		hit_shape: CollisionShape3D = null) -> void:
	holes += 1
	if health <= 0:
		return

	var skin := get_node_or_null(
		"Characters/Armature/Skeleton3D/Skin") as MeshInstance3D
	if skin:
		if hit_tween_:
			hit_tween_.kill()
		hit_tween_ = create_tween()
		skin.set_instance_shader_parameter("color", Color.RED)
		hit_tween_.tween_interval(0.2)
		hit_tween_.tween_property(
			skin,
			"instance_shader_parameters/color",
			Color(1.0, 1.0, 1.0, 0.0),
			0.0)

	super(damage, normal, hit_shape)


func hit_with_damage_event(event: DamageEvent) -> void:
	var body_part: BodyPart = hitbox_to_body_part.get(
		event.hit_shape, BodyPart.TORSO)
	event.body_part_multiplier = get_body_part_damage_multiplier(body_part)
	_request_blood_spray(event)
	hit(event.get_damage(), event.hit_normal, event.hit_shape)


func _request_blood_spray(event: DamageEvent) -> void:
	var spray_direction := event.hit_position - event.shot_origin
	if spray_direction.is_zero_approx():
		spray_direction = -event.hit_normal
	for node in get_tree().get_nodes_in_group("blood_system"):
		var blood_system := node as BloodSystem
		if blood_system and blood_system.get_viewport() == get_viewport():
			blood_system.request_spray(event.hit_position, spray_direction, self)
			return


func get_body_part_damage_multiplier(body_part: BodyPart) -> float:
	match body_part:
		BodyPart.HEAD:
			return damage_multiplier_head
		BodyPart.ARM:
			return damage_multiplier_arm
		BodyPart.UPPER_LEG:
			return damage_multiplier_upper_leg
		BodyPart.LOWER_LEG:
			return damage_multiplier_lower_leg
		_:
			return damage_multiplier_torso


func die(
		_normal := Vector3.ZERO,
		_hit_shape: CollisionShape3D = null) -> void:
	died.emit()
	Main.instance.enemy_killed.emit()
