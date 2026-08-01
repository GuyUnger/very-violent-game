class_name MapEditorCatalog
extends Resource

@export var items: Array[MapEditorItem] = []
@export var included_catalogs: Array[MapEditorCatalog] = []

var resolved_items: Array[MapEditorItem] = []
var has_rebuilt := false


func rebuild() -> void:
	resolved_items.clear()
	_append_catalog(self, {}, {})
	has_rebuilt = true


func _append_catalog(
	catalog: MapEditorCatalog,
	item_ids: Dictionary,
	active_catalogs: Dictionary,
) -> void:
	var catalog_instance_id := catalog.get_instance_id()
	if active_catalogs.has(catalog_instance_id):
		push_error("Cyclic map editor catalogue inclusion detected.")
		return
	active_catalogs[catalog_instance_id] = true

	for item in catalog.items:
		if not item:
			continue
		if item_ids.has(item.id):
			push_error("Duplicate map editor item id: %s" % item.id)
			continue
		item_ids[item.id] = true
		resolved_items.append(item)

	for included_catalog in catalog.included_catalogs:
		if included_catalog:
			_append_catalog(included_catalog, item_ids, active_catalogs)

	active_catalogs.erase(catalog_instance_id)


func _ensure_rebuilt() -> void:
	if not has_rebuilt:
		rebuild()


func get_items_in_category(category: int) -> Array[MapEditorItem]:
	_ensure_rebuilt()
	var result: Array[MapEditorItem] = []
	for item in resolved_items:
		if item and item.category == category and item.show_in_palette:
			result.append(item)
	return result


func get_item(item_id: StringName) -> MapEditorItem:
	_ensure_rebuilt()
	for item in resolved_items:
		if item and item.id == item_id:
			return item
	return null
