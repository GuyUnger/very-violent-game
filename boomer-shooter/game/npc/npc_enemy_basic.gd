class_name NPCEnemyBasic
extends NPCEnemy


func _ready() -> void:
	add_child(StateIdle.new())
