extends AudioStreamPlayer

static var liam_gag := false

func _ready() -> void:
	if not liam_gag:
		liam_gag = true
		play()
