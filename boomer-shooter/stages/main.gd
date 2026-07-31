class_name Main
extends Node3D

const PORTAL_PLACEMENT_HINT := "SHOOT THE FLOOR TO KILL MORE"

signal enemy_killed
signal all_enemies_killed

static var instance
static var hud

@export var time: float = 30.0
@export_multiline var entry_hint_message := ""
@export_range(0.0, 10.0, 0.1) var portal_placement_delay := 2.0
@export_range(0.0, 30.0, 0.1) var portal_auto_spawn_delay := 5.0

var total_enemies: int
var actual_enemies: int
var enemies_left: int

var max_enemies: int = 30
var completed: bool= false
var portal_spawned := false
var portal_placement_enabled := false
var hint_request_id := 0

@export var track_num: int = 0
@export var next_level: PackedScene

static var clones: int = 0


func _init() -> void:
	instance = self
	

func _ready() -> void:
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
	total_enemies = get_tree().get_nodes_in_group("npc_enemies").size()
	actual_enemies = total_enemies
	total_enemies = min(total_enemies, max_enemies)

	enemies_left = total_enemies
	enemy_killed.connect(_on_enemy_killed)
	await get_tree().create_timer(0.3).timeout
	get_tree().paused = false
	show_hint(entry_hint_message, 2.0)
	Transition.play_track(track_num)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
	

func _on_enemy_killed() -> void:
	enemies_left = 0
	for enemy in get_tree().get_nodes_in_group("npc_enemies"):
		if enemy.health > 0:
			enemies_left += 1
	
	enemies_left = max(enemies_left - (actual_enemies - total_enemies), 0)
	
	var pitch: float = 0.6 + (1.0 - (enemies_left / float(total_enemies))) * 2.0
	
	await get_tree().create_timer(0.5).timeout
	if not get_tree():
		return
	if enemies_left == 0 and !completed:
		$AudioKillComplete.play()
		completed = true
		all_enemies_killed.emit()
		await get_tree().create_timer(portal_placement_delay).timeout
		if not is_inside_tree() or portal_spawned:
			return
		portal_placement_enabled = true
		show_hint(PORTAL_PLACEMENT_HINT, portal_auto_spawn_delay)
		await get_tree().create_timer(portal_auto_spawn_delay).timeout
		if not is_inside_tree() or portal_spawned:
			return
		if is_instance_valid(player):
			spawn_portal(player.global_position, Vector3.UP)
	else:
		%AudioKill.pitch_scale = pitch
		%AudioKill.play()


func try_spawn_portal_from_shot(
		hit_position: Vector3,
		hit_normal: Vector3) -> void:
	if not portal_placement_enabled or portal_spawned:
		return
	if hit_normal.dot(Vector3.UP) < 0.7:
		return

	spawn_portal(hit_position, hit_normal)


func spawn_portal(hit_position: Vector3, hit_normal: Vector3) -> void:
	portal_spawned = true
	portal_placement_enabled = false
	hide_hint()
	var portal = preload("res://entities/portal.tscn").instantiate()
	portal.portal_to = next_level
	var portal_global_transform := Transform3D(
		Basis.IDENTITY,
		hit_position + hit_normal * 0.02)
	portal.transform = global_transform.affine_inverse() * portal_global_transform
	add_child(portal)


func show_hint(message: String, duration: float = 2.0) -> void:
	hint_request_id += 1
	var request_id := hint_request_id
	%Hint.text = message
	%Hint.visible = not message.is_empty()
	if message.is_empty() or duration <= 0.0:
		return

	await get_tree().create_timer(duration).timeout
	if is_inside_tree() and request_id == hint_request_id:
		%Hint.hide()


func hide_hint() -> void:
	hint_request_id += 1
	%Hint.hide()


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
