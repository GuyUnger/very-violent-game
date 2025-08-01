extends CanvasLayer

func _process(delta: float) -> void:
	%Time.text = str(ceili(get_parent().time))