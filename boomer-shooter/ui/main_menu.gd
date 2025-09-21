extends Control


func _ready() -> void:
	set_menu(%Main)
	Transition.play_end()
	
	add_button_sounds(self)


func add_button_sounds(parent: Node) -> void:
	for child in parent.get_children():
		if child is Button:
			child.mouse_entered.connect(%AudioHover.play)
			child.pressed.connect(%AudioSelect.play)
		else:
			add_button_sounds(child)


func _on_button_play_pressed() -> void:
	set_menu(%Difficulty)


func _on_button_back_pressed() -> void:
	set_menu(%Main)


func set_menu(menu: Control) -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			continue
		child.visible = child == menu


func _on_button_difficult_hard_pressed() -> void:
	Settings.difficulty = Settings.Difficulty.HARD
	play()


func _on_button_difficult_regular_pressed() -> void:
	Settings.difficulty = Settings.Difficulty.REGULAR
	play()


func _on_button_difficulty_easy_pressed() -> void:
	Settings.difficulty = Settings.Difficulty.EASY
	play()


func play() -> void:
	get_tree().change_scene_to_file("res://stages/guy_level_0.tscn")


func _on_button_settings_pressed() -> void:
	Settings.open(true)
