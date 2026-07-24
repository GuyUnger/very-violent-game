@tool
extends StaticBody3D
class_name Wall

const HIT_TEXTURE_SIZE := 8
const MAX_HITS := HIT_TEXTURE_SIZE * HIT_TEXTURE_SIZE
const WALL_SPARKS_SCENE := preload("res://game/fx/wall_sparks.tscn")
const SNAP_COLLISION_LAYER := 1 << 19
const SNAP_POINT_GROUP := &"wall_snap_point"
const OPAQUE_COLLISION_LAYER := 1 << 4


@export_range(1, 1000, 1) var max_health := 5
@export var bullet_hole_size_range := Vector2(0.85, 1.2)
@export_range(0.0, 0.5, 0.001) var bullet_hole_merge_distance := 0.06
@export_range(0.01, 0.5, 0.01) var break_edge_width := 0.12
@export_range(0.0, 100.0, 0.1) var bullet_stopping_power := 1.0
@export var can_run_through := false
@export var opaque := true:
	set = set_opaque
@export var wall_color := Color.WHITE
@export var exclude_from_snap := false
@export_range(0.05, 1.0, 0.01) var snap_point_search_distance := 0.35
@export_tool_button("Snap To Nearby Wall") var snap_to_wall_action = _snap_to_wall

var hit_count := 0
var health: int
var broken := false
var hit_data_image: Image
var hit_data_texture: ImageTexture
var wall_material: ShaderMaterial

@onready var wall_mesh: MeshInstance3D = $MeshInstance3D
@onready var back_wall_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D2")


func _ready() -> void:
	health = max_health
	_update_opaque_collision_layer()
	_update_editor_snap_points_enabled()
	var size_min := minf(bullet_hole_size_range.x, bullet_hole_size_range.y)
	var size_max := maxf(bullet_hole_size_range.x, bullet_hole_size_range.y)
	hit_data_image = Image.create(
		HIT_TEXTURE_SIZE,
		HIT_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBAF)
	hit_data_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	hit_data_texture = ImageTexture.create_from_image(hit_data_image)

	# Every wall needs separate hit data, even when they use the same material resource.
	if wall_mesh.material_override is ShaderMaterial:
		wall_material = wall_mesh.material_override.duplicate()
		wall_mesh.material_override = wall_material
		wall_material.set_shader_parameter("holes", hit_data_texture)
		wall_material.set_shader_parameter("hole_count", 0)
		wall_material.set_shader_parameter("hole_size_random_range", Vector2(size_min, size_max))
		wall_material.set_shader_parameter("broken", 0.0)
		wall_material.set_shader_parameter("break_edge_width", break_edge_width)
		var plane := wall_mesh.mesh as PlaneMesh
		if plane:
			wall_material.set_shader_parameter("wall_chunk_size", plane.size)
		_apply_instance_shader_params()
	else:
		push_warning("Wall MeshInstance3D requires a ShaderMaterial in material_override.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_update_opaque_collision_layer()
		call_deferred("_update_editor_snap_points_enabled")


func set_opaque(value: bool) -> void:
	opaque = value
	_update_opaque_collision_layer()


func hit(hit_position: Vector3, _hit_normal: Vector3, damage: int = 1) -> void:
	if broken or not hit_data_image or not hit_data_texture:
		return

	_spawn_wall_sparks(hit_position, _hit_normal)
	var hit_uv := _get_hit_uv(hit_position)
	if not _has_nearby_hole(hit_uv):
		var data_index := hit_count % MAX_HITS
		var data_pixel := Vector2i(
			data_index % HIT_TEXTURE_SIZE,
			data_index / HIT_TEXTURE_SIZE)
		var size_min := minf(bullet_hole_size_range.x, bullet_hole_size_range.y)
		var size_max := maxf(bullet_hole_size_range.x, bullet_hole_size_range.y)
		var rotation_ratio := randf()
		var size_ratio := 0.0
		if not is_equal_approx(size_min, size_max):
			size_ratio = inverse_lerp(size_min, size_max, randf_range(size_min, size_max))

		# R/G store the wall UV. B stores random rotation. A stores random size.
		hit_data_image.set_pixel(
			data_pixel.x,
			data_pixel.y,
			Color(hit_uv.x, hit_uv.y, rotation_ratio, size_ratio))
		hit_data_texture.update(hit_data_image)

		hit_count += 1
		if wall_material:
			wall_material.set_shader_parameter("hole_count", min(hit_count, MAX_HITS))

	health -= damage
	if health <= 0:
		break_wall()


func break_wall() -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	collision_mask = 0
	if wall_material:
		wall_material.set_shader_parameter("broken", 1.0)
	$Break.play()
	

func try_break_from_sprint_impact() -> bool:
	if broken:
		return false
	if not can_run_through:
		return false

	break_wall()
	return true


func get_bullet_stopping_power() -> float:
	return 0.0 if broken else bullet_stopping_power


func _update_opaque_collision_layer() -> void:
	if opaque:
		collision_layer |= OPAQUE_COLLISION_LAYER
	else:
		collision_layer &= ~OPAQUE_COLLISION_LAYER


func _apply_instance_shader_params() -> void:
	wall_mesh.set_instance_shader_parameter("wall_color", wall_color)
	if back_wall_mesh:
		back_wall_mesh.set_instance_shader_parameter("wall_color", wall_color)


func _spawn_wall_sparks(hit_position: Vector3, hit_normal: Vector3) -> void:
	var sparks := WALL_SPARKS_SCENE.instantiate()
	sparks.global_position = hit_position
	sparks.look_at(hit_position + hit_normal, Vector3.UP, true)
	add_child(sparks)


func _snap_to_wall() -> void:
	if not Engine.is_editor_hint():
		return
	if exclude_from_snap:
		return

	var best_match := _find_best_snap_match()
	if best_match.is_empty():
		return

	var source_snap: Area3D = best_match["source"]
	var target_snap: Area3D = best_match["target"]
	var target_wall := _get_wall_from_snap_point(target_snap)
	if not target_wall or target_wall == self:
		return

	global_position += target_snap.global_position - source_snap.global_position


func _get_hit_uv(hit_position: Vector3) -> Vector2:
	var plane := wall_mesh.mesh as PlaneMesh
	if not plane:
		push_warning("Wall MeshInstance3D requires a PlaneMesh.")
		return Vector2.ZERO

	var local_position := wall_mesh.to_local(hit_position)
	var uv := Vector2(
		local_position.x / plane.size.x + 0.5,
		local_position.z / plane.size.y + 0.5)
	return uv.clamp(Vector2.ZERO, Vector2.ONE)


func _update_editor_snap_points_enabled() -> void:
	var snap_points_enabled := Engine.is_editor_hint() and not exclude_from_snap
	for snap_point in _get_snap_points():
		_configure_snap_point(snap_point, snap_points_enabled)


func _get_snap_points() -> Array[Area3D]:
	var snap_points: Array[Area3D] = []
	var container := get_node_or_null("SnapPoints")
	if not container:
		return snap_points

	for child in container.get_children():
		if child is Area3D:
			snap_points.append(child)

	return snap_points


func _configure_snap_point(snap_point: Area3D, enabled: bool) -> void:
	snap_point.monitoring = enabled
	snap_point.monitorable = enabled
	snap_point.collision_layer = SNAP_COLLISION_LAYER if enabled else 0
	snap_point.collision_mask = SNAP_COLLISION_LAYER if enabled else 0
	snap_point.visible = enabled
	if enabled and not snap_point.is_in_group(SNAP_POINT_GROUP):
		snap_point.add_to_group(SNAP_POINT_GROUP)
	elif not enabled and snap_point.is_in_group(SNAP_POINT_GROUP):
		snap_point.remove_from_group(SNAP_POINT_GROUP)


func _find_best_snap_match() -> Dictionary:
	if exclude_from_snap:
		return {}

	var best_source: Area3D
	var best_target: Area3D
	var best_distance_squared := INF
	var search_distance_squared := snap_point_search_distance * snap_point_search_distance

	for source_snap in _get_snap_points():
		for target_snap in source_snap.get_overlapping_areas():
			if not _is_valid_snap_target(target_snap):
				continue

			var distance_squared := source_snap.global_position.distance_squared_to(
				target_snap.global_position)
			if distance_squared < best_distance_squared:
				best_distance_squared = distance_squared
				best_source = source_snap
				best_target = target_snap

		if best_target:
			continue

		for candidate in get_tree().get_nodes_in_group(SNAP_POINT_GROUP):
			if not (candidate is Area3D):
				continue

			var target_snap: Area3D = candidate
			if not _is_valid_snap_target(target_snap):
				continue

			var distance_squared := source_snap.global_position.distance_squared_to(
				target_snap.global_position)
			if distance_squared > search_distance_squared:
				continue

			if distance_squared < best_distance_squared:
				best_distance_squared = distance_squared
				best_source = source_snap
				best_target = target_snap

	if not best_source or not best_target:
		return {}

	return {
		"source": best_source,
		"target": best_target,
	}


func _is_valid_snap_target(target_snap: Area3D) -> bool:
	var target_wall := _get_wall_from_snap_point(target_snap)
	return target_wall != null and target_wall != self and not target_wall.exclude_from_snap


func _get_wall_from_snap_point(snap_point: Area3D) -> Wall:
	if not snap_point:
		return null

	var current: Node = snap_point
	while current:
		if current is Wall:
			return current
		current = current.get_parent()

	return null


func _get_snap_axis_sign(snap_point: Area3D) -> float:
	if snap_point.has_meta("snap_axis"):
		return signf(float(snap_point.get_meta("snap_axis")))

	return -1.0 if "left" in snap_point.name.to_lower() else 1.0


func _has_nearby_hole(hit_uv: Vector2) -> bool:
	var active_hit_count := mini(hit_count, MAX_HITS)
	if active_hit_count <= 0 or bullet_hole_merge_distance <= 0.0:
		return false

	var merge_distance_squared := bullet_hole_merge_distance * bullet_hole_merge_distance
	for hit_index in active_hit_count:
		var hit_pixel := Vector2i(
			hit_index % HIT_TEXTURE_SIZE,
			hit_index / HIT_TEXTURE_SIZE)
		var stored_hit := hit_data_image.get_pixel(hit_pixel.x, hit_pixel.y)
		var stored_hit_uv := Vector2(stored_hit.r, stored_hit.g)
		if hit_uv.distance_squared_to(stored_hit_uv) <= merge_distance_squared:
			return true

	return false
