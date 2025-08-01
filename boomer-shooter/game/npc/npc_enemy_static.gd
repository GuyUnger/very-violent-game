@tool
extends NPCEnemy
class_name NPCEnemyStatic

func _ready() -> void:
	add_child(StateIdle.new())

class State extends Node:
	func _ready() -> void:
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


class StateIdle extends State:
	func _ready() -> void:
		super()

		get_parent().get_node("%Vision").monitoring = false
		get_parent().get_node("%Vision").monitoring = true
		get_parent().get_node("%Vision").body_entered.connect(_body_entered_vision)
		get_parent().target = null
		get_parent().moving_to = null
		
		get_parent().heard.connect(_heard)
		get_parent().told_enemy_position.connect(_told_enemy_position)

	func _heard(position:Vector3) -> void:
		get_parent().looking_at = position
		
	func _told_enemy_position(enemy) -> void:
		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)

	func _body_entered_vision(body) -> void:
		var next_state = StateSpottedEnemy.new()
		next_state.enemy = body
		move_to(next_state)
	
	
	func _exit_tree() -> void:
		get_parent().heard.disconnect(_heard)
		get_parent().told_enemy_position.disconnect(_told_enemy_position)
		
		var vision := get_parent().get_node_or_null("%Vision")
		if vision:
			vision.body_entered.disconnect(_body_entered_vision)
		

class StateSpottedEnemy extends State:
	var enemy:Node3D

	func _ready() -> void:
		super()

		get_parent().animation_tree.set("parameters/Special/transition_request", "Panic")
		get_parent().target = enemy
		await get_tree().create_timer(1.0).timeout
		get_parent().animation_tree.set("parameters/Special/transition_request", "Moving")
		
		for node in get_tree().get_nodes_in_group("npc_enemies"):
			if node != get_parent() and node.global_position.distance_squared_to(get_parent().global_position) < 10:
				node._told_enemy_position(enemy)

		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)


class StateAttacking extends State:
	var enemy:Node3D
	
	
	func _ready() -> void:
		super()

		get_parent().target = enemy
		#get_parent().moving_to = enemy
		
	func _physics_process(delta: float) -> void:
		var weapon = get_parent().get_node("%Weapon")	
		
		if not get_parent().is_node_visible(enemy):
			weapon.trigger_pressed = false
			move_to(StateIdle.new())
			return

		
		
		var ds = enemy.global_position.distance_squared_to(get_parent().global_position)
		
		get_parent().speed_scale = lerp(0.0, 1.0, clamp(ds / 3.0, 0.0, 1.0))
		
		if ds < 1.0:
			get_parent().speed_scale = 0.0
		
		weapon.aim_dir = weapon.global_position.direction_to(enemy.global_position + Vector3.UP)
		weapon.trigger_pressed = true
		
		
	func _exit_tree() -> void:
		var weapon = get_parent().get_node("%Weapon")
		if weapon:
			weapon.trigger_pressed = false
			
func hit(damage:int) -> void:
	holes += 1
	super(damage)
