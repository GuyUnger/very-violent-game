@tool
extends NPC
class_name NPCEnemy


func hit(damage:int) -> void:
	if health <= 0:
		return
	health -= damage
	spawn_blood_puddle()
	spawn_blood_splash()
	if health <= 0:
		set_physics_process(false)
		#await get_tree().create_timer(1.0).timeout
		#queue_free()


func spawn_blood_puddle() -> void:
	var blood = preload("res://game/npc/blood.tscn").instantiate()
	get_parent().add_child(blood)
	blood.position = position
	blood.position.x += randf_range(-0.5, 0.5)
	blood.position.z += randf_range(-0.5, 0.5)
	blood.position.y += 0.01
	blood.scale = Vector3.ONE * randf_range(0.2, 1.5)
	var tween = create_tween()
	tween.tween_property(blood, "scale", Vector3.ZERO, 10.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	await tween.finished
	blood.queue_free()

func spawn_blood_splash() -> void:
	var blood = preload("res://game/npc/blood_splash.tscn").instantiate()
	get_parent().add_child(blood)
	blood.position = position + Vector3.UP * 1.0
	blood.position.x += randf_range(-0.5, 0.5)
	blood.position.z += randf_range(-0.5, 0.5)
	blood.position.y += randf_range(-0.5, 0.5)
	blood.scale = Vector3.ONE * randf_range(0.05, 0.4)
	var tween = create_tween()
	tween.tween_property(blood, "frame", 15, 0.3)
	await tween.finished
	blood.queue_free()
