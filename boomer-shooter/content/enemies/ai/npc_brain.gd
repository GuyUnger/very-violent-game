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
var perceived_enemy: Character
var last_visible_position := Vector3.ZERO


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
	pass


func lost_target(last_known_position: Vector3) -> void:
	if current_state:
		current_state.lost_target(last_known_position)


func track_visible_enemy(enemy: Character) -> void:
	if not is_instance_valid(enemy):
		return
	perceived_enemy = enemy
	last_visible_position = enemy.global_position


func reset_combat_posture() -> void:
	update_combat_posture(npc.CombatPosture.STANDING)


func update_combat_posture(posture: NPC.CombatPosture) -> void:
	npc.combat_posture = posture


func set_heard_target(position: Vector3) -> NPCHeardTargetMarker:
	if not is_instance_valid(heard_target_marker):
		heard_target_marker = HEARD_TARGET_MARKER_SCENE.instantiate()
		# Keep the marker fixed in world space, but owned by the NPC so it
		# cannot outlive a temporary playtest or level instance.
		heard_target_marker.top_level = true
		npc.add_child(heard_target_marker)
	heard_target_marker.global_position = position
	return heard_target_marker


func clear_heard_target() -> void:
	if is_instance_valid(heard_target_marker):
		heard_target_marker.queue_free()
	heard_target_marker = null


func _exit_tree() -> void:
	clear_heard_target()


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
	_update_perceived_enemy()
	if current_state:
		current_state.physics_process(delta)


func _update_perceived_enemy() -> void:
	if not is_instance_valid(perceived_enemy):
		perceived_enemy = null
		return
	if perceived_enemy.health <= 0.0:
		perceived_enemy = null
		return
	if perception.is_node_visible(perceived_enemy):
		last_visible_position = perceived_enemy.global_position
		return

	perceived_enemy = null
	lost_target(last_visible_position)


func _on_heard(position: Vector3) -> void:
	if current_state:
		current_state.heard(position)


func _on_spotted(enemy: Character) -> void:
	track_visible_enemy(enemy)
	if current_state:
		current_state.spotted(enemy)


func _on_told(position: Vector3) -> void:
	if current_state:
		current_state.told(position)


func _on_died() -> void:
	if current_state:
		current_state.exit()
	current_state = null
	perceived_enemy = null
	clear_heard_target()
	set_emotes(false, false)
	combat.throw_weapon()
	npc.looking_at = Vector3.ZERO
	npc.target = null
	npc.moving_to = null
	npc.set_physics_process(false)
	set_physics_process(false)
