extends Node3D

@export var allow_shotgun: bool = true
@export var allow_sniper: bool = true
@export var allow_revolver: bool = true
@export var allow_katana: bool = true
@export var allow_smg: bool = true
@export var allow_double_smg: bool = false
@export var allow_ak: bool = false
@export var infinite := false

const WEAPON_SCENES = [
	preload("res://weapons/weapon_smg.tscn"),
	preload("res://weapons/weapon_shotgun.tscn"),
	preload("res://weapons/weapon_sniper.tscn"),
	preload("res://weapons/weapon_revolver.tscn"),
	preload("res://weapons/weapon_katana.tscn"),
	preload("res://weapons/weapon_double_smg.tscn"),
	preload("res://weapons/weapon_ak.tscn"),
]


var weapon_scenes: Array = []
static var previous_weapon: int = -1
var spawned_weapon: Weapon

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
	if allow_ak:
		weapon_scenes.append(WEAPON_SCENES[6])

	await get_tree().process_frame
	_spawn_weapon()


func _spawn_weapon() -> void:
	if weapon_scenes.is_empty():
		return

	var weapon_i := 0
	if weapon_scenes.size() > 1:
		weapon_i = randi_range(0, weapon_scenes.size() - 1)
		if weapon_i == previous_weapon:
			weapon_i = (weapon_i + randi_range(1, weapon_scenes.size() - 1)) % weapon_scenes.size()
	previous_weapon = weapon_i
	var weapon: Weapon = weapon_scenes[weapon_i].instantiate()
	spawned_weapon = weapon
	
	get_parent().add_child(weapon)
	weapon.global_position = global_position + Vector3.UP * 1.0
	if infinite:
		weapon.released_by_holder.connect(_spawned_weapon_released, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	weapon.throw(Vector3.DOWN)


func _spawned_weapon_released() -> void:
	if not infinite:
		return
	_spawn_weapon()
