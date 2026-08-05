extends StaticBody3D
class_name Prop

signal died
signal hitt

const NONBLOCKING_PROP_LAYER := 1 << 7
const PLAYER_LAYER := 1 << 1
const FALL_OVER_LAYER := 1 << 3

@export var max_hp := 5
@export var can_run_through := false
@export var fall_over_on_collision := false
@export var climbable := false
@export var remote_character_body_on_hit := false
@export_range(0.0, 100.0, 0.1, "or_greater") var hit_impulse_strength := 2.0

@onready var hp = max_hp
@onready var model: Node3D = $Model
@onready var nested: Node3D = $Model/Nested

var is_nested_ := false
var tween_: Tween
var remote_rigid_body_: RemoteRigidBody
var remote_character_body_: RemoteCharacterBody
var fall_tween_: Tween
var falling_over_ := false
var fallen_over_ := false

func _ready() -> void:
	if fall_over_on_collision:
		_setup_fall_over_trigger()
		
	for child in nested.get_children():
		if child is Prop:
			child.hitt.connect(hit)
			child.is_nested_ = true

func _setup_fall_over_trigger() -> void:
	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision_shape or not collision_shape.shape:
		return

	# Keep the static shape available to bullets, but off the world layer that
	# the player's CharacterBody3D scans during move_and_slide().
	collision_layer &= ~1
	collision_layer |= NONBLOCKING_PROP_LAYER
	collision_mask |= NONBLOCKING_PROP_LAYER

	var trigger := Area3D.new()
	trigger.name = "FallOverTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = FALL_OVER_LAYER
	trigger.monitorable = false
	add_child(trigger)

	var trigger_shape := CollisionShape3D.new()
	trigger_shape.shape = collision_shape.shape
	trigger_shape.transform = collision_shape.transform
	trigger_shape.disabled = collision_shape.disabled
	trigger.add_child(trigger_shape)
	trigger.area_entered.connect(_on_fall_over_trigger_area_entered)


func _on_fall_over_trigger_area_entered(body: Node3D) -> void:
	var player_body := body.get_parent() as CharacterBody3D
	if not player_body:
		return
	var collision_normal := player_body.global_position - global_position
	collision_normal.y = 0.0
	try_fall_over_from_player(
		collision_normal.normalized(), player_body.velocity, player_body)


func hit(pos:Vector3, normal:Vector3, damage, is_nested := false) -> void:
	hitt.emit(pos, normal, damage, is_nested_)
	
	if hp <= 0:
		return
	
	if remote_character_body_on_hit:
		_apply_remote_character_body_impulse(pos, normal)
		
		
	if tween_ and tween_.is_valid():
		tween_.kill()

	model.position *= 0.0
	var start_position := model.position
	tween_ = create_tween()
	tween_.tween_property(model, "position", model.position + Vector3.UP * 0.1, 0.03)
	tween_.tween_property(model, "position", start_position, 0.12)

	if not is_nested:
		$HitSound.play()
		_spawn_wall_sparks(pos, normal)

	hp = max(0, hp - damage)
	
	if hp <= 0:
		explode()


func _apply_remote_character_body_impulse(
		hit_position: Vector3,
		hit_normal: Vector3,
	) -> void:
	if hit_normal == Vector3.UP:
		return
		
	if not is_instance_valid(remote_character_body_):
		remote_character_body_ = (
			get_node_or_null("RemoteCharacterBody") as RemoteCharacterBody)
	if not remote_character_body_:
		remote_character_body_ = RemoteCharacterBody.new()
		remote_character_body_.name = "RemoteCharacterBody"
		add_child(remote_character_body_)

	var impulse_direction := -hit_normal
	impulse_direction.y = 0.0
	if impulse_direction.length_squared() < 0.001:
		impulse_direction = global_position - hit_position
		impulse_direction.y = 0.0
	if impulse_direction.length_squared() < 0.001:
		return
	remote_character_body_.impulse(
		impulse_direction.normalized() * hit_impulse_strength)
		

func try_break_from_sprint_impact() -> bool:
	if hp <= 0:
		return false
	if not can_run_through:
		return false

	hp = 0
	explode()
	return true


func try_fall_over_from_player(
		collision_normal: Vector3,
		player_velocity: Vector3,
		player_body: PhysicsBody3D
	) -> bool:
	if (
		not fall_over_on_collision
		or falling_over_
		or fallen_over_
		or hp <= 0
	):
		return false

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision_shape or not collision_shape.shape or collision_shape.disabled:
		return false

	var desired_direction := -collision_normal
	desired_direction.y = 0.0
	if desired_direction.length_squared() < 0.001:
		desired_direction = player_velocity
		desired_direction.y = 0.0
	if desired_direction.length_squared() < 0.001:
		return false
	desired_direction = desired_direction.normalized()

	var pivot := global_transform * _get_collision_shape_bottom_center(collision_shape)
	var initial_transform := global_transform
	var directions := [
		Vector3.FORWARD,
		Vector3.RIGHT,
		Vector3.BACK,
		Vector3.LEFT,
	]

	while not directions.is_empty():
		var best_index := 0
		var best_alignment := -INF
		for direction_index in directions.size():
			var alignment: float = directions[direction_index].dot(
				desired_direction)
			if alignment > best_alignment:
				best_alignment = alignment
				best_index = direction_index
		var fall_direction: Vector3 = directions.pop_at(best_index)
		var fall_axis := Vector3.UP.cross(fall_direction).normalized()
		if not _has_fall_clearance(
			fall_direction, collision_shape, player_body):
			continue
		var fall_lift := _get_collision_shape_fall_lift(
			collision_shape, fall_direction)
		_start_fall_tween(initial_transform, pivot, fall_axis, fall_lift)
		return true

	return false


func _get_collision_shape_bottom_center(
	collision_shape: CollisionShape3D,
) -> Vector3:
	var shape := collision_shape.shape
	var bottom_center := Vector3.ZERO
	if shape is BoxShape3D:
		bottom_center.y = -(shape as BoxShape3D).size.y * 0.5
	elif shape is CapsuleShape3D:
		bottom_center.y = -(shape as CapsuleShape3D).height * 0.5
	elif shape is CylinderShape3D:
		bottom_center.y = -(shape as CylinderShape3D).height * 0.5
	elif shape is SphereShape3D:
		bottom_center.y = -(shape as SphereShape3D).radius
	return collision_shape.transform * bottom_center


func _get_fall_transform(
		initial_transform: Transform3D,
		pivot: Vector3,
		fall_axis: Vector3,
		angle: float,
	) -> Transform3D:
	return (
		Transform3D(Basis.IDENTITY, pivot)
		* Transform3D(Basis(fall_axis, angle), Vector3.ZERO)
		* Transform3D(Basis.IDENTITY, -pivot)
		* initial_transform)


func _has_fall_clearance(
		fall_direction: Vector3,
		collision_shape: CollisionShape3D,
		player_body: PhysicsBody3D,
	) -> bool:
	var excluded_rids: Array[RID] = [get_rid()]
	if is_instance_valid(player_body):
		excluded_rids.append(player_body.get_rid())

	var ray_origin := collision_shape.global_position
	var ray_query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + fall_direction * 100.0,
		collision_mask,
		excluded_rids)
	ray_query.collide_with_areas = false
	ray_query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray_query)
	return hit.is_empty() or ray_origin.distance_to(hit.position) > 1.0


func _get_collision_shape_fall_lift(
		collision_shape: CollisionShape3D,
		fall_direction: Vector3,
	) -> float:
	var shape := collision_shape.shape
	if shape is BoxShape3D:
		var half_size := (shape as BoxShape3D).size * 0.5
		var shape_basis := collision_shape.global_basis
		return (
			absf(fall_direction.dot(shape_basis.x)) * half_size.x
			+ absf(fall_direction.dot(shape_basis.y)) * half_size.y
			+ absf(fall_direction.dot(shape_basis.z)) * half_size.z)
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	return 0.0


func _start_fall_tween(
		initial_transform: Transform3D,
		pivot: Vector3,
		fall_axis: Vector3,
		fall_lift: float,
	) -> void:
	falling_over_ = true
	fall_tween_ = create_tween()
	var apply_fall_angle := func(angle: float) -> void:
		var fall_transform := _get_fall_transform(
			initial_transform, pivot, fall_axis, angle)
		fall_transform.origin.y += sin(angle) * fall_lift
		global_transform = fall_transform
	fall_tween_.tween_method(
		apply_fall_angle,
		0.0,
		PI * 0.5,
		0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween_.tween_method(
		apply_fall_angle,
		PI * 0.5,
		deg_to_rad(82.0),
		0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall_tween_.tween_method(
		apply_fall_angle,
		deg_to_rad(82.0),
		PI * 0.5,
		0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween_.finished.connect(
		func() -> void:
			falling_over_ = false
			fallen_over_ = true)


func explode() -> void:
	died.emit()

	var p := preload("res://content/fx/vfx_burst_wood_planks.tscn").instantiate()
	p.position = global_position
	get_parent().add_child(p)
	
	for child in model.get_children():
		if child == nested:
			continue
		child.visible = false

	collision_layer = 0
	collision_mask = 0


func _spawn_wall_sparks(hit_position: Vector3, hit_normal: Vector3) -> void:
	var hole_decal: Node3D = preload("res://map_editor/surfaces/materials/bullet_hit_fabric.tscn").instantiate()
	hole_decal.look_at_from_position(
		to_local(hit_position),
		to_local(hit_position + hit_normal),
		Vector3.UP,
		true)
	model.add_child(hole_decal)

	var sparks: Node3D = preload("res://content/fx/wall_sparks.tscn").instantiate()
	sparks.look_at_from_position(
		to_local(hit_position),
		to_local(hit_position + hit_normal),
		Vector3.UP,
		true)
	add_child(sparks)
