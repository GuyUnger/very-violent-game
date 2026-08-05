class_name BloodSystem
extends Node3D

@export_range(1, 32, 1) var ray_budget_per_frame := 6
@export_range(1, 12, 1) var rays_per_spray := 4
@export_range(0.1, 20.0, 0.1) var spray_distance := 4.0
@export_range(0.0, 2.0, 0.01) var merge_distance := 0.25
@export_range(1, 256, 1) var maximum_queued_sprays := 48
@export_range(0.0, 1.0, 0.01) var cone_spread := 0.4

var pending_sprays: Array[Dictionary] = []


func request_spray(
		origin: Vector3,
		direction: Vector3,
		victim: CollisionObject3D
	) -> void:
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	var victim_id := victim.get_instance_id() if is_instance_valid(victim) else 0
	var merge_distance_squared := merge_distance * merge_distance
	for spray in pending_sprays:
		if (
			int(spray["victim_id"]) == victim_id
			and (spray["origin"] as Vector3).distance_squared_to(origin)
				<= merge_distance_squared
		):
			spray["origin"] = origin
			spray["direction"] = direction
			spray["next_ray"] = 0
			return

	if pending_sprays.size() >= maximum_queued_sprays:
		pending_sprays.pop_front()
	var excluded_rids: Array[RID] = []
	if is_instance_valid(victim):
		excluded_rids.append(victim.get_rid())
	pending_sprays.append({
		"origin": origin,
		"direction": direction,
		"victim_id": victim_id,
		"exclude": excluded_rids,
		"next_ray": 0,
		"seed": randf() * 1000.0,
	})


func _physics_process(_delta: float) -> void:
	var rays_processed := 0
	while rays_processed < ray_budget_per_frame and not pending_sprays.is_empty():
		var spray := pending_sprays[0]
		_process_spray_ray(spray)
		rays_processed += 1
		spray["next_ray"] = int(spray["next_ray"]) + 1
		if int(spray["next_ray"]) >= rays_per_spray:
			pending_sprays.pop_front()
		else:
			pending_sprays[0] = spray


func _process_spray_ray(spray: Dictionary) -> void:
	var direction := _get_ray_direction(spray)
	var origin: Vector3 = spray["origin"]
	var query := PhysicsRayQueryParameters3D.create(
		origin + direction * 0.03,
		origin + direction * spray_distance,
		1,
		spray["exclude"])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider := hit.get("collider") as Node
	if collider and collider.has_method("add_blood_splat"):
		collider.add_blood_splat(hit["position"], hit["normal"])


func _get_ray_direction(spray: Dictionary) -> Vector3:
	var ray_index := int(spray["next_ray"])
	var forward: Vector3 = spray["direction"]
	if ray_index == 0:
		return forward

	var side := forward.cross(Vector3.UP)
	if side.is_zero_approx():
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var up := side.cross(forward).normalized()
	var seed := float(spray["seed"]) + ray_index * 17.0
	var side_offset := sin(seed * 12.9898) * cone_spread
	var up_offset := sin(seed * 78.233 + 1.7) * cone_spread
	return (forward + side * side_offset + up * up_offset).normalized()
