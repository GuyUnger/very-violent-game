class_name NPCCombat
extends Node

var npc
var weapon
var target_lock := 0.0
var shot_delay_left := 0.0
var waiting_for_shot := false
var burst_shots_left := 0
var use_move_attack_interval := false


func setup(p_npc) -> void:
	npc = p_npc
	weapon = npc.get_node_or_null("%Weapon")
	if weapon:
		weapon.enemy = npc
		weapon.hide_glow()


func begin(p_use_move_attack_interval := false) -> bool:
	if not is_instance_valid(weapon):
		return false
	use_move_attack_interval = p_use_move_attack_interval
	target_lock = npc.target_lock_time
	shot_delay_left = 0.0
	waiting_for_shot = false
	burst_shots_left = _roll_burst_shots()
	weapon.trigger_pressed = false
	return true


func update_aim(aim_position: Vector3, delta: float) -> void:
	if not is_instance_valid(weapon):
		return

	target_lock = maxf(target_lock - delta, 0.0)
	shot_delay_left = maxf(shot_delay_left - delta, 0.0)

	var lock_spread := minf(target_lock, 1.0)
	var miss := Vector3(
		lock_spread * sign(randf_range(-0.5, 0.5)),
		randf_range(-npc.attack_vertical_spread, npc.attack_vertical_spread),
		lock_spread * sign(randf_range(-0.5, 0.5)))
	miss += _get_intentional_miss_offset(weapon.global_position, aim_position)
	weapon.aim_dir = weapon.global_position.direction_to(aim_position + miss)

	if waiting_for_shot:
		weapon.trigger_pressed = true
		if weapon.reload_t > 0.0:
			_on_shot_fired()
	elif shot_delay_left <= 0.0 and weapon.reload_t <= 0.0:
		waiting_for_shot = true
		weapon.trigger_pressed = true
	else:
		weapon.trigger_pressed = false

	weapon.ammo = weapon.max_ammo


func stop() -> void:
	waiting_for_shot = false
	if is_instance_valid(weapon):
		weapon.trigger_pressed = false


func throw_weapon() -> void:
	stop()
	if is_instance_valid(weapon):
		weapon.throw(Vector3.UP * 5.0)


func reset_target_lock() -> void:
	target_lock = npc.target_lock_time


func _on_shot_fired() -> void:
	waiting_for_shot = false
	npc.intentional_misses_remaining = maxi(
		npc.intentional_misses_remaining - 1,
		0)

	if weapon.auto:
		burst_shots_left -= 1
		if burst_shots_left > 0:
			shot_delay_left = 0.0
			return
		burst_shots_left = _roll_burst_shots()

	shot_delay_left = _roll_shot_delay()


func _roll_shot_delay() -> float:
	var delay_range: Vector2 = (
		npc.move_attack_burst_interval_range
		if use_move_attack_interval
		else npc.attack_shot_delay_range)
	var delay_min := minf(delay_range.x, delay_range.y)
	var delay_max := maxf(delay_range.x, delay_range.y)
	if is_equal_approx(delay_min, delay_max):
		return delay_min
	return randf_range(delay_min, delay_max)


func _roll_burst_shots() -> int:
	if not weapon.auto:
		return 1
	var shot_min := maxi(mini(
		npc.auto_burst_shot_range.x,
		npc.auto_burst_shot_range.y), 1)
	var shot_max := maxi(maxi(
		npc.auto_burst_shot_range.x,
		npc.auto_burst_shot_range.y), 1)
	if shot_min == shot_max:
		return shot_min
	return randi_range(shot_min, shot_max)


func _get_intentional_miss_offset(
		from_position: Vector3,
		aim_position: Vector3) -> Vector3:
	if npc.intentional_misses_remaining <= 0:
		return Vector3.ZERO

	var to_target := aim_position - from_position
	var flat_direction := Vector3(to_target.x, 0.0, to_target.z)
	var miss_side := Vector3.RIGHT
	if not flat_direction.is_zero_approx():
		flat_direction = flat_direction.normalized()
		miss_side = Vector3(-flat_direction.z, 0.0, flat_direction.x)

	var side_sign := (
		-1.0
		if npc.intentional_misses_remaining % 2 == 0
		else 1.0)
	var miss_distance := maxf(1.5, to_target.length() * 0.35)
	return miss_side * miss_distance * side_sign
