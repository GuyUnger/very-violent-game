extends Control


func _ready() -> void:
	set_menu(%Main)


func _on_button_play_pressed() -> void:
	set_menu(%Difficulty)


func _on_button_back_pressed() -> void:
	set_menu(%Main)


func set_menu(menu: Control) -> void:
	for child in get_children():
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
