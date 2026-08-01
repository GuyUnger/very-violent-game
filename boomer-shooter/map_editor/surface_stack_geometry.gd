@tool
class_name SurfaceStackGeometry
extends Node3D

const GENERIC_GEOMETRY_SCENE := preload(
	"res://map_editor/generic_geometry.tscn")

@export var size := Vector2(1.5, 2.4):
	set(value):
		size = Vector2(maxf(value.x, 0.001), maxf(value.y, 0.001))
		_queue_rebuild()

@export var is_floor := false:
	set(value): is_floor = value; _queue_rebuild()

@export var show_editor_line := false:
	set(value): show_editor_line = value; _queue_rebuild()

@export var surface_stack: SurfaceStackDefinition:
	set(value):
		if surface_stack and surface_stack.changed.is_connected(_on_stack_changed):
			surface_stack.changed.disconnect(_on_stack_changed)
		surface_stack = value
		if surface_stack and not surface_stack.changed.is_connected(_on_stack_changed):
			surface_stack.changed.connect(_on_stack_changed)
		_queue_rebuild()

var rebuild_queued := false

@onready var editor_line: MeshInstance3D = $EditorLine


func _ready() -> void:
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_queue_rebuild()


func _on_stack_changed() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or rebuild_queued:
		return
	rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	rebuild_queued = false
	for child in get_children(true):
		if child == editor_line:
			continue
		remove_child(child)
		child.queue_free()
	_update_editor_line()

	if not surface_stack:
		return

	if not is_floor and surface_stack.layers.size() == 3:
		_rebuild_three_part_wall()
		return

	var layer_offset := 0.0
	for layer_index in surface_stack.layers.size():
		var layer := surface_stack.layers[layer_index]
		if not layer:
			continue
		if layer_index > 0:
			layer_offset += layer.spacing_from_previous
		if not layer.surface:
			continue

		_add_layer_geometry(
			layer,
			layer_index,
			Vector3.DOWN * layer_offset
			if is_floor
			else Vector3.FORWARD * layer_offset)


func _rebuild_three_part_wall() -> void:
	# Slot 1 is structural. Slots 0 and 2 are finishes on opposite faces.
	for layer_index in surface_stack.layers.size():
		var layer := surface_stack.layers[layer_index]
		if not layer or not layer.surface:
			continue
		var layer_position := Vector3.ZERO
		var layer_rotation := 0.0
		if layer_index == 0:
			layer_position = Vector3.FORWARD * layer.spacing_from_previous
			layer_rotation = PI
		elif layer_index == 2:
			layer_position = Vector3.BACK * layer.spacing_from_previous
		_add_layer_geometry(
			layer, layer_index, layer_position, layer_rotation)


func _add_layer_geometry(
		layer: SurfaceLayerDefinition,
		layer_index: int,
		layer_position: Vector3,
		layer_rotation := 0.0
	) -> void:
	var geometry := GENERIC_GEOMETRY_SCENE.instantiate() as GenericGeometry
	geometry.name = "Layer%d_%s" % [layer_index, layer.surface.display_name]
	geometry.size = size
	geometry.is_floor = is_floor
	geometry.is_wallpaper_layer = (
		not is_floor
		and surface_stack.layers.size() == 3
		and layer_index != 1)
	geometry.respond_to_map_editor_tools = show_editor_line
	geometry.surface_definition = layer.surface
	geometry.position = layer_position
	geometry.rotation.y = layer_rotation
	add_child(geometry, false, Node.INTERNAL_MODE_BACK)


func _update_editor_line() -> void:
	if not is_instance_valid(editor_line):
		return
	editor_line.visible = show_editor_line and not is_floor
	if not editor_line.visible:
		return

	var plane := editor_line.mesh as PlaneMesh
	if not plane:
		plane = PlaneMesh.new()
	elif not editor_line.has_meta(&"editor_line_mesh_local"):
		plane = plane.duplicate() as PlaneMesh
		editor_line.mesh = plane
		editor_line.set_meta(&"editor_line_mesh_local", true)
	plane.orientation = PlaneMesh.FACE_Y
	plane.flip_faces = false
	plane.size = Vector2(size.x, 0.1)
	editor_line.position = Vector3.UP * (size.y + 0.005)
	editor_line.rotation = Vector3.ZERO
	editor_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
