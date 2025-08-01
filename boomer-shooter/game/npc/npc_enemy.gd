@tool
extends NPC
class_name NPCEnemy

func hit(damage:int) -> void:
	health -= damage
	if health <= 0:
		set_physics_process(false)
		await get_tree().create_timer(1.0).timeout
		queue_free()
