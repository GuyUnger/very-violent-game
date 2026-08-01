extends Character
class_name NPC

enum CombatPosture {
	DEFAULT,
	CROUCHING,
	SITTING,
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

signal died
signal heard(sound_position: Vector3)
signal told_enemy_position(enemy: Node3D)
signal spotted_enemy(enemy: Character)
signal combat_posture_changed(posture: CombatPosture)

@export var target_lock_time := 0.3
@export var heard_enemy_attack_time := 1.2
@export var attack_shot_delay_range := Vector2(0.4, 0.9)
@export var move_attack_burst_interval_range := Vector2(4.0, 6.0)
@export var surprised_time := 1.0
@export_range(0.0, 2.0, 0.01) var attack_vertical_spread := 0.35
@export_range(0, 100, 1) var intentional_misses_remaining := 1
@export var auto_burst_shot_range := Vector2i(3, 6)
@export var ignore_player_hearing := false
@export var draw_debug_vision_ray := false
@export_range(0.0, 20.0, 0.1) var sitting_distance_threshold := 1.0
@export_range(0.0, 20.0, 0.1) var crouching_distance_threshold := 2.0
@export_group("Navigation")
@export var navigation_enabled := true
@export_group("Damage Multipliers")
@export_range(0.0, 10.0, 0.05) var head_damage_multiplier := 4.0
@export_range(0.0, 10.0, 0.05) var torso_damage_multiplier := 1.0
@export_range(0.0, 10.0, 0.05) var arm_damage_multiplier := 0.25
@export_range(0.0, 10.0, 0.05) var upper_leg_damage_multiplier := 0.5
@export_range(0.0, 10.0, 0.05) var lower_leg_damage_multiplier := 0.5
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
var combat_posture := CombatPosture.DEFAULT:
	set = set_combat_posture
var brain
var perception
var combat
var navigation
var hitbox_to_body_part: Dictionary = {}


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


func set_holes(value: int) -> void:
	holes = value


func set_cuts(value: int) -> void:
	cuts = value


func set_target(node: Node3D) -> void:
	target = node


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


func _told_enemy_position(enemy: Node3D) -> void:
	told_enemy_position.emit(enemy)


func _on_spotted_enemy(enemy: Character) -> void:
	spotted_enemy.emit(enemy)


func play_alert_sound() -> void:
	var alert_sound := get_node_or_null("AlertSound")
	if alert_sound and alert_sound.has_method("play"):
		alert_sound.play()


func start_move_and_attack(enemy: Node3D) -> void:
	if brain:
		brain.start_move_and_attack(enemy)


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
	hit(event.get_damage(), event.hit_normal, event.hit_shape)


func get_body_part_damage_multiplier(body_part: BodyPart) -> float:
	match body_part:
		BodyPart.HEAD:
			return head_damage_multiplier
		BodyPart.ARM:
			return arm_damage_multiplier
		BodyPart.UPPER_LEG:
			return upper_leg_damage_multiplier
		BodyPart.LOWER_LEG:
			return lower_leg_damage_multiplier
		_:
			return torso_damage_multiplier


func die(
		_normal := Vector3.ZERO,
		_hit_shape: CollisionShape3D = null) -> void:
	remove_from_group("aimables")
	died.emit()
	Main.instance.enemy_killed.emit()
