extends Node

@onready var interaction_raycast = $"../Nek/Head/Eyes/Camera/InteractionRaycast"
@onready var hold_point = $"../Nek/Head/Eyes/Camera/HoldPoint"

var picked_object = null
const pull_power = 4


func _ready():
	pass

func pick_object():
	var collider = interaction_raycast.get_collider()
	if collider != null and collider is RigidBody3D:
		if picked_object == collider:
			drop_object()
		else:
			picked_object = collider
	else:
		drop_object()
		
func drop_object():
	picked_object = null

func _physics_process(delta):
	if picked_object != null:
		var a = picked_object.global_transform.origin
		var b = hold_point.global_transform.origin
		picked_object.set_linear_velocity((b-a) * pull_power)
	pass
