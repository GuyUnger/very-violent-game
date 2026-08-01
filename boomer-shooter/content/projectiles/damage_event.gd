class_name DamageEvent
extends RefCounted

var source: Node3D
var shot_origin := Vector3.ZERO
var hit_position := Vector3.ZERO
var hit_normal := Vector3.ZERO
var hit_shape: CollisionShape3D
var base_damage := 0.0
var body_part_multiplier := 1.0


func get_damage() -> float:
	var scaled_damage := base_damage * body_part_multiplier
	return maxf(scaled_damage, 0.0)
