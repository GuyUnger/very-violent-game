extends Node3D

@export var allow_shotgun: bool = true
@export var allow_sniper: bool = true
@export var allow_revolver: bool = true
@export var allow_katana: bool = true
@export var allow_smg: bool = true
@export var allow_double_smg: bool = false

const WEAPON_SCENES = [
	preload("res://game/weapons/weapon_smg.tscn"),
	preload("res://game/weapons/weapon_shotgun.tscn"),
	preload("res://game/weapons/weapon_sniper.tscn"),
	preload("res://game/weapons/weapon_revolver.tscn"),
	preload("res://game/weapons/weapon_katana.tscn"),
	preload("res://game/weapons/weapon_double_smg.tscn"),
]


var weapon_scenes: Array = []
static var previous_weapon: int = -1

func _ready() -> void:
	if allow_shotgun:
		weapon_scenes.append(WEAPON_SCENES[1])
	if allow_sniper:
		weapon_scenes.append(WEAPON_SCENES[2])
	if allow_revolver:
		weapon_scenes.append(WEAPON_SCENES[3])
	if allow_katana:
		weapon_scenes.append(WEAPON_SCENES[4])
	if allow_smg:
		weapon_scenes.append(WEAPON_SCENES[0])
	if allow_double_smg:
		weapon_scenes.append(WEAPON_SCENES[5])
	
	await get_tree().process_frame
	var weapon_i: int = previous_weapon
	while weapon_i == previous_weapon:
		weapon_i = randi() % weapon_scenes.size()
	var weapon = weapon_scenes[weapon_i].instantiate()
	
	get_parent().add_child(weapon)
	weapon.global_position = global_position + Vector3.UP * 1.0
	await get_tree().process_frame
	weapon.throw(Vector3.DOWN)
