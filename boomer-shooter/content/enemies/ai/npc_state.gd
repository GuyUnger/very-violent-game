class_name NPCState
extends RefCounted


class State extends RefCounted:
	var brain
	var npc

	func enter(p_brain) -> void:
		brain = p_brain
		npc = brain.npc

	func exit() -> void:
		pass

	func physics_process(_delta: float) -> void:
		pass

	func heard(_position: Vector3) -> void:
		pass

	func spotted(_enemy: Character) -> void:
		pass

	func told(_enemy: Node3D) -> void:
		pass

	func _request_weapon_animation() -> void:
		pass


class Idle extends State:
	func enter(p_brain) -> void:
		super(p_brain)
		npc.speed_scale = 1.0
		npc.target = null
		npc.moving_to = null
		if npc.navigation:
			npc.navigation.stop()
		brain.reset_combat_posture()
		brain.perception.poll()

	func heard(position: Vector3) -> void:
		brain.set_heard_target(position)
		var next_state := Surprised.new()
		next_state.heard_position = position
		next_state.react_to_heard = true
		brain.transition(next_state)

	func spotted(enemy: Character) -> void:
		npc.play_alert_sound()
		var next_state := Surprised.new()
		next_state.enemy = enemy
		brain.transition(next_state)

	func told(enemy: Node3D) -> void:
		var next_state := WasToldEnemyPosition.new()
		next_state.enemy = enemy
		brain.transition(next_state)

class Surprised extends State:
	var enemy: Node3D
	var heard_position := Vector3.ZERO
	var react_to_heard := false
	var time_left := 0.0

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(true, false)
		brain.combat.stop()
		time_left = npc.surprised_time
		npc.speed_scale = 0.0
		if is_instance_valid(enemy):
			npc.target = enemy
			brain.update_combat_posture(
				npc.global_position.distance_to(enemy.global_position))
		else:
			npc.target = brain.set_heard_target(heard_position)
			brain.reset_combat_posture()
			npc.looking_at = Vector3.ZERO
		_request_weapon_animation()

	func physics_process(delta: float) -> void:
		time_left -= delta
		npc.speed_scale = 0.0

		if is_instance_valid(enemy):
			if enemy.health <= 0:
				brain.transition(Idle.new())
				return

		if time_left > 0.0:
			return

		if react_to_heard:
			var next_state := HeardEnemy.new()
			next_state.heard_position = heard_position
			brain.transition(next_state)
		else:
			var next_state := Attacking.new()
			next_state.enemy = enemy
			brain.transition(next_state)

	func heard(position: Vector3) -> void:
		if not react_to_heard:
			return
		heard_position = position
		npc.target = brain.set_heard_target(position)


class WasToldEnemyPosition extends State:
	var enemy: Node3D
	var time_left := 0.3

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(false, true)
		npc.target = enemy
		if is_instance_valid(enemy):
			brain.update_combat_posture(
				npc.global_position.distance_to(enemy.global_position))
		_request_weapon_animation()

	func physics_process(delta: float) -> void:
		time_left -= delta
		if time_left > 0.0:
			return
		if not is_instance_valid(enemy):
			brain.transition(Idle.new())
			return
		var next_state := Attacking.new()
		next_state.enemy = enemy
		brain.transition(next_state)


class HeardEnemy extends State:
	var heard_position := Vector3.ZERO
	var attack_time_left := 0.0

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(false, true)
		if not brain.combat.begin():
			brain.transition(Idle.new())
			return
		attack_time_left = npc.heard_enemy_attack_time
		npc.target = brain.set_heard_target(heard_position)
		npc.looking_at = Vector3.ZERO
		brain.reset_combat_posture()

	func physics_process(delta: float) -> void:
		attack_time_left -= delta
		if attack_time_left <= 0.0:
			brain.transition(Idle.new())
			return

		npc.speed_scale = 0.0
		if not is_instance_valid(brain.heard_target_marker):
			brain.transition(Idle.new())
			return
		npc.target = brain.heard_target_marker
		brain.combat.update_aim(
			brain.heard_target_marker.get_center_pos(),
			delta)

	func heard(position: Vector3) -> void:
		heard_position = position
		npc.target = brain.set_heard_target(position)

	func spotted(enemy: Character) -> void:
		npc.play_alert_sound()
		var next_state := Surprised.new()
		next_state.enemy = enemy
		brain.transition(next_state)

	func told(enemy: Node3D) -> void:
		var next_state := WasToldEnemyPosition.new()
		next_state.enemy = enemy
		brain.transition(next_state)

	func exit() -> void:
		brain.combat.stop()
		brain.clear_heard_target()


class Attacking extends State:
	var enemy: Node3D

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(false, true)
		if npc.health <= 0 or not brain.combat.begin():
			brain.transition(Idle.new())
			return
		npc.target = enemy
		_request_weapon_animation()

	func physics_process(delta: float) -> void:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			brain.transition(Idle.new())
			return
		if not brain.perception.is_node_visible(enemy):
			brain.transition(Idle.new())
			return

		var distance_squared := enemy.global_position.distance_squared_to(
			npc.global_position)
		brain.update_combat_posture(sqrt(distance_squared))
		npc.speed_scale = lerp(
			0.0,
			1.0,
			clamp(distance_squared / 3.0, 0.0, 1.0))
		if distance_squared < 1.0:
			npc.speed_scale = 0.0

		brain.combat.update_aim(enemy.global_position + Vector3.UP, delta)

	func exit() -> void:
		brain.combat.stop()


class MoveAndAttack extends State:
	var enemy: Node3D
	var last_known_target_position := Vector3.ZERO

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(false, true)
		if npc.health <= 0 or not brain.combat.begin(true):
			brain.transition(Idle.new())
			return
		if is_instance_valid(enemy):
			last_known_target_position = enemy.global_position
		_request_weapon_animation()

	func physics_process(delta: float) -> void:
		npc.speed_scale = 1.0
		if is_instance_valid(enemy):
			if enemy.health <= 0:
				brain.transition(Idle.new())
				return
			if brain.perception.is_node_visible(enemy):
				last_known_target_position = enemy.global_position
				npc.target = enemy
				brain.update_combat_posture(
					npc.global_position.distance_to(enemy.global_position))
			else:
				enemy = null
				npc.target = null
				brain.reset_combat_posture()
				brain.perception.poll()
		else:
			npc.target = null
			brain.reset_combat_posture()

		brain.combat.update_aim(
			last_known_target_position + Vector3.UP,
			delta)

	func spotted(p_enemy: Character) -> void:
		enemy = p_enemy
		last_known_target_position = enemy.global_position
		brain.combat.reset_target_lock()

	func told(p_enemy: Node3D) -> void:
		enemy = p_enemy
		last_known_target_position = enemy.global_position
		brain.combat.reset_target_lock()

	func exit() -> void:
		brain.combat.stop()
