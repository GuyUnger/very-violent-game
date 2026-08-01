class_name NPCBrain
extends Node

const NPC_STATE_SCRIPT = preload("res://content/enemies/ai/npc_state.gd")
const HEARD_TARGET_MARKER_SCENE = preload(
	"res://content/enemies/ai/heard_target_marker.tscn")

var npc
var perception
var combat
var current_state
var heard_target_marker: NPCHeardTargetMarker


func setup(
		p_npc,
		p_perception,
		p_combat) -> void:
	npc = p_npc
	perception = p_perception
	combat = p_combat
	npc.heard.connect(_on_heard)
	npc.spotted_enemy.connect(_on_spotted)
	npc.told_enemy_position.connect(_on_told)
	npc.died.connect(_on_died)
	transition(NPC_STATE_SCRIPT.Idle.new())


func transition(next_state) -> void:
	if current_state:
		current_state.exit()
	set_emotes(false, false)
	current_state = next_state
	if current_state:
		current_state.enter(self)


func start_move_and_attack(enemy: Node3D) -> void:
	var next_state := NPC_STATE_SCRIPT.MoveAndAttack.new()
	next_state.enemy = enemy
	transition(next_state)


func reset_combat_posture() -> void:
	npc.combat_posture = npc.CombatPosture.DEFAULT


func update_combat_posture(target_distance: float) -> void:
	var sitting_threshold: float = minf(
		npc.sitting_distance_threshold,
		npc.crouching_distance_threshold)
	var crouching_threshold: float = maxf(
		npc.sitting_distance_threshold,
		npc.crouching_distance_threshold)

	if target_distance < sitting_threshold:
		npc.combat_posture = npc.CombatPosture.SITTING
	elif target_distance <= crouching_threshold:
		npc.combat_posture = npc.CombatPosture.CROUCHING
	else:
		npc.combat_posture = npc.CombatPosture.DEFAULT


func set_heard_target(position: Vector3) -> NPCHeardTargetMarker:
	if not is_instance_valid(heard_target_marker):
		heard_target_marker = HEARD_TARGET_MARKER_SCENE.instantiate()
		var marker_parent: Node = npc.get_tree().current_scene
		if marker_parent == null:
			marker_parent = npc.get_parent()
		marker_parent.add_child(heard_target_marker)
	heard_target_marker.global_position = position
	return heard_target_marker


func clear_heard_target() -> void:
	if is_instance_valid(heard_target_marker):
		heard_target_marker.queue_free()
	heard_target_marker = null


func set_emotes(show_startled: bool, show_attacking: bool) -> void:
	var startled: Node3D = npc.get_node_or_null("Startled") as Node3D
	if startled == null:
		startled = npc.get_node_or_null("Spotted")
	if startled:
		startled.visible = show_startled

	var attacking: Node3D = npc.get_node_or_null("Attacking") as Node3D
	if attacking:
		attacking.visible = show_attacking


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)


func _on_heard(position: Vector3) -> void:
	if current_state:
		current_state.heard(position)


func _on_spotted(enemy: Character) -> void:
	if current_state:
		current_state.spotted(enemy)


func _on_told(enemy: Node3D) -> void:
	if current_state:
		current_state.told(enemy)


func _on_died() -> void:
	if current_state:
		current_state.exit()
	current_state = null
	clear_heard_target()
	set_emotes(false, false)
	combat.throw_weapon()
	npc.looking_at = Vector3.ZERO
	npc.target = null
	npc.moving_to = null
	npc.set_physics_process(false)
	set_physics_process(false)
