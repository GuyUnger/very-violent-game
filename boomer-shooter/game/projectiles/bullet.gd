class_name Bullet
extends Node3D

const PENETRATION_TRACE_EPSILON := 0.001

var speed := 40.0
@export var damage := 1
@export var knock_back := 1
@export var penetration_power := 0.0

var track_in_event_store := false
var source_id := 0
var is_ghost := false
var collision_mask := 1 + 4
var enemy
var target_position: Vector3:
	get:
		return target_position
	set(value):
		target_position = value
		var distance := global_position.distance_to(target_position)
		
		$Mesh.scale.z = distance

		await get_tree().physics_frame
		
		$Whiz.pitch_scale = randf_range(0.9, 1.3)
		$Whiz.play()


func _ready() -> void:
	if not is_instance_valid(enemy):
		var heard_position := global_position
		if is_instance_valid(Main.player):
			heard_position = Main.player.global_position

		for node in get_tree().get_nodes_in_group("npc_enemies"):
			node._heard(heard_position)
	
	var from_position: Vector3 = global_position
	
	
	if source_id != 0:
		is_ghost = true
	elif track_in_event_store:
		source_id = EventStore.next_source_id()
		EventStore.push_event(EventStoreCommandAddChild.new(get_parent().source_id, source_id, load(scene_file_path), global_transform))
		EventStore.push_event(EventStoreCommandSet.new(source_id, "collision_mask", collision_mask))
		EventStore.push_event(EventStoreCommandSet.new(source_id, "damage", damage))
	
	if source_id != 0:
		EventStore.register_source(source_id, self)
	

	await get_tree().process_frame
	
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.from = global_position
	query.to = global_position + global_transform.basis.z.normalized() * 100.0
	
	if not is_ghost:
		var trace_result := _trace_bullet_path(query)
		target_position = trace_result["target_position"]
		for impact in trace_result["impacts"]:
			_apply_impact(
				impact["collider"],
				impact["normal"],
				impact["position"],
				impact["stops_bullet"])
		
		EventStore.push_event(EventStoreCommandSet.new(source_id, "target_position", target_position))
	
	if is_ghost:
		$Fire.global_position = from_position
		$Fire.pitch_scale = randf_range(1.0, 1.2)
		$Fire.play()
	
	if is_inside_tree():
		await get_tree().create_timer(0.2).timeout
		queue_free()

#func _physics_process(delta: float) -> void:
	#if not is_ghost:
		#var direction = global_transform.basis.z.normalized()
		#global_position += direction * delta * speed
		
		#if track_in_event_store:
			#EventStore.push_event(EventStoreCommandSet.new(source_id, "global_transform", global_transform))


func _apply_impact(collider:Node3D, normal:Vector3, hit_position:Vector3, stops_bullet: bool = true) -> void:
	#await get_tree().create_timer(position.distance_to(hit_position) / speed).timeout
	#set_physics_process(false)

	#global_position = hit_position
	if not is_instance_valid(collider):
		return

	if collider is Wall and not stops_bullet:
		collider.hit(hit_position, normal, damage)
	elif collider is Prop:
		collider.hit(hit_position, normal, damage)
	
	if collider is not Character:
		if "shoot_active" in collider:
			collider.shoot_activate() 
		if "shoot_activate" in collider.get_parent():
			collider.get_parent().shoot_activate()
		$HitMetal.global_position = hit_position
		#$HitMetal.pitch_scale = randf_range(0.9, 1.2)
		$HitMetal.play()
	else:
		$HitMeat.global_position = hit_position
		$HitMeat.pitch_scale = randf_range(0.9, 1.2)
		$HitMeat.play()
		var x := preload("res://game/fx/blood_splat.tscn").instantiate()
		x.top_level = true
		x.global_position = hit_position
		x.look_at_from_position(x.position, x.position + normal * 10.0)
		add_child(x)
	
		collider.hit(damage)
		if enemy and "last_hit_enemy" in collider:
			collider.last_hit_enemy = enemy


func _trace_bullet_path(query: PhysicsRayQueryParameters3D) -> Dictionary:
	var direction := (query.to - query.from).normalized()
	var final_target := query.to
	var impacts: Array[Dictionary] = []
	var remaining_penetration := penetration_power
	var current_from := query.from
	var exclude: Array[RID] = []

	while true:
		query.from = current_from
		query.exclude = exclude
		var res := get_world_3d().direct_space_state.intersect_ray(query)
		if not res:
			final_target = query.to
			break

		var collider = res.collider
		var stops_bullet := true
		if collider is Wall:
			var stopping_power := _get_stopping_power(collider)
			if remaining_penetration >= stopping_power:
				remaining_penetration -= stopping_power
				stops_bullet = false

		if collider is Character and not enemy:
			Main.player.animate_crosshair()

		impacts.append({
			"collider": collider,
			"normal": res.normal,
			"position": res.position,
			"stops_bullet": stops_bullet,
		})

		if stops_bullet:
			final_target = res.position
			break

		var next_from = res.position + direction * PENETRATION_TRACE_EPSILON
		if next_from.distance_squared_to(current_from) <= PENETRATION_TRACE_EPSILON * PENETRATION_TRACE_EPSILON:
			final_target = res.position
			break
		exclude.append(collider.get_rid())
		current_from = next_from
		if current_from.distance_squared_to(query.to) < PENETRATION_TRACE_EPSILON * PENETRATION_TRACE_EPSILON:
			final_target = query.to
			break

	return {
		"target_position": final_target,
		"impacts": impacts,
	}


func _get_stopping_power(collider: Node) -> float:
	if collider.has_method("get_bullet_stopping_power"):
		return maxf(collider.get_bullet_stopping_power(), 0.0)
	return INF
