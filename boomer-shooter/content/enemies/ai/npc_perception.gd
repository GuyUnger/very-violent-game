class_name NPCPerception
extends Node

const VISION_OPAQUE_COLLISION_LAYER := 1 << 4

signal spotted_enemy(enemy: Character)

var npc
var vision: Area3D
var polling := false
var debug_mesh_instance: MeshInstance3D
var debug_mesh: ImmediateMesh
var debug_material := StandardMaterial3D.new()


func setup(p_npc) -> void:
	npc = p_npc
	vision = npc.get_node_or_null("%Vision") as Area3D
	if vision:
		vision.body_entered.connect(_on_body_entered)
	_setup_debug_line()


func is_node_visible(node: Node3D) -> bool:
	if not is_instance_valid(node) or not is_instance_valid(vision):
		return false

	var target_position := node.global_position + Vector3.UP
	if node is Character:
		target_position = node.global_position + Vector3.UP * 0.9

	var query := PhysicsRayQueryParameters3D.new()
	query.from = vision.global_position
	query.to = target_position
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = VISION_OPAQUE_COLLISION_LAYER + 2 + 8

	var result: Dictionary = npc.get_world_3d().direct_space_state.intersect_ray(query)
	var visible: bool = not result.is_empty() and result.collider == node
	_update_debug_line(
		query.from,
		result.position if not result.is_empty() else target_position,
		visible)
	return visible


func poll() -> void:
	if polling or not is_instance_valid(vision):
		return

	polling = true
	while is_inside_tree() and is_instance_valid(npc):
		var has_character := false
		for node in vision.get_overlapping_bodies():
			if node is not Character:
				continue
			has_character = true

			await get_tree().process_frame
			if not is_inside_tree() or not is_instance_valid(npc):
				polling = false
				return

			if is_node_visible(node):
				spotted_enemy.emit(node)
				polling = false
				return

		if not has_character:
			break

	polling = false


func _on_body_entered(body: Node3D) -> void:
	if body is not Character:
		return
	if is_node_visible(body):
		spotted_enemy.emit(body)
	else:
		poll()


func _setup_debug_line() -> void:
	if not npc.draw_debug_vision_ray:
		return

	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh_instance.name = "DebugVisionRay"
	debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug_mesh_instance.top_level = true
	debug_mesh = ImmediateMesh.new()
	debug_mesh_instance.mesh = debug_mesh

	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.vertex_color_use_as_albedo = true
	debug_material.no_depth_test = true
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_mesh_instance.material_override = debug_material
	npc.add_child(debug_mesh_instance)


func _update_debug_line(from: Vector3, to: Vector3, visible: bool) -> void:
	if not npc.draw_debug_vision_ray or not is_instance_valid(debug_mesh):
		return

	debug_mesh.clear_surfaces()
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES, debug_material)
	debug_mesh.surface_set_color(
		Color(0.1, 1.0, 0.1, 0.9)
		if visible
		else Color(1.0, 0.15, 0.15, 0.9))
	debug_mesh.surface_add_vertex(from)
	debug_mesh.surface_add_vertex(to)
	debug_mesh.surface_end()
