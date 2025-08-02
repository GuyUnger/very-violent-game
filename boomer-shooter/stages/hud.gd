extends CanvasLayer

func _process(delta: float) -> void:
	%Time.text = str(ceili(Main.instance.time))
