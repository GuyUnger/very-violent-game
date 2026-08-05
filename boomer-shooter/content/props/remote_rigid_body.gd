class_name RemoteRigidBody
extends RigidBody3D

## Static body driven by this rigid body's simulation. Defaults to the parent.
@export_node_path("StaticBody3D") var remote_path := NodePath("..")
@export var update_position := true
@export var update_rotation := true
@export_flags("X", "Y", "Z") var remote_rotation_axes := 7
@export var origin := Vector3.ZERO

var remote_body: StaticBody3D
var initial_remote_rotation_: Basis
var initial_rigid_rotation_: Basis


func _init() -> void:
	# The remote static body remains the queryable collision object. This body
	# only needs a mask so it can simulate against the world.
	collision_layer = 0


func _ready() -> void:
	remote_body = get_node_or_null(remote_path) as StaticBody3D
	if not remote_body:
		push_warning("RemoteRigidBody remote_path must point to a StaticBody3D.")
		freeze = true
		set_physics_process(false)
		return

	var origin_transform := Transform3D(Basis.IDENTITY, origin)
	top_level = true
	global_transform = remote_body.global_transform * origin_transform
	initial_remote_rotation_ = remote_body.global_basis.orthonormalized()
	initial_rigid_rotation_ = global_basis.orthonormalized()
	add_collision_exception_with(remote_body)
	if get_child_count() == 0:
		_copy_remote_collision_shapes()
	_sync_remote_transform()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(remote_body):
		set_physics_process(false)
		return
	_sync_remote_transform()


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
	var target_transform := remote_body.global_transform
	var driven_transform := (
		global_transform * Transform3D(Basis.IDENTITY, -origin))
	if update_position:
		target_transform.origin = driven_transform.origin
	if update_rotation:
		var target_scale := target_transform.basis.get_scale()
		target_transform.basis = _get_filtered_remote_rotation(
			driven_transform.basis).scaled(target_scale)
	remote_body.global_transform = target_transform


func _get_filtered_remote_rotation(rigid_rotation: Basis) -> Basis:
	var normalized_rotation := rigid_rotation.orthonormalized()
	if remote_rotation_axes == 7:
		return normalized_rotation
	if remote_rotation_axes == 0:
		return initial_remote_rotation_

	# Filter the rigid body's rotation relative to its authored orientation so
	# the selected axes are local to the prop, not world Euler axes.
	var relative_rotation := (
		initial_rigid_rotation_.inverse() * normalized_rotation)
	var relative_euler := relative_rotation.get_euler()
	if (remote_rotation_axes & 1) == 0:
		relative_euler.x = 0.0
	if (remote_rotation_axes & 2) == 0:
		relative_euler.y = 0.0
	if (remote_rotation_axes & 4) == 0:
		relative_euler.z = 0.0
	return (
		initial_remote_rotation_ * Basis.from_euler(relative_euler)
	).orthonormalized()
