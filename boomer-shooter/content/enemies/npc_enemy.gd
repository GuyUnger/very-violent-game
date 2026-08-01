@tool
extends NPC
class_name NPCEnemy

func _ready() -> void:
	super()


func hit(damage: int) -> void:
	super(damage)


func melee() -> void:
	super()

	$AudioHurt.unit_size = 10
	$AudioHurt.volume_db = 5.0
	$AudioHurt.play()

	var x := preload("res://content/fx/bloot_line.tscn").instantiate()
	$CollisionShape3D.add_child(x)
	x.position.y += 0.5
	x.look_at(Main.instance.player.global_position + Vector3.UP * 2.0, Vector3.UP, true)
