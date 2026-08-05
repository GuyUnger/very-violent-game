extends CanvasLayer

@export_range(0.01, 1.0) var hit_effect_rise_time := 0.1
@export_range(0.0, 3.0) var hit_effect_hang_time := 1.0
@export_range(0.05, 4.0) var hit_effect_fade_time := 4.0
@export_range(20.0, 20000.0) var hit_low_pass_cutoff := 1000.0
@export_range(20.0, 20000.0) var normal_low_pass_cutoff := 16000.0

var hit_effect_tween: Tween


func _ready() -> void:
	Main.hud = self
	if is_instance_valid(Main.player):
		Main.player.damaged.connect(_on_player_damaged)
	
	AudioEffects.low_pass = normal_low_pass_cutoff


func _on_player_damaged(amount: float) -> void:
	if hit_effect_tween:
		hit_effect_tween.kill()

	var current_strength: float = %ScreenSpaceEffects.damage_mist
	_set_hit_effect_strength(current_strength)

	hit_effect_tween = create_tween()
	hit_effect_tween.tween_method(
		_set_hit_effect_strength,
		current_strength,
		1.0,
		hit_effect_rise_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hit_effect_tween.tween_interval(hit_effect_hang_time)
	hit_effect_tween.tween_method(
		_set_hit_effect_strength,
		1.0,
		0.0,
		hit_effect_fade_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_hit_effect_strength(value: float) -> void:
	%ScreenSpaceEffects.damage_mist = value
	AudioEffects.low_pass = lerpf(
		normal_low_pass_cutoff,
		hit_low_pass_cutoff,
		value
	)


func hide_gameplay_ui() -> void:
	set_process(false)
	%Time.hide()
	%Hint.hide()
	%Ammo.hide()
	%Health.hide()
	%ProgressBar.hide()

func _process(delta: float) -> void:
	%Time.text = str(ceili(Main.instance.time))
	%Health.text = "Health: %.1f" % maxf(Main.instance.player.health, 0.0)
	if Main.instance.player.weapon:
		%Ammo.text = "Ammo: " + str(Main.instance.player.weapon.ammo)
	else:
		%Ammo.text = ""
	
	%ProgressBar.visible = Main.instance.total_enemies > 0
	%ProgressBar.max_value = Main.instance.total_enemies
	
	var enemies_killed = Main.instance.total_enemies - Main.instance.enemies_left
	%ProgressBar.value = enemies_killed
	%LabelEnemies.text = str(enemies_killed) + " / " + str(Main.instance.total_enemies)
	
