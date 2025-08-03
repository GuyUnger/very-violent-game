extends Character
class_name NPC

signal died
signal heard
signal told_enemy_position
signal spotted_enemy

@export var target_lock_time := 0.3
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
	query.from = %Vision.global_position
	query.to = node.global_position + Vector3.UP * 1.
	query.collide_with_bodies = true
	query.collision_mask = 1 + 2 + 8
	
	var res = get_world_3d().direct_space_state.intersect_ray(query)
	if res and res.collider == node:
		return true

	return false


func _heard(sound_position:Vector3) -> void:
	heard.emit(sound_position)


func _told_enemy_position(enemy) -> void:
	told_enemy_position.emit(enemy)


func melee() -> void:
	health -= 5
	cuts += 1


func hit(from:Node3D) -> void:
	holes += 1
	
	if health <= 0:
		return

	
	knock_back(from.knock_back * 0.01 * from.transform.basis.z)
	
	if "is_ghost" in from and not from.is_ghost:
		$AudioHurt.unit_size = 30
		$AudioHurt.volume_db = 4.0
	else:
		$AudioHurt.unit_size = 10
		$AudioHurt.volume_db = 0.0
	$AudioHurt.play()
	
	health -= from.damage

	if health <= 0:

		die()


func die() -> void:
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	set_physics_process(false)
	remove_from_group("aimables")
	died.emit()


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
			weapon.hide_glow()
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
		get_parent().died.disconnect(_died)


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
		get_parent().looking_at = position
		
	func _told_enemy_position(enemy) -> void:
		var next_state = StateWasToldEnemyPosition.new()
		next_state.enemy = enemy
		move_to(next_state)

	func _spotted_enemy(enemy) -> void:
		var next_state = StateSpottedEnemy.new()
		next_state.enemy = enemy
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
		
		get_parent().target = enemy

		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

		for node in get_tree().get_nodes_in_group("npc_enemies"):
			if node != get_parent() and node.global_position.distance_squared_to(get_parent().global_position) < 50:
				node._told_enemy_position(enemy)
				
		await get_tree().create_timer(1.0).timeout

		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)

class StateWasToldEnemyPosition extends State:
	var enemy:Node3D

	func _ready() -> void:
		super()
		
		get_parent().target = enemy

		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

		await get_tree().create_timer(1.0).timeout

		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)


class StateAttacking extends State:
	var enemy:Node3D
	var target_lock := 0.0

	func _ready() -> void:
		super()
		
		target_lock = get_parent().target_lock_time
		var animation_tree = get_parent().get("animation_tree")
		if animation_tree:
			animation_tree.set("parameters/Holding/transition_request", "Pistol")

		get_parent().target = enemy
		#get_parent().moving_to = enemy
		
	func _physics_process(delta: float) -> void:
		target_lock = max(0, target_lock - delta)
		
		var weapon = get_parent().get_node("%Weapon")
		if not is_instance_valid(weapon):
			return queue_free()
		
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
		
		var miss := Vector3(
			target_lock * sign(randf_range(-0.5, 0.5)),
			target_lock * sign(randf_range(-0.5, 0.5)),
			target_lock * sign(randf_range(-0.5, 0.5)))
		
		var aim_dir = weapon.global_position.direction_to(enemy.global_position + Vector3.UP + miss)
		
		weapon.aim_dir = aim_dir
		weapon.trigger_pressed = true
		weapon.ammo = weapon.max_ammo
		
		
	func _exit_tree() -> void:
		super()
		var weapon = get_parent().get_node("%Weapon")
		if weapon:
			weapon.trigger_pressed = false
