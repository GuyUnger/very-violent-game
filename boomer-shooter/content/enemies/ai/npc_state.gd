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

	func told(_position: Vector3) -> void:
		pass

	func lost_target(_last_known_position: Vector3) -> void:
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

	func told(position: Vector3) -> void:
		var next_state := BlindAttack.new()
		next_state.target_position = position
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
			brain.reset_combat_posture()
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
			var next_state := BlindAttack.new()
			next_state.target_position = heard_position
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

	func lost_target(last_known_position: Vector3) -> void:
		npc.alert_other_enemies(last_known_position)
		enemy = null
		heard_position = last_known_position
		react_to_heard = true
		npc.target = brain.set_heard_target(last_known_position)

class BlindAttack extends State:
	var target_position := Vector3.ZERO

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(false, true)
		if not brain.combat.begin(true, true):
			brain.transition(Idle.new())
			return
		npc.target = brain.set_heard_target(target_position)
		npc.looking_at = Vector3.ZERO
		brain.reset_combat_posture()
		brain.perception.poll()

	func physics_process(delta: float) -> void:
		npc.speed_scale = 0.0
		if not is_instance_valid(brain.heard_target_marker):
			brain.transition(Idle.new())
			return
		npc.target = brain.heard_target_marker
		brain.combat.update_aim(
			brain.heard_target_marker.get_center_pos(),
			delta)

	func heard(position: Vector3) -> void:
		target_position = position
		npc.target = brain.set_heard_target(position)

	func told(position: Vector3) -> void:
		target_position = position
		npc.target = brain.set_heard_target(position)

	func spotted(enemy: Character) -> void:
		npc.play_alert_sound()
		var next_state := Surprised.new()
		next_state.enemy = enemy
		brain.transition(next_state)

	func exit() -> void:
		brain.combat.stop()
		brain.clear_heard_target()


class Attacking extends State:
	var enemy: Node3D
	var alert_time_left := 0.0
	var alerted_other_enemies := false

	func enter(p_brain) -> void:
		super(p_brain)
		brain.set_emotes(false, true)
		if npc.health <= 0 or not brain.combat.begin():
			brain.transition(Idle.new())
			return
		npc.target = enemy
		alert_time_left = randf_range(2.0, 3.0)
		_request_weapon_animation()

	func physics_process(delta: float) -> void:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			brain.transition(Idle.new())
			return

		if not alerted_other_enemies:
			alert_time_left -= delta
			if alert_time_left <= 0.0:
				alerted_other_enemies = true
				npc.alert_other_enemies(brain.last_visible_position)

		var distance_squared := enemy.global_position.distance_squared_to(
			npc.global_position)
		var target_distance := sqrt(distance_squared)
		var prone_threshold: float = minf(
			npc.prone_distance_threshold,
			npc.crouched_distance_threshold)
		var crouched_threshold: float = maxf(
			npc.prone_distance_threshold,
			npc.crouched_distance_threshold)
		var posture = npc.CombatPosture.STANDING
		if target_distance < prone_threshold:
			posture = npc.CombatPosture.PRONE
		elif target_distance <= crouched_threshold:
			posture = npc.CombatPosture.CROUCHED
		brain.update_combat_posture(posture)

		brain.combat.update_aim(enemy.get_center_pos(), delta)

	func lost_target(last_known_position: Vector3) -> void:
		npc.alert_other_enemies(last_known_position)
		var next_state := BlindAttack.new()
		next_state.target_position = last_known_position
		brain.transition(next_state)

	func exit() -> void:
		brain.combat.stop()
