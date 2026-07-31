class_name MapEditor
extends Node3D

const MAP_FORMAT_VERSION := 3
const GAMEPLAY_SCENE := preload("res://stages/main.tscn")
const SURFACE_STACK_SCENE := preload(
	"res://map_editor/surface_stack_geometry.tscn")
const WALLPAPER_SLOT_0_KEY := "wallpaper_slot_0_item_id"
const WALLPAPER_SLOT_2_KEY := "wallpaper_slot_2_item_id"

@export var catalog: MapEditorCatalog
@export_range(0.1, 10.0, 0.1) var grid_size := 1.5
@export_range(0.1, 10.0, 0.1) var wall_height := 2.4
@export_file("*.map") var map_file_path := "user://map.map"

@onready var camera: Camera3D = %Camera
@onready var camera_rig: MapEditorCamera = $CameraRig
@onready var grid: MeshInstance3D = $Grid
@onready var mouse_ground_marker: MeshInstance3D = %MouseGroundMarker
@onready var walls: Node3D = %Walls
@onready var floors: Node3D = %Floors
@onready var npcs: Node3D = %Npcs
@onready var props: Node3D = %Props
@onready var items: Node3D = %Items
@onready var meta: Node3D = %Meta
@onready var wall_preview: Node3D = %WallPreview
@onready var floor_preview: Node3D = %FloorPreview
@onready var top_down_view_button: Button = %TopDownViewButton
@onready var isometric_view_button: Button = %IsometricViewButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var play_button: Button = %PlayButton
@onready var editor_ui: CanvasLayer = $CanvasLayer
@onready var walls_category_button: Button = %WallsCategoryButton
@onready var wallpaper_category_button: Button = %WallPaperCategoryButton
@onready var floors_category_button: Button = %FloorsCategoryButton
@onready var npcs_category_button: Button = %NpcsCategoryButton
@onready var items_category_button: Button = %ItemsCategoryButton
@onready var props_category_button: Button = %PropsCategoryButton
@onready var meta_category_button: Button = %MetaCategoryButton
@onready var palette_items: HFlowContainer = %PaletteItems
@onready var stack_thumbnail_renderer: MapEditorStackThumbnailRenderer = (
	%StackThumbnailRenderer)

var drawing_wall := false
var drawing_floor := false
var painting_wallpaper := false
var erasing_wallpaper := false
var rotating_placed_entity := false
var rotating_entity_key := ""
var deleting_walls := false
var wall_start := Vector2i.ZERO
var wall_end := Vector2i.ZERO
var wallpaper_start := Vector2i.ZERO
var wallpaper_end := Vector2i.ZERO
var floor_start := Vector2i.ZERO
var floor_end := Vector2i.ZERO
var occupied_wall_edges: Dictionary = {}
var wall_edge_data: Dictionary = {}
var occupied_floor_cells: Dictionary = {}
var floor_data: Dictionary = {}
var floor_nodes: Dictionary = {}
var placed_item_data: Dictionary = {}
var placed_item_nodes: Dictionary = {}
var preview_material: StandardMaterial3D
var occupied_preview_material: StandardMaterial3D
var delete_stroke_records: Array = []
var floor_delete_stroke_records: Array = []
var undo_redo := UndoRedo.new()
var gameplay_instance: Node3D
var detached_editor_world_nodes: Array[Node3D] = []
var active_category := MapEditorItem.Category.WALLS
var active_item: MapEditorItem
var palette_button_group := ButtonGroup.new()
var stack_thumbnail_cache: Dictionary = {}
var palette_generation := 0


func _ready() -> void:
	if catalog:
		catalog.rebuild()
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.albedo_color = Color(0.35, 0.75, 1.0, 0.55)
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	occupied_preview_material = preview_material.duplicate() as StandardMaterial3D
	occupied_preview_material.albedo_color = Color(1.0, 0.65, 0.15, 0.65)

	top_down_view_button.pressed.connect(_show_top_down_view)
	isometric_view_button.pressed.connect(_show_isometric_view)
	save_button.pressed.connect(save_map)
	load_button.pressed.connect(load_map)
	play_button.pressed.connect(play_map)
	walls_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.WALLS))
	wallpaper_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.WALLPAPERS))
	floors_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.FLOORS))
	npcs_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.NPCS))
	items_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.ITEMS))
	props_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.PROPS))
	meta_category_button.pressed.connect(
		_select_category.bind(MapEditorItem.Category.META))
	camera_rig.view_mode_changed.connect(_update_view_buttons)
	_update_view_buttons(camera_rig.view_mode)
	_select_category(MapEditorItem.Category.WALLS)


func _process(_delta: float) -> void:
	if gameplay_instance or not camera.current:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if active_category in [
		MapEditorItem.Category.PROPS,
		MapEditorItem.Category.NPCS,
		MapEditorItem.Category.ITEMS,
		MapEditorItem.Category.META,
	]:
		var cell := _screen_to_floor_cell(mouse_position)
		mouse_ground_marker.position = Vector3(
			(cell.x + 0.5) * grid_size,
			0.075,
			(cell.y + 0.5) * grid_size)
	else:
		var grid_point := _screen_to_grid_point(mouse_position)
		mouse_ground_marker.position = Vector3(
			grid_point.x * grid_size,
			0.075,
			grid_point.y * grid_size)


func _input(event: InputEvent) -> void:
	if gameplay_instance and event.is_action_pressed("exit"):
		exit_playtest()
		get_viewport().set_input_as_handled()


func _show_top_down_view() -> void:
	camera_rig.view_mode = MapEditorCamera.ViewMode.TOP_DOWN


func _show_isometric_view() -> void:
	camera_rig.view_mode = MapEditorCamera.ViewMode.ISOMETRIC


func _update_view_buttons(mode: int) -> void:
	top_down_view_button.button_pressed = mode == MapEditorCamera.ViewMode.TOP_DOWN
	isometric_view_button.button_pressed = mode == MapEditorCamera.ViewMode.ISOMETRIC


func _select_category(category: int) -> void:
	_finish_entity_rotation()
	_cancel_wall()
	_cancel_floor()
	_finish_wallpaper_stroke()
	_finish_delete_stroke()
	active_category = category
	active_item = null
	walls_category_button.button_pressed = category == MapEditorItem.Category.WALLS
	wallpaper_category_button.button_pressed = (
		category == MapEditorItem.Category.WALLPAPERS)
	floors_category_button.button_pressed = category == MapEditorItem.Category.FLOORS
	npcs_category_button.button_pressed = category == MapEditorItem.Category.NPCS
	items_category_button.button_pressed = category == MapEditorItem.Category.ITEMS
	props_category_button.button_pressed = category == MapEditorItem.Category.PROPS
	meta_category_button.button_pressed = category == MapEditorItem.Category.META
	_rebuild_palette()


func _rebuild_palette() -> void:
	palette_generation += 1
	var current_generation := palette_generation
	for child in palette_items.get_children():
		palette_items.remove_child(child)
		child.queue_free()

	if not catalog:
		push_warning("MapEditor needs a catalogue Resource.")
		return

	var category_items := catalog.get_items_in_category(active_category)
	if category_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items registered in this category"
		empty_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
		palette_items.add_child(empty_label)
		return

	var thumbnail_requests: Array = []
	for item in category_items:
		var button := Button.new()
		button.custom_minimum_size = Vector2(128.0, 56.0)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = palette_button_group
		button.text = item.display_name
		button.tooltip_text = String(item.id)
		button.expand_icon = true
		#button.icon_max_width = 48
		if item.surface:
			var cache_key := item.surface.get_instance_id()
			if stack_thumbnail_cache.has(cache_key):
				button.icon = stack_thumbnail_cache[cache_key]
			else:
				thumbnail_requests.append({
					"button": button,
					"surface": item.surface,
					"cache_key": cache_key,
				})
		elif item.thumbnail:
			button.icon = item.thumbnail
		button.pressed.connect(_select_palette_item.bind(item))
		palette_items.add_child(button)

		if not active_item:
			active_item = item
			button.button_pressed = true

	if not thumbnail_requests.is_empty():
		_render_stack_thumbnails(thumbnail_requests, current_generation)


func _render_stack_thumbnails(requests: Array, generation: int) -> void:
	for request in requests:
		var thumbnail: Texture2D = await (
			stack_thumbnail_renderer.render_surface(request["surface"]))
		if generation != palette_generation:
			return
		if not thumbnail:
			continue
		stack_thumbnail_cache[request["cache_key"]] = thumbnail
		var button: Button = request["button"]
		if is_instance_valid(button):
			button.icon = thumbnail


func _select_palette_item(item: MapEditorItem) -> void:
	_finish_wallpaper_stroke()
	active_item = item


func save_map(path := map_file_path) -> Error:
	_finish_entity_rotation()
	_finish_wallpaper_stroke()
	_finish_delete_stroke()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var error := FileAccess.get_open_error()
		push_error("Could not save map to %s (error %s)." % [path, error])
		return error

	var saved_walls: Array = []
	for record_value in wall_edge_data.values():
		var record: Dictionary = record_value
		var saved_wall := {
			"point_a": record["point_a"],
			"point_b": record["point_b"],
			"item_id": record["item_id"],
		}
		if record.has(WALLPAPER_SLOT_0_KEY):
			saved_wall[WALLPAPER_SLOT_0_KEY] = record[WALLPAPER_SLOT_0_KEY]
		if record.has(WALLPAPER_SLOT_2_KEY):
			saved_wall[WALLPAPER_SLOT_2_KEY] = record[WALLPAPER_SLOT_2_KEY]
		saved_walls.append(saved_wall)
	var saved_floors: Array = []
	for record_value in floor_data.values():
		var record: Dictionary = record_value
		saved_floors.append({
			"cell_min": record["cell_min"],
			"cell_max": record["cell_max"],
			"item_id": record["item_id"],
		})
	var saved_items: Array = []
	for record_value in placed_item_data.values():
		var record: Dictionary = record_value
		saved_items.append({
			"cell": record["cell"],
			"item_id": record["item_id"],
			"rotation_y": record.get("rotation_y", 0.0),
		})

	var map_data := {
		"version": MAP_FORMAT_VERSION,
		"grid_size": grid_size,
		"walls": saved_walls,
		"floors": saved_floors,
		"placed_items": saved_items,
	}
	file.store_string(var_to_str(map_data))
	print("Saved map to ", path)
	return OK


func load_map(path := map_file_path) -> Error:
	var result := _read_map_file(path)
	var error: Error = result["error"]
	if error != OK:
		return error

	_cancel_wall()
	_cancel_floor()
	_finish_delete_stroke()
	_clear_all_structures()
	grid_size = result["grid_size"]
	_update_grid_shader()
	_create_wall_records(result["wall_records"])
	_create_floor_records(result["floor_records"])
	_create_placed_item_records(result["placed_item_records"])
	undo_redo.clear_history()
	print("Loaded map from ", path)
	return OK


func play_map() -> void:
	if gameplay_instance:
		return
	if save_map() != OK:
		return

	var result := _read_map_file(map_file_path)
	var error: Error = result["error"]
	if error != OK:
		return

	var main := GAMEPLAY_SCENE.instantiate() as Node3D
	if not main:
		push_error("stages/main.tscn must have a Node3D root.")
		return

	var gameplay_viewport := main.get_node_or_null(
		"SubViewportContainer/SubViewport") as SubViewport
	if not gameplay_viewport:
		push_error("stages/main.tscn is missing its gameplay SubViewport.")
		main.free()
		return

	for record in result["wall_records"]:
		_instantiate_wall(record, gameplay_viewport, result["grid_size"], false)
	for record in result["floor_records"]:
		_instantiate_floor(record, gameplay_viewport, result["grid_size"])
	for record in result["placed_item_records"]:
		_instantiate_placed_item(
			record, gameplay_viewport, result["grid_size"], false)

	gameplay_instance = main
	_detach_editor_world()
	_set_editor_enabled(false)
	add_child(gameplay_instance)


func exit_playtest() -> void:
	if not gameplay_instance:
		return
	var instance_to_free := gameplay_instance
	gameplay_instance = null
	instance_to_free.queue_free()
	get_tree().paused = false
	Transition.stop_music()
	_reattach_editor_world()
	_set_editor_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _detach_editor_world() -> void:
	detached_editor_world_nodes.clear()
	var editor_world_nodes: Array[Node3D] = [
		walls, floors, npcs, props, items, meta]
	for editor_world_node in editor_world_nodes:
		if editor_world_node.get_parent() != self:
			continue
		remove_child(editor_world_node)
		detached_editor_world_nodes.append(editor_world_node)


func _reattach_editor_world() -> void:
	for editor_world_node in detached_editor_world_nodes:
		if not is_instance_valid(editor_world_node):
			continue
		add_child(editor_world_node)
	detached_editor_world_nodes.clear()


func _set_editor_enabled(enabled: bool) -> void:
	grid.visible = enabled
	mouse_ground_marker.visible = enabled
	walls.visible = enabled
	floors.visible = enabled
	npcs.visible = enabled
	props.visible = enabled
	items.visible = enabled
	meta.visible = enabled
	wall_preview.visible = enabled
	floor_preview.visible = enabled
	editor_ui.visible = enabled
	camera.current = enabled
	set_process_unhandled_input(enabled)
	camera_rig.set_process(enabled)
	camera_rig.set_process_unhandled_input(enabled)


func _read_map_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Map file does not exist: %s" % path)
		return {"error": ERR_FILE_NOT_FOUND}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		var error := FileAccess.get_open_error()
		push_error("Could not load map from %s (error %s)." % [path, error])
		return {"error": error}

	var map_data: Variant = str_to_var(file.get_as_text())
	if not map_data is Dictionary:
		push_error("Map file does not contain a Dictionary: %s" % path)
		return {"error": ERR_PARSE_ERROR}
	if int(map_data.get("version", -1)) != MAP_FORMAT_VERSION:
		push_error("Unsupported map version in: %s" % path)
		return {"error": ERR_FILE_UNRECOGNIZED}

	var saved_walls: Variant = map_data.get("walls", [])
	if not saved_walls is Array:
		push_error("Map walls must be stored as an Array: %s" % path)
		return {"error": ERR_PARSE_ERROR}

	var wall_records: Array = []
	var loaded_edge_keys: Dictionary = {}
	for saved_wall_value in saved_walls:
		if not saved_wall_value is Dictionary:
			push_error("Invalid wall entry in map: %s" % path)
			return {"error": ERR_PARSE_ERROR}

		var saved_wall: Dictionary = saved_wall_value
		var point_a: Variant = saved_wall.get("point_a")
		var point_b: Variant = saved_wall.get("point_b")
		var item_id := StringName(saved_wall.get("item_id", &""))
		if not point_a is Vector2i or not point_b is Vector2i:
			push_error("Wall points must be Vector2i values: %s" % path)
			return {"error": ERR_PARSE_ERROR}
		if absi(point_b.x - point_a.x) + absi(point_b.y - point_a.y) != 1:
			push_error("Saved wall must occupy exactly one grid edge: %s" % path)
			return {"error": ERR_PARSE_ERROR}
		var item := catalog.get_item(item_id) if catalog else null
		if (
			not item
			or item.category != MapEditorItem.Category.WALLS
			or not item.surface
		):
			push_error("Saved wall item is not in the catalogue: %s" % item_id)
			return {"error": ERR_FILE_NOT_FOUND}

		var edge_key := _get_edge_key(point_a, point_b)
		if loaded_edge_keys.has(edge_key):
			continue
		loaded_edge_keys[edge_key] = true
		var wall_record := {
			"key": edge_key,
			"point_a": point_a,
			"point_b": point_b,
			"item_id": item.id,
			"surface": item.surface,
		}
		for wallpaper_key in [WALLPAPER_SLOT_0_KEY, WALLPAPER_SLOT_2_KEY]:
			if not saved_wall.has(wallpaper_key):
				continue
			var wallpaper_id := StringName(saved_wall[wallpaper_key])
			var wallpaper_item := catalog.get_item(wallpaper_id) if catalog else null
			if (
				not wallpaper_item
				or wallpaper_item.category != MapEditorItem.Category.WALLPAPERS
				or not wallpaper_item.surface
			):
				push_error("Saved wallpaper item is not in the catalogue: %s" % wallpaper_id)
				return {"error": ERR_FILE_NOT_FOUND}
			wall_record[wallpaper_key] = wallpaper_id
		wall_records.append(wall_record)

	var saved_floors: Variant = map_data.get("floors", [])
	if not saved_floors is Array:
		push_error("Map floors must be stored as an Array: %s" % path)
		return {"error": ERR_PARSE_ERROR}

	var floor_records: Array = []
	var loaded_floor_keys: Dictionary = {}
	for saved_floor_value in saved_floors:
		if not saved_floor_value is Dictionary:
			push_error("Invalid floor entry in map: %s" % path)
			return {"error": ERR_PARSE_ERROR}
		var saved_floor: Dictionary = saved_floor_value
		var cell_min: Variant = saved_floor.get("cell_min")
		var cell_max: Variant = saved_floor.get("cell_max")
		var floor_item_id := StringName(saved_floor.get("item_id", &""))
		if not cell_min is Vector2i or not cell_max is Vector2i:
			push_error("Floor bounds must be Vector2i values: %s" % path)
			return {"error": ERR_PARSE_ERROR}
		var floor_item := catalog.get_item(floor_item_id) if catalog else null
		if (
			not floor_item
			or floor_item.category != MapEditorItem.Category.FLOORS
			or not floor_item.surface
		):
			push_error("Saved floor item is not in the catalogue: %s" % floor_item_id)
			return {"error": ERR_FILE_NOT_FOUND}
		var bounds_min := Vector2i(
			mini(cell_min.x, cell_max.x), mini(cell_min.y, cell_max.y))
		var bounds_max := Vector2i(
			maxi(cell_min.x, cell_max.x), maxi(cell_min.y, cell_max.y))
		for cell in _get_floor_cells(bounds_min, bounds_max):
			var floor_key := _get_floor_key(cell, cell)
			if loaded_floor_keys.has(floor_key):
				continue
			loaded_floor_keys[floor_key] = true
			floor_records.append({
				"key": floor_key,
				"cell_min": cell,
				"cell_max": cell,
				"item_id": floor_item.id,
				"surface": floor_item.surface,
			})

	var loaded_grid_size := float(map_data.get("grid_size", grid_size))
	if loaded_grid_size <= 0.0:
		push_error("Map grid size must be greater than zero: %s" % path)
		return {"error": ERR_INVALID_DATA}

	var saved_items: Variant = map_data.get("placed_items", [])
	if not saved_items is Array:
		push_error("Map placed items must be stored as an Array: %s" % path)
		return {"error": ERR_PARSE_ERROR}
	var placed_item_records: Array = []
	var loaded_item_cells: Dictionary = {}
	for saved_item_value in saved_items:
		if not saved_item_value is Dictionary:
			push_error("Invalid placed item entry in map: %s" % path)
			return {"error": ERR_PARSE_ERROR}
		var saved_item: Dictionary = saved_item_value
		var cell: Variant = saved_item.get("cell")
		var item_id := StringName(saved_item.get("item_id", &""))
		if not cell is Vector2i:
			push_error("Placed item cell must be a Vector2i: %s" % path)
			return {"error": ERR_PARSE_ERROR}
		var item := catalog.get_item(item_id) if catalog else null
		if (
			not item
			or item.category not in [
				MapEditorItem.Category.NPCS,
				MapEditorItem.Category.PROPS,
				MapEditorItem.Category.ITEMS,
				MapEditorItem.Category.META,
			]
			or not item.scene
		):
			push_error("Placed item is not in the catalogue: %s" % item_id)
			return {"error": ERR_FILE_NOT_FOUND}
		var item_key := _get_cell_key(cell)
		if loaded_item_cells.has(item_key):
			continue
		loaded_item_cells[item_key] = true
		placed_item_records.append({
			"key": item_key,
			"cell": cell,
			"item_id": item.id,
			"category": item.category,
			"scene": item.scene,
			"rotation_y": float(saved_item.get("rotation_y", 0.0)),
		})

	return {
		"error": OK,
		"grid_size": loaded_grid_size,
		"wall_records": wall_records,
		"floor_records": floor_records,
		"placed_item_records": placed_item_records,
	}


func _clear_all_structures() -> void:
	for child in walls.get_children():
		child.queue_free()
	for child in floors.get_children():
		child.queue_free()
	for child in npcs.get_children():
		child.queue_free()
	for child in props.get_children():
		child.queue_free()
	for child in items.get_children():
		child.queue_free()
	for child in meta.get_children():
		child.queue_free()
	occupied_wall_edges.clear()
	wall_edge_data.clear()
	occupied_floor_cells.clear()
	floor_nodes.clear()
	floor_data.clear()
	placed_item_data.clear()
	placed_item_nodes.clear()


func _update_grid_shader() -> void:
	var plane := grid.mesh as PlaneMesh
	if not plane:
		return
	var material := plane.material as ShaderMaterial
	if material:
		material.set_shader_parameter("cell_size", grid_size)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			_finish_delete_stroke()
			if event.shift_pressed:
				if undo_redo.has_redo():
					undo_redo.redo()
			elif undo_redo.has_undo():
				undo_redo.undo()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_Y:
			_finish_delete_stroke()
			if undo_redo.has_redo():
				undo_redo.redo()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_S:
			save_map()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_O:
			load_map()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if active_category in [
			MapEditorItem.Category.NPCS,
			MapEditorItem.Category.META,
		]:
			if event.pressed:
				var item_key := place_active_item(
					_screen_to_floor_cell(event.position))
				if not item_key.is_empty():
					rotating_placed_entity = true
					rotating_entity_key = item_key
					_rotate_placed_entity_toward(event.position)
			else:
				_rotate_placed_entity_toward(event.position)
				_finish_entity_rotation()
			get_viewport().set_input_as_handled()
			return
		if active_category in [
			MapEditorItem.Category.PROPS,
			MapEditorItem.Category.ITEMS,
		]:
			if event.pressed:
				place_active_item(_screen_to_floor_cell(event.position))
			get_viewport().set_input_as_handled()
			return
		if active_category == MapEditorItem.Category.WALLPAPERS:
			if event.pressed and active_item and active_item.surface:
				_finish_delete_stroke()
				_begin_wallpaper_stroke(event.position)
			elif not event.pressed:
				_finish_wallpaper_stroke()
			get_viewport().set_input_as_handled()
			return
		if not active_item or active_category not in [
			MapEditorItem.Category.WALLS,
			MapEditorItem.Category.FLOORS,
		]:
			return
		if event.pressed:
			_finish_delete_stroke()
			if active_category == MapEditorItem.Category.WALLS:
				_begin_wall(_screen_to_grid_point(event.position))
			else:
				_begin_floor(_screen_to_floor_cell(event.position))
		elif drawing_wall:
			_finish_wall()
		elif drawing_floor:
			_finish_floor()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if active_category in [
			MapEditorItem.Category.NPCS,
			MapEditorItem.Category.PROPS,
			MapEditorItem.Category.ITEMS,
			MapEditorItem.Category.META,
		]:
			if event.pressed:
				delete_placed_item(_screen_to_floor_cell(event.position))
			get_viewport().set_input_as_handled()
			return
		if active_category == MapEditorItem.Category.WALLPAPERS:
			if event.pressed:
				_begin_wallpaper_stroke(event.position, true)
			else:
				_finish_wallpaper_stroke()
			get_viewport().set_input_as_handled()
			return
		if active_category not in [
			MapEditorItem.Category.WALLS,
			MapEditorItem.Category.FLOORS,
		]:
			return
		deleting_walls = event.pressed
		if deleting_walls:
			_cancel_wall()
			_cancel_floor()
			if active_category == MapEditorItem.Category.WALLS:
				_delete_wall_at_screen_position(event.position)
			else:
				_delete_floor_at_screen_position(event.position)
		else:
			_finish_delete_stroke()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and drawing_wall:
		var grid_point := _screen_to_grid_point(event.position)
		_update_wall_end(grid_point)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and rotating_placed_entity:
		_rotate_placed_entity_toward(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and drawing_floor:
		_update_floor_end(_screen_to_floor_cell(event.position))
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and painting_wallpaper:
		_continue_wallpaper_stroke(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and deleting_walls:
		if active_category == MapEditorItem.Category.WALLS:
			_delete_wall_at_screen_position(event.position)
		else:
			_delete_floor_at_screen_position(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_finish_entity_rotation()
		_cancel_wall()
		_cancel_floor()
		_cancel_wallpaper_stroke()
		get_viewport().set_input_as_handled()


func _begin_wall(grid_point: Vector2i) -> void:
	drawing_wall = true
	wall_start = grid_point
	wall_end = grid_point
	_rebuild_preview()


func _update_wall_end(grid_point: Vector2i) -> void:
	var offset := grid_point - wall_start
	if absi(offset.x) >= absi(offset.y):
		wall_end = Vector2i(grid_point.x, wall_start.y)
	else:
		wall_end = Vector2i(wall_start.x, grid_point.y)
	_rebuild_preview()


func _finish_wall() -> void:
	drawing_wall = false
	create_wall(wall_start, wall_end)
	_clear_preview()


func _cancel_wall() -> void:
	drawing_wall = false
	_clear_preview()


func _begin_floor(cell: Vector2i) -> void:
	drawing_floor = true
	floor_start = cell
	floor_end = cell
	_rebuild_floor_preview()


func _update_floor_end(cell: Vector2i) -> void:
	floor_end = cell
	_rebuild_floor_preview()


func _finish_floor() -> void:
	drawing_floor = false
	create_floor(floor_start, floor_end)
	_clear_floor_preview()


func _cancel_floor() -> void:
	drawing_floor = false
	_clear_floor_preview()


func create_floor(start: Vector2i, end: Vector2i) -> void:
	if (
		not active_item
		or active_item.category != MapEditorItem.Category.FLOORS
		or not active_item.surface
	):
		push_warning("Select a floor from the Floors palette first.")
		return

	var cell_min := Vector2i(mini(start.x, end.x), mini(start.y, end.y))
	var cell_max := Vector2i(maxi(start.x, end.x), maxi(start.y, end.y))
	for x in range(cell_min.x, cell_max.x + 1):
		for y in range(cell_min.y, cell_max.y + 1):
			if occupied_floor_cells.has(_get_cell_key(Vector2i(x, y))):
				return

	var records: Array = []
	for cell in _get_floor_cells(cell_min, cell_max):
		records.append({
			"key": _get_floor_key(cell, cell),
			"cell_min": cell,
			"cell_max": cell,
			"item_id": active_item.id,
			"surface": active_item.surface,
		})
	undo_redo.create_action("Create Floor")
	undo_redo.add_do_method(_create_floor_records.bind(records))
	undo_redo.add_undo_method(_delete_floor_records.bind(records))
	undo_redo.commit_action()


func _rebuild_floor_preview() -> void:
	_clear_floor_preview()
	var bounds := _get_floor_bounds(floor_start, floor_end, grid_size)
	var preview := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(bounds["size"].x, 0.04, bounds["size"].y)
	preview.mesh = mesh
	preview.material_override = preview_material
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.position = bounds["position"] + Vector3.DOWN * 0.02
	floor_preview.add_child(preview)


func _clear_floor_preview() -> void:
	for child in floor_preview.get_children():
		floor_preview.remove_child(child)
		child.queue_free()


func place_active_item(cell: Vector2i) -> String:
	if (
		not active_item
		or active_item.category not in [
		MapEditorItem.Category.NPCS,
		MapEditorItem.Category.PROPS,
		MapEditorItem.Category.ITEMS,
		MapEditorItem.Category.META,
		]
		or not active_item.scene
	):
		return ""
	var item_key := _get_cell_key(cell)
	if placed_item_nodes.has(item_key):
		return ""
	var record := {
		"key": item_key,
		"cell": cell,
		"item_id": active_item.id,
		"category": active_item.category,
		"scene": active_item.scene,
		"rotation_y": 0.0,
	}
	undo_redo.create_action("Place %s" % active_item.display_name)
	undo_redo.add_do_method(_create_placed_item_records.bind([record]))
	undo_redo.add_undo_method(_delete_placed_item_records.bind([record]))
	undo_redo.commit_action()
	return item_key


func _rotate_placed_entity_toward(screen_position: Vector2) -> void:
	if not rotating_placed_entity:
		return
	var placed_node := placed_item_nodes.get(rotating_entity_key) as Node3D
	var record: Dictionary = placed_item_data.get(rotating_entity_key, {})
	if not placed_node or record.is_empty():
		_finish_entity_rotation()
		return
	var target := _screen_to_ground_position(screen_position)
	var direction := target - placed_node.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return
	var rotation_y := atan2(direction.x, direction.z)
	placed_node.global_rotation.y = rotation_y
	record["rotation_y"] = rotation_y
	placed_item_data[rotating_entity_key] = record


func _finish_entity_rotation() -> void:
	rotating_placed_entity = false
	rotating_entity_key = ""


func delete_placed_item(cell: Vector2i) -> void:
	var item_key := _get_cell_key(cell)
	var record: Dictionary = placed_item_data.get(item_key, {})
	if record.is_empty() or record["category"] != active_category:
		return
	undo_redo.create_action("Delete Placed Item")
	undo_redo.add_do_method(_delete_placed_item_records.bind([record]))
	undo_redo.add_undo_method(_create_placed_item_records.bind([record]))
	undo_redo.commit_action()


func _create_placed_item_records(records: Array) -> void:
	for record in records:
		var item_key: String = record["key"]
		if placed_item_nodes.has(item_key):
			continue
		var parent: Node3D
		match record["category"]:
			MapEditorItem.Category.NPCS:
				parent = npcs
			MapEditorItem.Category.ITEMS:
				parent = items
			MapEditorItem.Category.META:
				parent = meta
			_:
				parent = props
		var placed_node := _instantiate_placed_item(
			record, parent, grid_size, true)
		if not placed_node:
			continue
		placed_item_nodes[item_key] = placed_node
		placed_item_data[item_key] = record


func _delete_placed_item_records(records: Array) -> void:
	for record in records:
		var item_key: String = record["key"]
		var placed_node := placed_item_nodes.get(item_key) as Node3D
		if not placed_node:
			continue
		placed_item_nodes.erase(item_key)
		placed_item_data.erase(item_key)
		placed_node.queue_free()


func _instantiate_placed_item(
		record: Dictionary,
		parent: Node,
		placement_grid_size: float,
		disable_processing: bool
	) -> Node3D:
	var placed_node := record["scene"].instantiate() as Node3D
	if not placed_node:
		push_warning("Map editor item scene must have a Node3D root.")
		return null
	if disable_processing:
		placed_node.process_mode = Node.PROCESS_MODE_DISABLED
	var cell: Vector2i = record["cell"]
	placed_node.position = Vector3(
		(cell.x + 0.5) * placement_grid_size,
		0.0,
		(cell.y + 0.5) * placement_grid_size)
	placed_node.rotation.y = float(record.get("rotation_y", 0.0))
	parent.add_child(placed_node)
	if not disable_processing and placed_node is Weapon:
		placed_node.activate_world_pickup()
	return placed_node


func create_wall(start: Vector2i, end: Vector2i) -> void:
	if (
		not active_item
		or active_item.category != MapEditorItem.Category.WALLS
		or not active_item.surface
	):
		push_warning("Select a wall from the Walls palette first.")
		return

	var created_records: Array = []
	var replacement_records: Array = []
	var previous_records: Array = []
	for edge in _get_wall_edges(start, end):
		var edge_key := _get_edge_key(edge[0], edge[1])
		var previous: Dictionary = wall_edge_data.get(edge_key, {})
		if previous.is_empty():
			created_records.append({
				"key": edge_key,
				"point_a": edge[0],
				"point_b": edge[1],
				"item_id": active_item.id,
				"surface": active_item.surface,
			})
		elif StringName(previous.get("item_id", &"")) != active_item.id:
			var replacement := previous.duplicate(true)
			replacement["item_id"] = active_item.id
			replacement["surface"] = active_item.surface
			previous_records.append(previous.duplicate(true))
			replacement_records.append(replacement)

	if created_records.is_empty() and replacement_records.is_empty():
		return

	undo_redo.create_action("Paint Walls")
	if not created_records.is_empty():
		undo_redo.add_do_method(_create_wall_records.bind(created_records))
		undo_redo.add_undo_method(_delete_wall_records.bind(created_records))
	if not replacement_records.is_empty():
		undo_redo.add_do_method(_replace_wall_records.bind(replacement_records))
		undo_redo.add_undo_method(_replace_wall_records.bind(previous_records))
	undo_redo.commit_action()


func delete_wall(start: Vector2i, end: Vector2i) -> void:
	var records := _make_wall_records(start, end, null, &"", true)
	if records.is_empty():
		return

	undo_redo.create_action("Delete Wall")
	undo_redo.add_do_method(_delete_wall_records.bind(records))
	undo_redo.add_undo_method(_create_wall_records.bind(records))
	undo_redo.commit_action()


func _rebuild_preview() -> void:
	_clear_preview()
	for edge in _get_wall_edges(wall_start, wall_end):
		var edge_key := _get_edge_key(edge[0], edge[1])
		var placement := _get_edge_placement(edge[0], edge[1])
		var preview := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(grid_size, wall_height, 0.08)
		preview.mesh = mesh
		preview.material_override = (
			occupied_preview_material
			if occupied_wall_edges.has(edge_key)
			else preview_material
		)
		preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preview.position = placement.position + Vector3.UP * wall_height * 0.5
		preview.rotation.y = placement.rotation
		wall_preview.add_child(preview)


func _clear_preview() -> void:
	for child in wall_preview.get_children():
		wall_preview.remove_child(child)
		child.queue_free()


func _delete_wall_at_screen_position(screen_position: Vector2) -> void:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var wall := _get_placed_wall_for_node(hit.get("collider") as Node)
	if not wall:
		return

	var edge_key: String = occupied_wall_edges.find_key(wall)
	var record: Dictionary = wall_edge_data.get(edge_key, {})
	if record.is_empty():
		return

	delete_stroke_records.append(record.duplicate())
	_delete_wall_records([record])


func _begin_wallpaper_stroke(
		screen_position: Vector2,
		erase := false
	) -> void:
	_finish_wallpaper_stroke()
	painting_wallpaper = true
	erasing_wallpaper = erase
	wallpaper_start = _screen_to_grid_point(screen_position)
	wallpaper_end = wallpaper_start
	_rebuild_wallpaper_preview()


func _continue_wallpaper_stroke(screen_position: Vector2) -> void:
	wallpaper_end = _lock_to_axis(
		wallpaper_start, _screen_to_grid_point(screen_position))
	_rebuild_wallpaper_preview()


func _finish_wallpaper_stroke() -> void:
	if not painting_wallpaper:
		return
	painting_wallpaper = false
	_clear_preview()
	var erase := erasing_wallpaper
	erasing_wallpaper = false
	var changes: Array = []
	var side_reference := camera.global_position
	if camera_rig.view_mode == MapEditorCamera.ViewMode.TOP_DOWN:
		side_reference = _screen_to_ground_position(
			get_viewport().get_mouse_position())
	for edge in _get_wall_edges(wallpaper_start, wallpaper_end):
		var edge_key := _get_edge_key(edge[0], edge[1])
		var wall := occupied_wall_edges.get(edge_key) as SurfaceStackGeometry
		var record: Dictionary = wall_edge_data.get(edge_key, {})
		if not wall or record.is_empty():
			continue
		var slot := 2 if wall.to_local(side_reference).z >= 0.0 else 0
		var wallpaper_key := (
			WALLPAPER_SLOT_2_KEY if slot == 2 else WALLPAPER_SLOT_0_KEY)
		var previous_had_override := record.has(wallpaper_key)
		var previous_item_id := StringName(record.get(wallpaper_key, &""))
		if erase and not previous_had_override:
			continue
		if (
			not erase
			and previous_had_override
			and previous_item_id == active_item.id
		):
			continue
		changes.append({
			"edge_key": edge_key,
			"slot": slot,
			"previous_item_id": previous_item_id,
			"previous_had_override": previous_had_override,
			"new_item_id": &"" if erase else active_item.id,
			"new_has_override": not erase,
		})
	if changes.is_empty():
		return
	undo_redo.create_action(
		"Remove Wallpaper" if erase else "Paint Wallpaper")
	for change in changes:
		undo_redo.add_do_method(_set_wallpaper_override.bind(
			change["edge_key"],
			change["slot"],
			change["new_item_id"],
			change["new_has_override"]))
		undo_redo.add_undo_method(_set_wallpaper_override.bind(
			change["edge_key"],
			change["slot"],
			change["previous_item_id"],
			change["previous_had_override"]))
	undo_redo.commit_action()


func _cancel_wallpaper_stroke() -> void:
	painting_wallpaper = false
	erasing_wallpaper = false
	_clear_preview()


func _rebuild_wallpaper_preview() -> void:
	_clear_preview()
	for edge in _get_wall_edges(wallpaper_start, wallpaper_end):
		var edge_key := _get_edge_key(edge[0], edge[1])
		if not occupied_wall_edges.has(edge_key):
			continue
		var placement := _get_edge_placement(edge[0], edge[1])
		var preview := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(grid_size, wall_height, 0.09)
		preview.mesh = mesh
		preview.material_override = preview_material
		preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		preview.position = placement.position + Vector3.UP * wall_height * 0.5
		preview.rotation.y = placement.rotation
		wall_preview.add_child(preview)


func _set_wallpaper_override(
		edge_key: String,
		slot: int,
		item_id: StringName,
		has_override: bool
	) -> void:
	var record: Dictionary = wall_edge_data.get(edge_key, {})
	var wall := occupied_wall_edges.get(edge_key) as SurfaceStackGeometry
	if record.is_empty() or not wall:
		return
	var wallpaper_key := (
		WALLPAPER_SLOT_2_KEY if slot == 2 else WALLPAPER_SLOT_0_KEY)
	if has_override:
		record[wallpaper_key] = item_id
	else:
		record.erase(wallpaper_key)
	wall_edge_data[edge_key] = record
	wall.surface_stack = _build_wall_surface_stack(record)


func _delete_floor_at_screen_position(screen_position: Vector2) -> void:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var floor_node := _get_placed_floor_for_node(hit.get("collider") as Node)
	if not floor_node:
		return
	var floor_key: String = floor_nodes.find_key(floor_node)
	var record: Dictionary = floor_data.get(floor_key, {})
	if record.is_empty():
		return
	floor_delete_stroke_records.append(record.duplicate())
	_delete_floor_records([record])


func _finish_delete_stroke() -> void:
	deleting_walls = false
	if not delete_stroke_records.is_empty():
		var wall_records := delete_stroke_records.duplicate(true)
		delete_stroke_records.clear()
		undo_redo.create_action("Delete Walls")
		undo_redo.add_do_method(_delete_wall_records.bind(wall_records))
		undo_redo.add_undo_method(_create_wall_records.bind(wall_records))
		undo_redo.commit_action(false)

	if not floor_delete_stroke_records.is_empty():
		var deleted_floors := floor_delete_stroke_records.duplicate(true)
		floor_delete_stroke_records.clear()
		undo_redo.create_action("Delete Floors")
		undo_redo.add_do_method(_delete_floor_records.bind(deleted_floors))
		undo_redo.add_undo_method(_create_floor_records.bind(deleted_floors))
		undo_redo.commit_action(false)


func _make_wall_records(
		start: Vector2i,
		end: Vector2i,
		surface: SurfaceDefinition,
		item_id: StringName,
		only_existing: bool
	) -> Array:
	var records: Array = []
	for edge in _get_wall_edges(start, end):
		var edge_key := _get_edge_key(edge[0], edge[1])
		if only_existing:
			if wall_edge_data.has(edge_key):
				records.append(wall_edge_data[edge_key].duplicate())
		elif not occupied_wall_edges.has(edge_key):
			records.append({
				"key": edge_key,
				"point_a": edge[0],
				"point_b": edge[1],
				"item_id": item_id,
				"surface": surface,
			})
	return records


func _create_wall_records(records: Array) -> void:
	for record in records:
		var edge_key: String = record["key"]
		if occupied_wall_edges.has(edge_key):
			continue

		var wall := _instantiate_wall(record, walls, grid_size, true)
		if not wall:
			continue

		occupied_wall_edges[edge_key] = wall
		wall_edge_data[edge_key] = record


func _replace_wall_records(records: Array) -> void:
	for record in records:
		var edge_key: String = record["key"]
		var previous_wall := occupied_wall_edges.get(edge_key) as Node3D
		if previous_wall:
			occupied_wall_edges.erase(edge_key)
			wall_edge_data.erase(edge_key)
			previous_wall.queue_free()

		var wall := _instantiate_wall(record, walls, grid_size, true)
		if not wall:
			continue
		occupied_wall_edges[edge_key] = wall
		wall_edge_data[edge_key] = record


func _instantiate_wall(
		record: Dictionary,
		parent: Node,
		placement_grid_size: float,
		show_editor_helpers: bool
	) -> Node3D:
	var wall := SURFACE_STACK_SCENE.instantiate() as SurfaceStackGeometry
	if not wall:
		push_warning("Surface stack geometry scene must have a valid root.")
		return null

	wall.surface_stack = _build_wall_surface_stack(record)
	wall.size = Vector2(placement_grid_size, wall_height)
	wall.is_floor = false
	wall.show_editor_line = show_editor_helpers
	var placement := _get_edge_placement(
		record["point_a"],
		record["point_b"],
		placement_grid_size)
	wall.position = placement.position
	wall.rotation.y = placement.rotation
	parent.add_child(wall)
	return wall


func _build_wall_surface_stack(record: Dictionary) -> SurfaceStackDefinition:
	var core_surface: SurfaceDefinition = record["surface"]
	var result := SurfaceStackDefinition.new()
	result.id = StringName("wall_%s" % core_surface.id)
	result.display_name = core_surface.display_name
	var layers: Array[SurfaceLayerDefinition] = [null, null, null]
	var core_layer := SurfaceLayerDefinition.new()
	core_layer.surface = core_surface
	layers[1] = core_layer

	if record.has(WALLPAPER_SLOT_0_KEY):
		layers[0] = _make_wallpaper_layer(record[WALLPAPER_SLOT_0_KEY])
	if record.has(WALLPAPER_SLOT_2_KEY):
		layers[2] = _make_wallpaper_layer(record[WALLPAPER_SLOT_2_KEY])
	result.layers = layers
	return result


func _make_wallpaper_layer(item_id: StringName) -> SurfaceLayerDefinition:
	var item := catalog.get_item(item_id) if catalog else null
	if (
		not item
		or item.category != MapEditorItem.Category.WALLPAPERS
		or not item.surface
	):
		return null
	var layer := SurfaceLayerDefinition.new()
	layer.surface = item.surface
	return layer


func _delete_wall_records(records: Array) -> void:
	for record in records:
		var edge_key: String = record["key"]
		var wall := occupied_wall_edges.get(edge_key) as Node3D
		if not wall:
			continue

		occupied_wall_edges.erase(edge_key)
		wall_edge_data.erase(edge_key)
		wall.queue_free()


func _create_floor_records(records: Array) -> void:
	for record in records:
		var floor_key: String = record["key"]
		if floor_nodes.has(floor_key):
			continue
		var floor_node := _instantiate_floor(record, floors, grid_size)
		if not floor_node:
			continue
		floor_nodes[floor_key] = floor_node
		floor_data[floor_key] = record
		for cell in _get_floor_cells(record["cell_min"], record["cell_max"]):
			occupied_floor_cells[_get_cell_key(cell)] = floor_node


func _instantiate_floor(
		record: Dictionary,
		parent: Node,
		placement_grid_size: float
	) -> SurfaceStackGeometry:
	var bounds := _get_floor_bounds(
		record["cell_min"], record["cell_max"], placement_grid_size)
	var floor_node := SURFACE_STACK_SCENE.instantiate() as SurfaceStackGeometry
	if not floor_node:
		return null
	floor_node.surface_stack = _build_floor_surface_stack(record["surface"])
	floor_node.size = bounds["size"]
	floor_node.is_floor = true
	floor_node.position = bounds["position"]
	parent.add_child(floor_node)
	return floor_node


func _build_floor_surface_stack(
		surface: SurfaceDefinition
	) -> SurfaceStackDefinition:
	var layer := SurfaceLayerDefinition.new()
	layer.surface = surface
	var result := SurfaceStackDefinition.new()
	result.id = StringName("floor_%s" % surface.id)
	result.display_name = surface.display_name
	result.layers = [layer]
	return result


func _delete_floor_records(records: Array) -> void:
	for record in records:
		var floor_key: String = record["key"]
		var floor_node := floor_nodes.get(floor_key) as Node3D
		if not floor_node:
			continue
		for cell in _get_floor_cells(record["cell_min"], record["cell_max"]):
			occupied_floor_cells.erase(_get_cell_key(cell))
		floor_nodes.erase(floor_key)
		floor_data.erase(floor_key)
		floor_node.queue_free()


func _get_placed_floor_for_node(node: Node) -> Node3D:
	var current := node
	while current and current != floors:
		if floor_nodes.find_key(current) != null:
			return current as Node3D
		current = current.get_parent()
	return null


func _get_placed_wall_for_node(node: Node) -> Node3D:
	var current := node
	while current and current != walls:
		if occupied_wall_edges.find_key(current) != null:
			return current as Node3D
		current = current.get_parent()
	return null


func _screen_to_grid_point(screen_position: Vector2) -> Vector2i:
	var ground_position := _screen_to_ground_position(screen_position)
	return Vector2i(
		roundi(ground_position.x / grid_size),
		roundi(ground_position.z / grid_size))


func _screen_to_floor_cell(screen_position: Vector2) -> Vector2i:
	var ground_position := _screen_to_ground_position(screen_position)
	return Vector2i(
		floori(ground_position.x / grid_size),
		floori(ground_position.z / grid_size))


func _screen_to_ground_position(screen_position: Vector2) -> Vector3:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var distance := -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * distance


func _get_floor_bounds(
		start: Vector2i,
		end: Vector2i,
		placement_grid_size: float
	) -> Dictionary:
	var cell_min := Vector2i(mini(start.x, end.x), mini(start.y, end.y))
	var cell_max := Vector2i(maxi(start.x, end.x), maxi(start.y, end.y))
	var cell_count := cell_max - cell_min + Vector2i.ONE
	var floor_size := Vector2(cell_count) * placement_grid_size
	var centre := (Vector2(cell_min) + Vector2(cell_max) + Vector2.ONE) * 0.5
	centre *= placement_grid_size
	return {
		"size": floor_size,
		"position": Vector3(centre.x, 0.0, centre.y),
	}


func _get_floor_cells(cell_min: Vector2i, cell_max: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(cell_min.x, cell_max.x + 1):
		for y in range(cell_min.y, cell_max.y + 1):
			cells.append(Vector2i(x, y))
	return cells


func _get_cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _get_floor_key(cell_min: Vector2i, cell_max: Vector2i) -> String:
	return "%d,%d:%d,%d" % [
		cell_min.x, cell_min.y, cell_max.x, cell_max.y]


func _get_wall_edges(start: Vector2i, end: Vector2i) -> Array:
	var edges: Array = []
	end = _lock_to_axis(start, end)
	var difference := end - start
	var segment_count := absi(difference.x) + absi(difference.y)
	if segment_count == 0:
		return edges

	var direction := Vector2i(signi(difference.x), signi(difference.y))
	for segment_index in segment_count:
		var point_a := start + direction * segment_index
		var point_b := point_a + direction
		edges.append([point_a, point_b])
	return edges


func _lock_to_axis(start: Vector2i, end: Vector2i) -> Vector2i:
	var offset := end - start
	if absi(offset.x) >= absi(offset.y):
		return Vector2i(end.x, start.y)
	return Vector2i(start.x, end.y)


func _get_edge_placement(
		point_a: Vector2i,
		point_b: Vector2i,
		placement_grid_size := grid_size
	) -> Dictionary:
	var centre := (
		(Vector2(point_a) + Vector2(point_b))
		* placement_grid_size
		* 0.5
	)
	var along_z := point_a.x == point_b.x
	return {
		"position": Vector3(centre.x, 0.0, centre.y),
		"rotation": PI * 0.5 if along_z else 0.0,
	}


func _get_edge_key(point_a: Vector2i, point_b: Vector2i) -> String:
	if point_b.x < point_a.x or (
			point_b.x == point_a.x and point_b.y < point_a.y
	):
		var swap := point_a
		point_a = point_b
		point_b = swap
	return "%d,%d:%d,%d" % [point_a.x, point_a.y, point_b.x, point_b.y]
