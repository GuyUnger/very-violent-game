@tool
class_name SurfaceStackDefinition
extends Resource

@export var id: StringName:
	set(value): id = value; emit_changed()
@export var display_name: String:
	set(value): display_name = value; emit_changed()
@export var layers: Array[SurfaceLayerDefinition] = []:
	set(value):
		_disconnect_layers(layers)
		layers = value
		_connect_layers(layers)
		emit_changed()


func _connect_layers(surface_layers: Array[SurfaceLayerDefinition]) -> void:
	for layer in surface_layers:
		if layer and not layer.changed.is_connected(_on_layer_changed):
			layer.changed.connect(_on_layer_changed)


func _disconnect_layers(surface_layers: Array[SurfaceLayerDefinition]) -> void:
	for layer in surface_layers:
		if layer and layer.changed.is_connected(_on_layer_changed):
			layer.changed.disconnect(_on_layer_changed)


func _on_layer_changed() -> void:
	emit_changed()
