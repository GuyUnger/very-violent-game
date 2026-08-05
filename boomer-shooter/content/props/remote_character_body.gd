class_name RemoteCharacterBody
extends CharacterBody3D

## Static body driven by this character body's simple planar physics.
## The remote body defaults to this node's parent.
@export_node_path("StaticBody3D") var remote_path := NodePath("..")
@export var update_position := true
@export var update_rotation := true
@export var origin := Vector3.ZERO

@export_category("Ping Pong Physics")
@export_range(0.0, 100.0, 0.1, "or_greater") var deceleration := 2.0
@export_range(0.0, 1.0, 0.01) var bounce_retention := 1.0
@export_range(0.0, 10.0, 0.01, "or_greater") var stop_speed := 0.05
@export_range(1, 8, 1) var max_bounces_per_step := 4

var remote_body: StaticBody3D
var movement_plane_y_: float


func _init() -> void:
	# The remote static body remains shootable/queryable. This proxy only needs
	# a mask so move_and_collide() can detect the world.
	collision_layer = 0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _ready() -> void:
	remote_body = get_node_or_null(remote_path) as StaticBody3D
	if not remote_body:
		push_warning("RemoteCharacterBody remote_path must point to a StaticBody3D.")
		set_physics_process(false)
		return

	top_level = true
	global_transform = (
		remote_body.global_transform
		* Transform3D(Basis.IDENTITY, origin))
	movement_plane_y_ = global_position.y
	add_collision_exception_with(remote_body)
	if get_child_count() == 0:
		_copy_remote_collision_shapes()
	_sync_remote_transform()


func impulse(p_impulse: Vector3) -> void:
	velocity += Vector3(p_impulse.x, 0.0, p_impulse.z)


func _physics_process(delta: float) -> void:
	velocity.y = 0.0
	if velocity.length_squared() > stop_speed * stop_speed:
		_move_and_bounce(delta)
		_apply_deceleration(delta)
	else:
		velocity = Vector3.ZERO

	var fixed_position := global_position
	fixed_position.y = movement_plane_y_
	global_position = fixed_position
	_sync_remote_transform()


func _move_and_bounce(delta: float) -> void:
	var remaining_motion := velocity * delta
	for _bounce_index in max_bounces_per_step:
		var collision := move_and_collide(remaining_motion)
		if not collision:
			break

		var wall_normal := collision.get_normal()
		wall_normal.y = 0.0
		if wall_normal.length_squared() < 0.001:
			break
		wall_normal = wall_normal.normalized()

		velocity = velocity.bounce(wall_normal) * bounce_retention
		remaining_motion = collision.get_remainder().bounce(wall_normal)
		remaining_motion.y = 0.0
		if remaining_motion.length_squared() < 0.000001:
			break


func _apply_deceleration(delta: float) -> void:
	var speed := velocity.length()
	var next_speed := move_toward(speed, 0.0, deceleration * delta)
	if next_speed <= stop_speed:
		velocity = Vector3.ZERO
	else:
		velocity *= next_speed / speed


func _copy_remote_collision_shapes() -> void:
	for child in remote_body.get_children():
		var source_shape := child as CollisionShape3D
		if not source_shape or not source_shape.shape:
			continue
		var copied_shape := CollisionShape3D.new()
		copied_shape.name = source_shape.name
		copied_shape.transform = (
			Transform3D(Basis.IDENTITY, -origin) * source_shape.transform)
		copied_shape.shape = source_shape.shape
		copied_shape.disabled = source_shape.disabled
		add_child(copied_shape)


func _sync_remote_transform() -> void:
	if not is_instance_valid(remote_body):
		set_physics_process(false)
		return

	var target_transform := remote_body.global_transform
	var driven_transform := (
		global_transform * Transform3D(Basis.IDENTITY, -origin))
	if update_position:
		target_transform.origin = driven_transform.origin
	if update_rotation:
		var target_scale := target_transform.basis.get_scale()
		target_transform.basis = (
			driven_transform.basis.orthonormalized().scaled(target_scale))
	remote_body.global_transform = target_transform
