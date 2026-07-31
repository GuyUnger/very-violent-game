extends Weapon
class_name WeaponSniper

@onready var red_dot := $RedDotContainer

func _physics_process(delta: float) -> void:
	super(delta)
	red_dot.visible = reload_t <= 0.2


func _process(delta: float) -> void:
	red_dot.global_transform.basis.z = lerp(red_dot.global_transform.basis.z, aim_dir, delta * 20.0)
	
