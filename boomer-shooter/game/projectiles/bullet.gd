extends Node3D

@export var speed := 30.0

var source_id := 0
var is_ghost := false


func _ready() -> void:
	if source_id == 0:
		source_id = EventStore.next_source_id()
		EventStore.push_event(EventStoreCommandAddChild.new(get_parent().source_id, source_id, load(scene_file_path)))
	else:
		is_ghost = true
	
	EventStore.register_source(source_id, self)
	
	await get_tree().process_frame
	
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 4 + 1
	query.collide_with_bodies = true
	query.from = global_position
	query.to = global_position + global_transform.basis.z.normalized() * 100.0
	
	var res := get_world_3d().direct_space_state.intersect_ray(query)
	if res:
		hit(res.collider, res.normal, res.position)
	
	await get_tree().create_timer(randf_range(0.0, 0.1)).timeout
	$Whiz.pitch_scale = randf_range(0.9, 1.3)
	$Whiz.play()


func _physics_process(delta: float) -> void:
	if not is_ghost:
		var direction = global_transform.basis.z.normalized()
		global_position += direction * delta * speed
		
		EventStore.push_event(EventStoreCommandSet.new(source_id, "global_transform", global_transform))


func hit(npc, normal:Vector3, hit_position:Vector3) -> void:
	await get_tree().create_timer(position.distance_to(hit_position) / speed).timeout
	speed = 0.0
	global_position = hit_position
	var bounce_vel = (-global_transform.basis.z).bounce(normal)
	look_at(global_position + bounce_vel, Vector3.UP)
	$MeshInstance3D.hide()
	$Sparks.show()
	$Sparks.emitting = true
	
	
	if npc is not NPC:
		$HitMetal.global_position = hit_position
		#$HitMetal.pitch_scale = randf_range(0.9, 1.2)
		$HitMetal.play()
	else:
		$HitMeat.global_position = hit_position
		$HitMeat.pitch_scale = randf_range(0.9, 1.2)
		$HitMeat.play()
		
		npc.health -= 1
		npc.knock_back(normal * 0.001)
	
	await get_tree().create_timer(1.0).timeout
	hide()