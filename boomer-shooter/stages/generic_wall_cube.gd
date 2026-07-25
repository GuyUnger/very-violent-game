@tool
class_name GenericWallCube
extends Node3D

@export var size := Vector3.ONE:
	set(value):
		size = Vector3(
			maxf(value.x, 0.001),
			maxf(value.y, 0.001),
			maxf(value.z, 0.001))
		_queue_face_update()

@export var wall_material: ShaderMaterial:
	set(value):
		wall_material = value
		_queue_face_update()

@export var cast_shadows := true:
	set(value):
		cast_shadows = value
		_queue_face_update()

var face_update_queued := false


func _ready() -> void:
	_update_faces()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_queue_face_update()


func _queue_face_update() -> void:
	if not is_inside_tree() or face_update_queued:
		return
	face_update_queued = true
	call_deferred("_update_faces")


func _update_faces() -> void:
	face_update_queued = false
	if not is_inside_tree():
		return

	_configure_face(
		"Top",
		Vector2(size.x, size.z),
		Vector3(0.0, size.y * 0.5, 0.0),
		Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK))
	_configure_face(
		"Bottom",
		Vector2(size.x, size.z),
		Vector3(0.0, -size.y * 0.5, 0.0),
		Basis(Vector3.LEFT, Vector3.DOWN, Vector3.BACK))
	_configure_face(
		"Front",
		Vector2(size.x, size.y),
		Vector3(0.0, 0.0, -size.z * 0.5),
		Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP))
	_configure_face(
		"Back",
		Vector2(size.x, size.y),
		Vector3(0.0, 0.0, size.z * 0.5),
		Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP))
	_configure_face(
		"Right",
		Vector2(size.y, size.z),
		Vector3(size.x * 0.5, 0.0, 0.0),
		Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP))
	_configure_face(
		"Left",
		Vector2(size.y, size.z),
		Vector3(-size.x * 0.5, 0.0, 0.0),
		Basis(Vector3.FORWARD, Vector3.LEFT, Vector3.UP))


func _configure_face(
		face_name: String,
		face_size: Vector2,
		face_position: Vector3,
		face_basis: Basis) -> void:
	var face := get_node_or_null(NodePath(face_name)) as MeshInstance3D
	if face == null:
		face = MeshInstance3D.new()
		face.name = face_name
		add_child(face, false, Node.INTERNAL_MODE_BACK)

	var plane := face.mesh as PlaneMesh
	if plane == null:
		plane = PlaneMesh.new()
		face.mesh = plane

	plane.size = face_size
	plane.orientation = PlaneMesh.FACE_Y
	face.transform = Transform3D(face_basis, face_position)
	face.material_override = wall_material
	face.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
