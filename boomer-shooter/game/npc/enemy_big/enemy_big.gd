extends NPCEnemy


func knock_back(force:Vector3) -> void:
	pass


func hit(damage:int) -> void:
	super(damage)
	$Label3D.text = str(health)
	if health <= 0:
		queue_free()
