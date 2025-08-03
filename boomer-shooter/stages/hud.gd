extends CanvasLayer

func _process(delta: float) -> void:
	%Time.text = str(ceili(Main.instance.time))
	if Main.instance.player.weapon:
		%Ammo.text = "Ammo: " + str(Main.instance.player.weapon.ammo)
	else:
		%Ammo.text = ""
