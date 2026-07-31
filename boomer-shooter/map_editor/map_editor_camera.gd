class_name MapEditorCamera
extends Node3D

enum ViewMode {
	ISOMETRIC,
	TOP_DOWN,
}

signal view_mode_changed(mode: int)

@export var view_mode := ViewMode.ISOMETRIC:
	set(value):
		view_mode = value
		if is_node_ready():
			_apply_view_mode()

@export_range(0.01, 4.0, 0.01) var drag_speed := 1.0
@export_range(0.1, 20.0, 0.1) var zoom_step := 2.0
@export_range(1.0, 100.0, 0.5) var minimum_zoom_distance := 6.0
@export_range(1.0, 200.0, 0.5) var maximum_zoom_distance := 60.0
@export_range(1.0, 200.0, 0.5) var zoom_distance := 22.0:
	set(value):
		zoom_distance = value
		if is_node_ready():
			_apply_camera_transform()
@export var isometric_camera_position := Vector3(12.0, 14.0, 12.0)
@export var isometric_camera_rotation_degrees := Vector3(-40.0, 45.0, 0.0)
@export_range(1.0, 120.0, 1.0) var field_of_view := 100.0
@export_range(10.0, 360.0, 5.0) var rotation_speed_degrees := 180.0

@onready var camera: Camera3D = %Camera

var dragging := false
var applied_view_mode := -1
var stored_isometric_basis := Basis.IDENTITY


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = field_of_view
	stored_isometric_basis = global_basis
	_apply_view_mode()


func _process(delta: float) -> void:
	if not camera.current or view_mode != ViewMode.ISOMETRIC:
		return
	var rotation_direction := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		rotation_direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		rotation_direction += 1.0
	if not is_zero_approx(rotation_direction):
		_orbit_around_view_center(
			deg_to_rad(rotation_speed_degrees)
			* rotation_direction
			* delta)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_Q
	):
		toggle_view_mode()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			get_viewport().set_input_as_handled()
			return

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_step * event.factor)
			get_viewport().set_input_as_handled()
			return

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_step * event.factor)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and dragging:
		_move_from_mouse_drag(event.relative)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		dragging = false


func _move_from_mouse_drag(mouse_delta: Vector2) -> void:
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var visible_height := (
		2.0
		* zoom_distance
		* tan(deg_to_rad(camera.fov) * 0.5)
	)
	var world_units_per_pixel := visible_height / viewport_height

	var camera_right := camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	var camera_up := camera.global_basis.y
	camera_up.y = 0.0
	camera_up = camera_up.normalized()

	global_position += (
		-camera_right * mouse_delta.x
		+ camera_up * mouse_delta.y
	) * world_units_per_pixel * drag_speed


func _zoom(amount: float) -> void:
	zoom_distance = clampf(
		zoom_distance + amount,
		minimum_zoom_distance,
		maximum_zoom_distance)


func _orbit_around_view_center(angle: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_direction := camera.project_ray_normal(screen_center)
	if is_zero_approx(ray_direction.y):
		return
	var distance := -ray_origin.y / ray_direction.y
	if distance < 0.0:
		return
	var pivot := ray_origin + ray_direction * distance
	var orbit_rotation := Basis(Vector3.UP, angle)
	var rotated_transform := global_transform
	rotated_transform.origin = (
		pivot
		+ orbit_rotation * (global_position - pivot))
	rotated_transform.basis = orbit_rotation * global_basis
	global_transform = rotated_transform


func toggle_view_mode() -> void:
	if view_mode == ViewMode.ISOMETRIC:
		view_mode = ViewMode.TOP_DOWN
	else:
		view_mode = ViewMode.ISOMETRIC


func _apply_view_mode() -> void:
	if view_mode == ViewMode.TOP_DOWN:
		if applied_view_mode != ViewMode.TOP_DOWN:
			stored_isometric_basis = global_basis
		global_basis = Basis.IDENTITY
	elif applied_view_mode == ViewMode.TOP_DOWN:
		global_basis = stored_isometric_basis
	_apply_camera_transform()
	applied_view_mode = view_mode
	view_mode_changed.emit(view_mode)


func _apply_camera_transform() -> void:
	match view_mode:
		ViewMode.ISOMETRIC:
			camera.position = isometric_camera_position.normalized() * zoom_distance
			camera.rotation_degrees = isometric_camera_rotation_degrees
		ViewMode.TOP_DOWN:
			camera.position = Vector3.UP * zoom_distance
			camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
