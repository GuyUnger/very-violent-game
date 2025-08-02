extends Node3D

var tween : Tween

@onready var mesh_muzzleflash: MeshInstance3D = $MeshMuzzleflash
@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh_muzzleflash_2: MeshInstance3D = $MeshMuzzleflash/MeshMuzzleflash2


func _ready() -> void:
	light.hide()

func shoot(s := 2.0):
	$GPUParticles3D.restart()
	if tween:
		tween.kill()
	light.show()
	light.light_energy = 10.0
	mesh_muzzleflash.rotation.z = randf()*TAU
	mesh_muzzleflash_2.rotation.z = randf()*TAU
	mesh_muzzleflash.show()
	mesh_muzzleflash.scale = Vector3.ONE*s
	tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	#tween.tween_property(light, "light_energy", 0.0, 0.2)
	tween.tween_property(mesh_muzzleflash, "scale", Vector3.ONE*s*0.5, 0.2)
	tween.tween_callback(hide_all).set_delay(0.05)


func hide_all():
	mesh_muzzleflash.hide()
	light.hide()
	
	
