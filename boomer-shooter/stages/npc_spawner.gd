extends Node3D

@export var npc_scene: PackedScene = preload("res://game/npc/npc_enemy_grunt.tscn")
@export var wave_spawn_counts: Array[int] = [5]
@export_range(0.0, 300.0, 0.1) var first_spawn_time := 0.0
@export_range(0.0, 300.0, 0.1) var wave_delay := 3.0
@export var patrol_waypoint_root: NodePath
var current_wave_npcs: Array[Node] = []
var spawning_wave := false
var wave_spawn_pending := false
var wave_index := 0


func _ready() -> void:
	_spawn_loop()


func _spawn_loop() -> void:
	if first_spawn_time > 0.0:
		await get_tree().create_timer(first_spawn_time).timeout
		if not is_inside_tree():
			return
	_spawn_wave()


func _spawn_wave() -> void:
	if spawning_wave or npc_scene == null:
		return
	var spawn_points := _get_spawn_points()
	if spawn_points.is_empty():
		return

	spawning_wave = true
	current_wave_npcs.clear()
	var wave_spawn_count := _get_wave_spawn_count()
	if wave_spawn_count <= 0:
		spawning_wave = false
		wave_index += 1
		_try_spawn_next_wave()
		return

	for _i in wave_spawn_count:
		var npc := npc_scene.instantiate()
		if npc is Node3D:
			var spawn_point: Node3D = spawn_points.pick_random()
			npc.global_transform = spawn_point.global_transform
		if not patrol_waypoint_root.is_empty() and "patrol_waypoint_root" in npc:
			npc.patrol_waypoint_root = patrol_waypoint_root
		get_parent().add_child(npc)
		current_wave_npcs.append(npc)

		if npc.has_signal("died"):
			npc.died.connect(_on_wave_npc_inactive.bind(npc))
		npc.tree_exited.connect(_on_wave_npc_inactive.bind(npc))

	wave_index += 1
	spawning_wave = false
	_try_spawn_next_wave()


func _on_wave_npc_inactive(npc: Node) -> void:
	var index := current_wave_npcs.find(npc)
	if index == -1:
		return

	current_wave_npcs.remove_at(index)
	_try_spawn_next_wave()


func _try_spawn_next_wave() -> void:
	if spawning_wave or wave_spawn_pending or not is_inside_tree():
		return
	if not current_wave_npcs.is_empty():
		return
	if _has_reached_final_wave():
		return
	_queue_next_wave()


func _queue_next_wave() -> void:
	wave_spawn_pending = true
	if wave_delay > 0.0:
		await get_tree().create_timer(wave_delay).timeout
		if not is_inside_tree():
			return
	wave_spawn_pending = false
	_spawn_wave()


func _get_spawn_points() -> Array[Node3D]:
	var spawn_points: Array[Node3D] = []
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)
	return spawn_points


func _get_wave_spawn_count() -> int:
	if wave_index < 0 or wave_index >= wave_spawn_counts.size():
		return 0
	return maxi(wave_spawn_counts[wave_index], 0)


func _has_reached_final_wave() -> bool:
	return wave_index >= wave_spawn_counts.size()
