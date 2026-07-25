extends Area3D

@export var portal_to:PackedScene
var triggered_ := false

func _ready() -> void:
	body_entered.connect(_body_entered)


func _body_entered(node: Node3D) -> void:
	if triggered_:
		return

	triggered_ = true
	node.physics_enabled = false
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_packed(portal_to)
