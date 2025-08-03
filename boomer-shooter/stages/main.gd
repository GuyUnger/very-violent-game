class_name Main
extends Node3D

signal enemy_killed

static var instance

var source_id := 1

@export var time: float = 30.0

var total_enemies: int
var enemies_left: int


func _init() -> void:
	instance = self
	

func _ready() -> void:
	EventStore.register_source(source_id, self)
	get_tree().paused = true
	
	await get_tree().process_frame
	total_enemies = get_tree().get_nodes_in_group("npc_enemies").size()
	enemies_left = total_enemies
	enemy_killed.connect(_on_enemy_killed)
	await get_tree().create_timer(0.3).timeout
	get_tree().paused = false

func _on_enemy_killed() -> void:
	enemies_left = 0
	for enemy in get_tree().get_nodes_in_group("npc_enemies"):
		if enemy.health > 0:
			enemies_left +=1
	
	var pitch: float = 0.6 + (1.0 - (enemies_left / float(total_enemies))) * 2.0
	
	await get_tree().create_timer(0.5).timeout
	if not get_tree():
		return
	if enemies_left == 0:
		$AudioKillComplete.play()
	else:
		%AudioKill.pitch_scale = pitch
		%AudioKill.play()

static var player: Player

var count_down_played: bool = false
func _process(delta: float) -> void:
	if time > 0:
		if time < 5.0 and not count_down_played:
			%AudioCountDown.play()
			count_down_played = true
		time -= delta
		if time <= 0:
			player.die()
	#$AudioStreamPlayer.pitch_scale = 1.0 + (1.0 - (time / 30.0)) * 0.5
