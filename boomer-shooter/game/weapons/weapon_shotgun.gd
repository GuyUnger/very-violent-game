class_name WeaponShotgun
extends Weapon


func shoot() -> void:
	ammo += 15
	for i in 16:
		total_recoil = 0.4
		super()
		await get_tree().process_frame
