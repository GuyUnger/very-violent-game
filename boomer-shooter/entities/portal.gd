extends Area3D

@export var portal_to:PackedScene

func _ready() -> void:
	body_entered.connect(_body_entered)
	

func _body_entered(node: Node3D) -> void:
	get_tree().change_scene_to_packed(portal_to)
