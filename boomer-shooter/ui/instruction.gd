extends CanvasLayer

@export var text: String = ""

var t: float = 0.0
func _ready() -> void:
	$Label.text = text


func _process(delta: float) -> void:
	t += delta / 0.3
	$Label.visible = fmod(t, 1.0) < 0.6