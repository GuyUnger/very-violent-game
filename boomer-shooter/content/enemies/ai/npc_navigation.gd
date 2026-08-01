class_name NPCNavigation
extends Node

var npc
var grid_navigation: GridNavigation
var path: Array[Vector3] = []
var path_index := 0
var destination := Vector3.ZERO
var moving := false


func setup(p_npc) -> void:
	npc = p_npc
	grid_navigation = get_tree().get_first_node_in_group(
		&"grid_navigation") as GridNavigation


func move_to(target_position: Vector3) -> bool:
	if not is_instance_valid(grid_navigation):
		grid_navigation = get_tree().get_first_node_in_group(
			&"grid_navigation") as GridNavigation
	if not is_instance_valid(grid_navigation):
		return false
	path = grid_navigation.find_path(npc.global_position, target_position)
	if path.is_empty():
		return false
	destination = target_position
	path_index = 0
	if path[0].distance_squared_to(npc.global_position) < 0.09:
		path_index = 1
	moving = path_index < path.size()
	return moving


func stop() -> void:
	moving = false
	path.clear()
	path_index = 0
	if is_instance_valid(npc):
		npc.velocity = Vector3.ZERO


func is_finished() -> bool:
	return not moving


func _physics_process(delta: float) -> void:
	if not is_instance_valid(npc) or npc.health <= 0.0:
		stop()
		set_physics_process(false)
		return
	if not npc.navigation_enabled:
		stop()
		return
	if is_instance_valid(npc.moving_to):
		if (
			not moving
			or destination.distance_squared_to(
				npc.moving_to.global_position) > 0.09
		):
			move_to(npc.moving_to.global_position)
	if not moving:
		npc.velocity = Vector3.ZERO
		return

	var next_position := path[path_index]
	var flat_delta: Vector3 = next_position - npc.global_position
	flat_delta.y = 0.0
	if flat_delta.length_squared() <= 0.0225:
		path_index += 1
		if path_index >= path.size():
			stop()
			return
		next_position = path[path_index]
		flat_delta = next_position - npc.global_position
		flat_delta.y = 0.0

	var direction: Vector3 = flat_delta.normalized()
	var movement_speed: float = (
		npc.speed * npc.speed_scale * npc.speed_scale_knock_back)
	npc.velocity = direction * movement_speed
	npc.look_at_node_y_axis_lerp(next_position, delta, 7.0)
	npc.move_and_slide()
