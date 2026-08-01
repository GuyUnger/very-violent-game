@tool
class_name GenericGeometry
extends StaticBody3D

const OPAQUE_COLLISION_LAYER := 1 << 4
const COLLISION_THICKNESS := 0.025
const HIT_TEXTURE_SIZE := 8
const MAX_HITS := HIT_TEXTURE_SIZE * HIT_TEXTURE_SIZE

@export var size := Vector2(1.5, 2.4):
	set(value):
		size = Vector2(
			maxf(value.x, 0.001),
			maxf(value.y, 0.001))
		_queue_geometry_update()

@export var surface_definition: SurfaceDefinition:
	set(value):
		if (
			surface_definition
			and surface_definition.changed.is_connected(
				_on_surface_definition_changed)
		):
			surface_definition.changed.disconnect(
				_on_surface_definition_changed)
		surface_definition = value
		if (
			surface_definition
			and not surface_definition.changed.is_connected(
				_on_surface_definition_changed)
		):
			surface_definition.changed.connect(
				_on_surface_definition_changed)
		_queue_geometry_update()

@export var is_floor := false:
	set(value):
		is_floor = value
		_queue_geometry_update()

@export var cast_shadows := true:
	set(value):
		cast_shadows = value
		_queue_geometry_update()

var health := 1
var broken := false
var geometry_update_queued := false
var hit_count := 0
var hit_data_image: Image
var hit_data_texture: ImageTexture
var damage_material: ShaderMaterial
var is_wallpaper_layer := false
var respond_to_map_editor_tools := false

@onready var geometry: MeshInstance3D = $Geometry
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var break_sound: AudioStreamPlayer3D = $BreakSound


func _ready() -> void:
	health = surface_definition.max_health if surface_definition else 1
	_update_geometry()
	_connect_to_map_editor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_queue_geometry_update()


func _on_surface_definition_changed() -> void:
	_queue_geometry_update()


func _connect_to_map_editor() -> void:
	if not respond_to_map_editor_tools or not is_instance_valid(MapEditor.instance):
		return
	var map_editor := MapEditor.instance
	if not map_editor.tool_changed.is_connected(_on_map_editor_tool_changed):
		map_editor.tool_changed.connect(_on_map_editor_tool_changed)
	_on_map_editor_tool_changed(map_editor.active_category)


func _on_map_editor_tool_changed(category: int) -> void:
	visible = not (
		is_wallpaper_layer
		and category == MapEditorItem.Category.WALLS)


func hit(
		hit_position: Vector3,
		hit_normal: Vector3,
		damage: int = 1
	) -> void:
	if broken or Engine.is_editor_hint():
		return
	_spawn_impact_effect(hit_position, hit_normal)
	_record_bullet_hole(hit_position)
	health -= damage
	if health <= 0:
		break_geometry()


func break_geometry() -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	collision_mask = 0
	geometry.hide()
	if break_sound.stream:
		break_sound.play()


func try_break_from_sprint_impact() -> bool:
	if broken or not surface_definition or not surface_definition.can_run_through:
		return false
	break_geometry()
	return true


func get_bullet_stopping_power() -> float:
	if broken or not surface_definition:
		return 0.0
	return surface_definition.bullet_stopping_power


func _queue_geometry_update() -> void:
	if not is_inside_tree() or geometry_update_queued:
		return
	geometry_update_queued = true
	call_deferred("_update_geometry")


func _update_geometry() -> void:
	geometry_update_queued = false
	if not is_node_ready():
		return

	var plane := geometry.mesh as PlaneMesh
	if not plane:
		plane = PlaneMesh.new()
		geometry.mesh = plane
	plane.orientation = PlaneMesh.FACE_Y
	geometry.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	var box := collision_shape.shape as BoxShape3D
	if not box:
		box = BoxShape3D.new()
		collision_shape.shape = box
	if is_floor:
		plane.size = size
		geometry.position = Vector3.ZERO
		geometry.rotation_degrees = Vector3.ZERO
		box.size = Vector3(size.x, COLLISION_THICKNESS, size.y)
		collision_shape.position = Vector3.DOWN * COLLISION_THICKNESS * 0.5
	else:
		plane.size = size
		geometry.position = Vector3.UP * size.y * 0.5
		geometry.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		box.size = Vector3(size.x, size.y, COLLISION_THICKNESS)
		collision_shape.position = Vector3.UP * size.y * 0.5

	if surface_definition:
		if damage_material:
			surface_definition.apply_to_material(damage_material)
			geometry.material_override = damage_material
			_apply_damage_material_parameters()
		else:
			geometry.material_override = surface_definition.get_shared_material()
		break_sound.stream = surface_definition.break_sound
		_set_opaque(surface_definition.opaque)
		call_deferred("_apply_instance_parameters")
	else:
		geometry.material_override = null
		break_sound.stream = null
		_set_opaque(true)


func _apply_instance_parameters() -> void:
	if not surface_definition or not is_instance_valid(geometry):
		return
	geometry.set_instance_shader_parameter(
		"modulate",
		Vector3(
			surface_definition.modulate.r,
			surface_definition.modulate.g,
			surface_definition.modulate.b))


func _record_bullet_hole(hit_position: Vector3) -> void:
	if not surface_definition or not surface_definition.hole_atlas:
		return
	if not _ensure_damage_material():
		return

	var hit_uv := _get_hit_uv(hit_position)
	if _has_nearby_hole(hit_uv):
		return

	var data_index := hit_count % MAX_HITS
	var data_pixel := Vector2i(
		data_index % HIT_TEXTURE_SIZE,
		data_index / HIT_TEXTURE_SIZE)
	var size_min := minf(
		surface_definition.hole_size_random_range.x,
		surface_definition.hole_size_random_range.y)
	var size_max := maxf(
		surface_definition.hole_size_random_range.x,
		surface_definition.hole_size_random_range.y)
	var size_ratio := 0.0
	if not is_equal_approx(size_min, size_max):
		size_ratio = inverse_lerp(
			size_min,
			size_max,
			randf_range(size_min, size_max))

	# R/G store UV position, B rotation, and A size.
	hit_data_image.set_pixel(
		data_pixel.x,
		data_pixel.y,
		Color(hit_uv.x, hit_uv.y, randf(), size_ratio))
	hit_data_texture.update(hit_data_image)
	hit_count += 1
	damage_material.set_shader_parameter("hole_count", mini(hit_count, MAX_HITS))


func _ensure_damage_material() -> bool:
	if damage_material:
		return true
	var shared_material := geometry.material_override as ShaderMaterial
	if not shared_material:
		push_warning("GenericGeometry requires a ShaderMaterial to draw bullet holes.")
		return false

	hit_data_image = Image.create(
		HIT_TEXTURE_SIZE,
		HIT_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBAF)
	hit_data_image.fill(Color.TRANSPARENT)
	hit_data_texture = ImageTexture.create_from_image(hit_data_image)
	damage_material = shared_material.duplicate() as ShaderMaterial
	geometry.material_override = damage_material
	_apply_damage_material_parameters()
	return true


func _apply_damage_material_parameters() -> void:
	if not damage_material:
		return
	damage_material.set_shader_parameter("holes", hit_data_texture)
	damage_material.set_shader_parameter("hole_count", mini(hit_count, MAX_HITS))
	damage_material.set_shader_parameter("wall_chunk_size", size)


func _get_hit_uv(hit_position: Vector3) -> Vector2:
	var plane := geometry.mesh as PlaneMesh
	if not plane:
		return Vector2.ZERO
	var local_position := geometry.to_local(hit_position)
	return Vector2(
		local_position.x / plane.size.x + 0.5,
		local_position.z / plane.size.y + 0.5
	).clamp(Vector2.ZERO, Vector2.ONE)


func _has_nearby_hole(hit_uv: Vector2) -> bool:
	var active_hit_count := mini(hit_count, MAX_HITS)
	if (
		active_hit_count <= 0
		or surface_definition.bullet_hole_merge_distance <= 0.0
	):
		return false
	var merge_distance_squared := (
		surface_definition.bullet_hole_merge_distance
		* surface_definition.bullet_hole_merge_distance)
	var minimum_dimension := maxf(minf(size.x, size.y), 0.0001)
	var chunk_aspect := size / minimum_dimension
	for hit_index in active_hit_count:
		var hit_pixel := Vector2i(
			hit_index % HIT_TEXTURE_SIZE,
			hit_index / HIT_TEXTURE_SIZE)
		var stored_hit := hit_data_image.get_pixel(hit_pixel.x, hit_pixel.y)
		var stored_hit_uv := Vector2(stored_hit.r, stored_hit.g)
		var aspect_adjusted_delta := (hit_uv - stored_hit_uv) * chunk_aspect
		if aspect_adjusted_delta.length_squared() <= merge_distance_squared:
			return true
	return false


func _set_opaque(value: bool) -> void:
	if value:
		collision_layer |= OPAQUE_COLLISION_LAYER
	else:
		collision_layer &= ~OPAQUE_COLLISION_LAYER


func _spawn_impact_effect(hit_position: Vector3, hit_normal: Vector3) -> void:
	if not surface_definition or not surface_definition.impact_effect:
		return
	var effect := surface_definition.impact_effect.instantiate() as Node3D
	if not effect:
		return
	effect.position = hit_position
	effect.look_at_from_position(hit_position, hit_position + hit_normal)
	get_viewport().add_child(effect)
