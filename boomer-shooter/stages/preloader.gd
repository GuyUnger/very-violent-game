extends Node3D

func _ready()->void:
	$Muzzleflash.shoot()
	
	await get_tree().create_timer(0.5).timeout
	queue_free()