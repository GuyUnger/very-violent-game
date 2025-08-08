extends CanvasLayer

func _ready() -> void:
	Main.hud = self

func _process(delta: float) -> void:
	%Time.text = str(ceili(Main.instance.time))
	if Main.instance.player.weapon:
		%Ammo.text = "Ammo: " + str(Main.instance.player.weapon.ammo)
	else:
		%Ammo.text = ""
	
	%ProgressBar.visible = Main.instance.total_enemies > 0
	%ProgressBar.max_value = Main.instance.total_enemies
	
	var enemies_killed = Main.instance.total_enemies - Main.instance.enemies_left
	%ProgressBar.value = enemies_killed
	%LabelEnemies.text = str(enemies_killed) + " / " + str(Main.instance.total_enemies)
	