extends CSGPolygon3D

func trigger() -> void:
	$Path3D/PathFollow3D/GPUParticles3D.visible = true
	var t := create_tween()
	t.tween_property($Path3D/PathFollow3D, "progress_ratio", 0.0,  6.0)
