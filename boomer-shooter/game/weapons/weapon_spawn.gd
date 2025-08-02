extends Node3D


const WEAPON_SCENES = [
	preload("res://game/weapons/weapon_smg.tscn"),
	preload("res://game/weapons/weapon_shotgun.tscn"),
	preload("res://game/weapons/weapon_sniper.tscn"),
	preload("res://game/weapons/weapon_revolver.tscn"),
]

static var previous_weapon: int = -1

func _ready() -> void:
	await get_tree().process_frame
	var weapon_i: int = previous_weapon
	while weapon_i == previous_weapon:
		weapon_i = randi() % WEAPON_SCENES.size()
	var weapon = WEAPON_SCENES[weapon_i].instantiate()
	get_parent().add_child(weapon)
	weapon.global_position = global_position + Vector3.UP * 1.0
	await get_tree().process_frame
	weapon.throw(Vector3.DOWN)