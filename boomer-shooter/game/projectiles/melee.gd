extends Area3D

func _ready() -> void:
	for i in 4:
		await get_tree().create_timer(0.05).timeout
		if not get_tree():
			return

		for body in get_overlapping_bodies():
			if "melee" in body:
				body.melee()
			elif "melee" in body.get_parent():
				body.get_parent().melee()

	queue_free()
