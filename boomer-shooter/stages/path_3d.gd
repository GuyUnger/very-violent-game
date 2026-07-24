extends Path3D

func _process(delta: float) -> void:
	$PathFollow3D.progress_ratio += delta * 0.05
	$PathFollow3D/RemoteTransform3D.look_at($"../Center".global_position)
