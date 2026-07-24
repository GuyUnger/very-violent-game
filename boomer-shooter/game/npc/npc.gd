extends Character
class_name NPC

signal died
signal heard
signal told_enemy_position
signal spotted_enemy

@export var target_lock_time := 0.3
@export var heard_enemy_attack_time := 1.2
@export var attack_shot_delay_range := Vector2(0.4, 0.9)
@export var surprised_time := 1.0
@export_range(0.0, 2.0, 0.01) var attack_vertical_spread := 0.35
@export var auto_burst_shot_range := Vector2i(3, 6)
@export var ignore_player_hearing := false
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
var polling_vision := false

func set_holes(value:int) -> void:
	holes = value

func set_cuts(value:int) -> void:
	cuts = value

func set_target(node:Node3D) -> void:
	target = node
	
func _ready() -> void:
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
	var target_position = node.global_position + Vector3.UP * 1.0
	if node is Character:
		target_position = node.center_pos
	query.from = %Vision.global_position
	query.to = target_position
	query.collide_with_bodies = true
	query.collision_mask = 1 + 2 + 8
	
	var res = get_world_3d().direct_space_state.intersect_ray(query)
	if res and res.collider == node:
		return true

	return false


func _heard(sound_position:Vector3) -> void:
	if ignore_player_hearing:
		return
	heard.emit(sound_position)


func _told_enemy_position(enemy) -> void:
	told_enemy_position.emit(enemy)


func roll_attack_shot_delay() -> float:
	var delay_min := minf(attack_shot_delay_range.x, attack_shot_delay_range.y)
	var delay_max := maxf(attack_shot_delay_range.x, attack_shot_delay_range.y)
	if is_equal_approx(delay_min, delay_max):
		return delay_min
	return randf_range(delay_min, delay_max)


func roll_auto_burst_shot_count() -> int:
	var shot_min := mini(auto_burst_shot_range.x, auto_burst_shot_range.y)
	var shot_max := maxi(auto_burst_shot_range.x, auto_burst_shot_range.y)
	if shot_max <= 0:
		return 1
	if shot_min == shot_max:
		return maxi(shot_min, 1)
	return randi_range(maxi(shot_min, 1), shot_max)


func melee() -> void:
	health = 0
	if has_node("%AudioMeleeSlash"):
		%AudioMeleeSlash.play()
	die()
	cuts += 1


func hit(damage: int) -> void:
	holes += 1
	
	if health <= 0:
		return

	#knock_back(from.knock_back * 0.01 * from.transform.basis.z)
	
	#if "is_ghost" in from and not from.is_ghost:
	#	$AudioHurt.unit_size = 30
	#	$AudioHurt.volume_db = 4.0
	#else:
	#$AudioHurt.unit_size = 10
	#$AudioHurt.volume_db = 0.0
	$AudioHurt.play()
	
	super(damage)


func die() -> void:
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	set_physics_process(false)
	remove_from_group("aimables")
	died.emit()
	
	var weapon = get_parent().get_node("%Weapon")
	if is_instance_valid(weapon):
		weapon.trigger_pressed = false
	Main.instance.enemy_killed.emit()


func _body_entered_vision(body) -> void:
	if is_node_visible(body):
		spotted_enemy.emit(body)
	else:
		poll_vision()

func poll_vision() -> void:
	if polling_vision:
		return
		
	polling_vision = true
	var bodies = %Vision.get_overlapping_bodies()
	
	while not bodies.is_empty():
		for node in bodies:

			await get_tree().process_frame
			if not is_inside_tree():
				polling_vision = false
				return
			
			if is_node_visible(node):
				spotted_enemy.emit(node)
				polling_vision = false
				return
				
		bodies = %Vision.get_overlapping_bodies()
	
	polling_vision = false


class State extends Node:
	func _ready() -> void:
		
		var weapon = get_parent().get_node("%Weapon")
		if weapon:
			weapon.enemy = get_parent()
			weapon.hide_glow()
		_set_emote_visibility(false, false)
		get_parent().died.connect(_died)
	
	func move_to(state:State) -> void:
		queue_free()
		var p := get_parent()
		p.remove_child(self)
		p.add_child(state)
		
	func _died() -> void:
		var weapon = get_parent().get_node("%Weapon")
		if weapon:
			weapon.throw(Vector3.UP * 5.0)
		
		get_parent().looking_at = Vector3.ZERO
		get_parent().target = null
		get_parent().moving_to = null
		get_parent().set_physics_process(false)
		queue_free()
		
	func _exit_tree() -> void:
		_set_emote_visibility(false, false)
		get_parent().died.disconnect(_died)

	func _set_emote_visibility(show_startled: bool, show_attacking: bool) -> void:
		var startled = get_parent().get_node_or_null("Startled")
		if startled == null:
			startled = get_parent().get_node_or_null("Spotted")
		if startled:
			startled.visible = show_startled

		var attacking = get_parent().get_node_or_null("Attacking")
		if attacking:
			attacking.visible = show_attacking


class StateIdle extends State:
	func _ready() -> void:
		super()

		get_parent().target = null
		get_parent().moving_to = null
		
		get_parent().spotted_enemy.connect(_spotted_enemy)
		get_parent().heard.connect(_heard)
		get_parent().told_enemy_position.connect(_told_enemy_position)

		get_parent().poll_vision()
	
	func _heard(position:Vector3) -> void:
		var next_state = StateSurprised.new()
		next_state.heard_position = position
		next_state.react_to_heard = true
		move_to(next_state)
		
	func _told_enemy_position(enemy) -> void:
		var next_state = StateWasToldEnemyPosition.new()
		next_state.enemy = enemy
		move_to(next_state)

	func _spotted_enemy(enemy) -> void:
		var next_state = StateSurprised.new()
		next_state.enemy = enemy
		next_state.react_to_heard = false
		move_to(next_state)

	func _exit_tree() -> void:
		super()
		get_parent().heard.disconnect(_heard)
		get_parent().spotted_enemy.disconnect(_spotted_enemy)
		get_parent().told_enemy_position.disconnect(_told_enemy_position)


class StateSpottedEnemy extends State:
	var enemy:Node3D

	func _ready() -> void:
		super()
		_set_emote_visibility(false, true)
		
		get_parent().target = enemy

		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

		for node in get_tree().get_nodes_in_group("npc_enemies"):
			if node != get_parent() and node.global_position.distance_squared_to(get_parent().global_position) < 50:
				node._told_enemy_position(enemy)
		
		var wait_delay = [3.0, 1.2, 0.5][Settings.difficulty]
		await get_tree().create_timer(wait_delay).timeout

		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)
		
	func _physics_process(delta: float) -> void:
		var weapon = get_parent().get_node("%Weapon")
		if weapon:
			weapon.look_at(enemy.global_position, Vector3.UP, true)
		
	func _exit_tree() -> void:
		super()
	

class StateSurprised extends State:
	var enemy: Node3D
	var heard_position := Vector3.ZERO
	var react_to_heard := false
	var surprise_time_left := 0.0
	var weapon

	func _ready() -> void:
		super()
		_set_emote_visibility(true, false)

		weapon = get_parent().get_node_or_null("%Weapon")
		surprise_time_left = get_parent().surprised_time
		get_parent().moving_to = null
		get_parent().speed_scale = 0.0
		if enemy:
			get_parent().target = enemy
		else:
			get_parent().target = null
			get_parent().looking_at = heard_position

		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

	func _physics_process(delta: float) -> void:
		surprise_time_left -= delta
		get_parent().speed_scale = 0.0
		if is_instance_valid(weapon):
			weapon.trigger_pressed = false

		if enemy:
			if not is_instance_valid(enemy) or enemy.health <= 0:
				move_to(StateIdle.new())
				return
			if is_instance_valid(weapon):
				weapon.look_at(enemy.global_position, Vector3.UP, true)
		else:
			get_parent().looking_at = heard_position
			if is_instance_valid(weapon):
				weapon.look_at(heard_position, Vector3.UP, true)

		if surprise_time_left > 0.0:
			return

		if react_to_heard:
			var next_heard := StateHeardEnemy.new()
			next_heard.heard_position = heard_position
			move_to(next_heard)
		else:
			var next_attacking := StateAttacking.new()
			next_attacking.enemy = enemy
			move_to(next_attacking)


class StateWasToldEnemyPosition extends State:
	var enemy:Node3D

	func _ready() -> void:
		super()
		_set_emote_visibility(false, true)
		
		get_parent().target = enemy

		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

		await get_tree().create_timer(0.3).timeout

		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)
		
	func _physics_process(delta: float) -> void:
		var weapon = get_parent().get_node("%Weapon")
		if weapon:
			weapon.look_at(enemy.global_position, Vector3.UP, true)


class StateHeardEnemy extends State:
	var heard_position := Vector3.ZERO
	var attack_time_left := 0.0
	var target_lock := 0.0
	var shot_delay_left := 0.0
	var waiting_for_shot := false
	var burst_shots_left := 0
	var weapon

	func _ready() -> void:
		super()
		_set_emote_visibility(false, true)

		weapon = get_parent().get_node_or_null("%Weapon")
		if not weapon:
			queue_free()
			return

		attack_time_left = get_parent().heard_enemy_attack_time
		target_lock = get_parent().target_lock_time
		shot_delay_left = 0.0
		waiting_for_shot = false
		burst_shots_left = _roll_burst_shots()
		get_parent().target = null
		get_parent().moving_to = null
		get_parent().looking_at = heard_position
		get_parent().spotted_enemy.connect(_spotted_enemy)
		get_parent().told_enemy_position.connect(_told_enemy_position)

	func _physics_process(delta: float) -> void:
		attack_time_left -= delta
		target_lock = max(0.0, target_lock - delta)
		shot_delay_left = max(shot_delay_left - delta, 0.0)

		if attack_time_left <= 0.0:
			weapon.trigger_pressed = false
			move_to(StateIdle.new())
			return

		weapon.look_at(heard_position, Vector3.UP, true)
		get_parent().speed_scale = 0.0
		get_parent().looking_at = heard_position

		var tl := minf(target_lock, 1.0)
		var miss := Vector3(
			tl * sign(randf_range(-0.5, 0.5)),
			randf_range(-get_parent().attack_vertical_spread, get_parent().attack_vertical_spread),
			tl * sign(randf_range(-0.5, 0.5)))
		var aim_dir = weapon.global_position.direction_to(heard_position + Vector3.UP + miss)

		weapon.aim_dir = aim_dir
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

	func _on_shot_fired() -> void:
		waiting_for_shot = false
		if weapon and weapon.auto:
			burst_shots_left -= 1
			if burst_shots_left > 0:
				shot_delay_left = 0.0
			else:
				shot_delay_left = get_parent().roll_attack_shot_delay()
				burst_shots_left = _roll_burst_shots()
		else:
			shot_delay_left = get_parent().roll_attack_shot_delay()

	func _roll_burst_shots() -> int:
		if weapon and weapon.auto:
			return get_parent().roll_auto_burst_shot_count()
		return 1

	func _spotted_enemy(enemy) -> void:
		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)

	func _told_enemy_position(enemy) -> void:
		var next_state = StateWasToldEnemyPosition.new()
		next_state.enemy = enemy
		move_to(next_state)

	func _exit_tree() -> void:
		super()
		if is_instance_valid(weapon):
			weapon.trigger_pressed = false
		get_parent().spotted_enemy.disconnect(_spotted_enemy)
		get_parent().told_enemy_position.disconnect(_told_enemy_position)


class StateAttacking extends State:
	var enemy:Node3D
	var target_lock := 0.0
	var shot_delay_left := 0.0
	var waiting_for_shot := false
	var burst_shots_left := 0
	var weapon

	func _ready() -> void:
		super()
		_set_emote_visibility(false, true)
		
		weapon = get_parent().get_node_or_null("%Weapon")
		if not weapon:
			queue_free()
			return
			
		if get_parent().health <= 0:
			queue_free()
			return
		
		target_lock = get_parent().target_lock_time
		shot_delay_left = 0.0
		waiting_for_shot = false
		burst_shots_left = _roll_burst_shots()
		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

		get_parent().target = enemy
		
		
	
		#get_parent().moving_to = enemy
		
	func _physics_process(delta: float) -> void:
		target_lock = max(0, target_lock - delta)
		shot_delay_left = max(shot_delay_left - delta, 0.0)

		weapon.look_at(enemy.global_position, Vector3.UP, true)
		
		if not get_parent().is_node_visible(enemy):
			weapon.trigger_pressed = false
			move_to(StateIdle.new())
			return
			
		if enemy.health <= 0:
			weapon.trigger_pressed = false
			move_to(StateIdle.new())
			return

		var ds = enemy.global_position.distance_squared_to(get_parent().global_position)
		
		get_parent().speed_scale = lerp(0.0, 1.0, clamp(ds / 3.0, 0.0, 1.0))
		
		if ds < 1.0:
			get_parent().speed_scale = 0.0
		
		
		var tl := target_lock
		tl = min(tl, 1.0)
		var miss := Vector3(
			tl * sign(randf_range(-0.5, 0.5)),
			randf_range(-get_parent().attack_vertical_spread, get_parent().attack_vertical_spread),
			tl * sign(randf_range(-0.5, 0.5)))
		
		var aim_dir = weapon.global_position.direction_to(enemy.global_position + Vector3.UP + miss)
		
		weapon.aim_dir = aim_dir
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

	func _on_shot_fired() -> void:
		waiting_for_shot = false
		if weapon and weapon.auto:
			burst_shots_left -= 1
			if burst_shots_left > 0:
				shot_delay_left = 0.0
			else:
				shot_delay_left = get_parent().roll_attack_shot_delay()
				burst_shots_left = _roll_burst_shots()
		else:
			shot_delay_left = get_parent().roll_attack_shot_delay()

	func _roll_burst_shots() -> int:
		if weapon and weapon.auto:
			return get_parent().roll_auto_burst_shot_count()
		return 1
		
		
	func _exit_tree() -> void:
		super()
		if is_instance_valid(weapon):
			weapon.trigger_pressed = false
