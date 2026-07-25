extends StaticBody3D
class_name Prop

signal died

@export var max_hp := 5
@export var can_run_through := false
@onready var hp = max_hp
@onready var visual_mesh: Node3D = $MeshInstance3D

var tween_:Tween

func hit(pos:Vector3, normal:Vector3, damage) -> void:
	if hp <= 0:
		return
		
	if tween_ and tween_.is_valid():
		tween_.kill()

	if visual_mesh:
		visual_mesh.position *= 0.0
		var start_position := visual_mesh.position
		var nudge_offset := to_local(pos - normal * 0.05) - to_local(pos)
		tween_ = create_tween()
		tween_.tween_property(visual_mesh, "position", start_position + nudge_offset, 0.03)
		tween_.tween_property(visual_mesh, "position", start_position, 0.12)
	
	$HitSound.play()
	
	_spawn_wall_sparks(pos, normal)

	hp = max(0, hp - damage)
	
	if hp <= 0:
		explode()
		

func try_break_from_sprint_impact() -> bool:
	if hp <= 0:
		return false
	if not can_run_through:
		return false

	hp = 0
	explode()
	return true


func explode() -> void:
	died.emit()

	var p := preload("res://vfx/vfx_burst_wood_planks.tscn").instantiate()
	p.position = global_position
	get_parent().add_child(p)

	queue_free()


func _spawn_wall_sparks(hit_position: Vector3, hit_normal: Vector3) -> void:
	var sparks := preload("res://game/fx/wall_sparks.tscn").instantiate()
	sparks.position = to_local(hit_position)
	sparks.look_at_from_position(
		hit_position,
		hit_position + hit_normal,
		Vector3.UP,
		true)
	add_child(sparks)
