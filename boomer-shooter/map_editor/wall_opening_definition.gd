@tool
class_name WallOpeningDefinition
extends Resource

@export var id: StringName:
	set(value): id = value; emit_changed()
@export var display_name: String:
	set(value): display_name = value; emit_changed()
@export_range(0.1, 10.0, 0.05) var width := 0.75:
	set(value): width = value; emit_changed()
@export_range(0.1, 10.0, 0.05) var height := 0.75:
	set(value): height = value; emit_changed()
@export_range(0.0, 10.0, 0.05) var bottom_height := 0.0:
	set(value): bottom_height = value; emit_changed()
@export var insert_scene: PackedScene:
	set(value): insert_scene = value; emit_changed()
