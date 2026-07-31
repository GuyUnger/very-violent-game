class_name MapEditorCatalog
extends Resource

const BUILTIN_CATALOG_DIRECTORY := "res://map_editor/builtin_catalogs"

@export var items: Array[MapEditorItem] = []

var base_item_count := -1


func rebuild() -> void:
	if base_item_count < 0:
		base_item_count = items.size()
	else:
		items.resize(base_item_count)

	var file_names := DirAccess.get_files_at(BUILTIN_CATALOG_DIRECTORY)
	file_names.sort()
	for file_name in file_names:
		if file_name.get_extension().to_lower() != "cfg":
			continue
		_load_catalog_file(BUILTIN_CATALOG_DIRECTORY.path_join(file_name))


func _load_catalog_file(path: String) -> void:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		push_error("Could not load map editor catalogue %s: %s" % [path, error])
		return
	var category := _category_from_name(
		String(config.get_value("catalog", "category", "")))
	if category < 0:
		push_error("Map editor catalogue has an invalid category: %s" % path)
		return

	for section in config.get_sections():
		if section == "catalog":
			continue
		var item_id := StringName(section)
		if get_item(item_id):
			push_error("Duplicate map editor item id: %s" % item_id)
			continue
		var item := MapEditorItem.new()
		item.id = item_id
		item.display_name = String(config.get_value(
			section, "display_name", section.capitalize()))
		item.category = category
		item.show_in_palette = bool(config.get_value(
			section, "show_in_palette", true))
		if category in [
			MapEditorItem.Category.WALLS,
			MapEditorItem.Category.FLOORS,
			MapEditorItem.Category.WALLPAPERS,
		]:
			var surface_path := String(config.get_value(section, "surface", ""))
			item.surface = load(surface_path) as SurfaceDefinition
			if not item.surface:
				push_error(
					"Could not load surface for map editor item %s: %s" % [
						item_id, surface_path])
				continue
		else:
			var scene_path := String(config.get_value(section, "scene", ""))
			item.scene = load(scene_path) as PackedScene
			if not item.scene:
				push_error("Could not load scene for map editor item %s: %s" % [
					item_id, scene_path])
				continue
			item.footprint = config.get_value(
				section, "footprint", Vector2i.ONE)
		items.append(item)


func _category_from_name(category_name: String) -> int:
	match category_name.to_lower():
		"walls":
			return MapEditorItem.Category.WALLS
		"floors":
			return MapEditorItem.Category.FLOORS
		"npcs":
			return MapEditorItem.Category.NPCS
		"props":
			return MapEditorItem.Category.PROPS
		"wallpapers", "wall_papers":
			return MapEditorItem.Category.WALLPAPERS
		"items":
			return MapEditorItem.Category.ITEMS
		"meta":
			return MapEditorItem.Category.META
	return -1


func get_items_in_category(category: int) -> Array[MapEditorItem]:
	var result: Array[MapEditorItem] = []
	for item in items:
		if item and item.category == category and item.show_in_palette:
			result.append(item)
	return result


func get_item(item_id: StringName) -> MapEditorItem:
	for item in items:
		if item and item.id == item_id:
			return item
	return null
