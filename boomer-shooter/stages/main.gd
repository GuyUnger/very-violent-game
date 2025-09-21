class_name Main
extends Node3D

signal enemy_killed

static var instance: Main
static var hud

var source_id := 1

@export var time: float = 30.0

var enemies_total: int
var enemies_killed: int

var completed: bool = false

@export var track_num: int = 0

static var clones: int = 0


func _init() -> void:
	instance = self
	

func _ready() -> void:
	EventStore.register_source(source_id, self)
	get_tree().paused = true
	
	match Settings.difficulty:
		Settings.Difficulty.EASY:
			time *= 4.0
		Settings.Difficulty.REGULAR:
			pass
		Settings.Difficulty.HARD:
			time *= 0.7
	
	clones += 1
	await get_tree().process_frame
	enemies_total = get_tree().get_nodes_in_group("npc_enemies").size()
	
	enemy_killed.connect(_on_enemy_killed)
	await get_tree().create_timer(0.3).timeout
	get_tree().paused = false
	Transition.play_track(track_num)
	

func _on_enemy_killed() -> void:
	enemies_killed = 0
	for enemy in get_tree().get_nodes_in_group("npc_enemies"):
		if enemy.health <= 0:
			enemies_killed += 1
	
	var pitch: float = 0.6 + (enemies_killed / float(enemies_total)) * 2.0
	
	await get_tree().create_timer(0.1).timeout
	if not get_tree():
		return
	if enemies_killed >= enemies_total and not completed:
		$AudioKillComplete.play()
		completed = true
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
