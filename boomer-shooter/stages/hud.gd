extends CanvasLayer

func _ready() -> void:
	Main.hud = self

func _process(delta: float) -> void:
	%Time.text = str(ceili(Main.instance.time))
	if Main.instance.player.weapon:
		%Ammo.text = "Ammo: " + str(Main.instance.player.weapon.ammo)
	else:
		%Ammo.text = ""
	
	%ProgressBar.visible = Main.instance.enemies_total > 0
	%ProgressBar.max_value = Main.instance.enemies_total
	
	%ProgressBar.value = Main.instance.enemies_killed
	%LabelEnemies.text = str(Main.instance.enemies_killed) + " / " + str(Main.instance.enemies_total)
	