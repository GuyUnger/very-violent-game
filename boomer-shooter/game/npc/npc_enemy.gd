@tool
extends NPC
class_name NPCEnemy

class State extends Node:
	
	
	func move_to(state:State) -> void:
		queue_free()
		var p := get_parent()
		p.remove_child(self)
		p.add_child(state)


class StateIdle extends State:
	
	
	func _ready() -> void:
		get_parent().get_node("%Vision").body_entered.connect(_body_entered_vision)
	
	
	func _body_entered_vision(body) -> void:
		var next_state = StateSpottedEnemy.new()
		next_state.enemy = body
		move_to(next_state)
	
	
	func _exit_tree() -> void:
		get_parent().get_node("%Vision").body_entered.disconnect(_body_entered_vision)


class StateSpottedEnemy extends State:
	var enemy:Node3D
	
	
	func _ready() -> void:
		get_parent().animation_tree.set("parameters/Special/transition_request", "Panic")
		get_parent().target = enemy
		await get_tree().create_timer(2.0).timeout
		get_parent().animation_tree.set("parameters/Special/transition_request", "Moving")
		
		var next_state = StateAttacking.new()
		next_state.enemy = enemy
		move_to(next_state)


class StateAttacking extends State:
	var enemy:Node3D
	
	
	func _ready() -> void:
		get_parent().target = enemy
		get_parent().moving_to = enemy
	
	
	func _physics_process(delta: float) -> void:
		var ds = enemy.global_position.distance_squared_to(get_parent().global_position)
		
		get_parent().speed_scale = lerp(0.0, 1.0, clamp(ds / 3.0, 0.0, 1.0))
		
		if ds < 1.0:
			get_parent().speed_scale = 0.0


func hit(damage:int) -> void:
	health -= damage
	if health <= 0:
		set_physics_process(false)
		await get_tree().create_timer(1.0).timeout
		queue_free()