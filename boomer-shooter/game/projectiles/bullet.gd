class_name Bullet
extends Node3D

var speed := 40.0
@export var damage := 1
@export var knock_back := 1

var track_in_event_store := false
var source_id := 0
var is_ghost := false
var collision_mask := 1 + 4

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("npc_enemies"):
		node._heard(global_position)
	
	var from_position: Vector3 = global_position
	
	
	if source_id != 0:
		is_ghost = true
	elif track_in_event_store:
		source_id = EventStore.next_source_id()
		EventStore.push_event(EventStoreCommandAddChild.new(get_parent().source_id, source_id, load(scene_file_path), global_transform))
		EventStore.push_event(EventStoreCommandSet.new(source_id, "collision_mask", collision_mask))
	
	if source_id != 0:
		EventStore.register_source(source_id, self)
	
	await get_tree().process_frame
	
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.from = global_position
	query.to = global_position + global_transform.basis.z.normalized() * 100.0
	
	var target_position: Vector3
	var res := get_world_3d().direct_space_state.intersect_ray(query)
	if res:
		if not is_ghost and res.collider is Character:
			Main.player.animate_crosshair()
		target_position = res.position
	else:
		target_position = global_position + global_transform.basis.z.normalized() * 100.0
	
	var distance := global_position.distance_to(target_position)
	var duration: float = distance / 250.0
	
	$Mesh.scale.z = distance
	
	position = target_position
	
	await get_tree().physics_frame
	var tween := create_tween()
	tween.tween_property($Mesh, "scale:z", 0.0, duration)
	
	if is_ghost:
		$Fire.global_position = from_position
		$Fire.pitch_scale = randf_range(1.0, 1.2)
		$Fire.play()
	
	await tween.finished
	
	$Whiz.pitch_scale = randf_range(0.9, 1.3)
	$Whiz.play()
	if res:
		hit(res.collider, res.normal, res.position)


#func _physics_process(delta: float) -> void:
	#if not is_ghost:
		#var direction = global_transform.basis.z.normalized()
		#global_position += direction * delta * speed
		
		#if track_in_event_store:
			#EventStore.push_event(EventStoreCommandSet.new(source_id, "global_transform", global_transform))


func hit(collider:Node3D, normal:Vector3, hit_position:Vector3) -> void:
	#await get_tree().create_timer(position.distance_to(hit_position) / speed).timeout
	#set_physics_process(false)

	#global_position = hit_position
	var bounce_vel = (-global_transform.basis.z).bounce(normal)
	look_at(global_position + bounce_vel, Vector3.UP)
	#$Mesh.hide()
	
	if not is_instance_valid(collider):
		return
	if collider is not Character:
		$HitMetal.global_position = hit_position
		#$HitMetal.pitch_scale = randf_range(0.9, 1.2)
		$HitMetal.play()
		if has_node("Sparks"):
			$Sparks.show()
			$Sparks.emitting = true
	else:
		$HitMeat.global_position = hit_position
		$HitMeat.pitch_scale = randf_range(0.9, 1.2)
		$HitMeat.play()
		var x := preload("res://game/fx/blood_splat.tscn").instantiate()
		x.position = hit_position
		x.look_at_from_position(x.position, x.position + normal * 10.0)
		add_child(x)

		collider.hit(self)
	
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		queue_free()
