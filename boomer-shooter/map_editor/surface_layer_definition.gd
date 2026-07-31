@tool
class_name SurfaceLayerDefinition
extends Resource

@export var surface: SurfaceDefinition:
	set(value):
		if surface and surface.changed.is_connected(_on_surface_changed):
			surface.changed.disconnect(_on_surface_changed)
		surface = value
		if surface and not surface.changed.is_connected(_on_surface_changed):
			surface.changed.connect(_on_surface_changed)
		emit_changed()

@export_range(0.001, 1.0, 0.001) var spacing_from_previous := 0.06:
	set(value): spacing_from_previous = value; emit_changed()


func _on_surface_changed() -> void:
	emit_changed()
