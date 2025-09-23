extends CanvasLayer

enum Difficulty {
	EASY,
	REGULAR,
	HARD,
}

var difficulty: int = Difficulty.REGULAR
var look_sensitivity: float = 1.0


func _on_slider_look_sensitivity_value_changed(value: float) -> void:
	look_sensitivity = value

func _on_button_close_pressed() -> void:
	close()


func _on_button_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	close()


func _on_button_continue_pressed() -> void:
	close()


func close() -> void:
	hide()
	get_tree().paused = false


func open(from_menu: bool = false) -> void:
	get_tree().paused = true
	show()
	%ButtonClose.visible = from_menu
	%ButtonMainMenu.visible = not from_menu
	%ButtonContinue.visible = not from_menu
	%Fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	

func _on_fullscreen_toggled(toggled_on:bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
