extends NPC
class_name NPCEnemyTurret

func set_target(node:Node3D) -> void:
	target = node
	

func _ready() -> void:
	super()
	add_child(StateIdle.new())


func _physics_process(delta: float) -> void:
	if target:
		$Node3D.look_at(target.global_position)


func knock_back(force) -> void:
	pass
	
func die() -> void:
	set_physics_process(false)
	remove_from_group("aimables")
	died.emit()
