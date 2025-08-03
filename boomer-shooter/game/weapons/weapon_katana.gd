class_name WeaponKatana
extends Weapon


func shoot() -> void:
	$AnimationPlayer.play("attack")
