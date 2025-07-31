extends Node

var delta_sum_ := 0.0
var sources := {}
var loop_id := ""
var source_ids := 1 # source id 1 is reserved for main scene

class Loop extends  Resource:
	var events := []
	var play_back_cursor := 0

var loops:Array[Loop]

func next_source_id() -> int:
	source_ids += 1
	return source_ids

func new_loop() -> void:
	loops.push_back(Loop.new())
	
	for loop in loops:
		loop.play_back_cursor = 0
	
	delta_sum_ = 0.0
	
	sources.clear()
	
	loop_id = "_" + str(loops.size())

func register_source(source_id:int, object:Object) -> void:
	sources[source_id] = object


func push_event(event:EventStoreCommand) -> void:
	loops.back().events.push_back(event)


func replay_event(event:EventStoreCommand) -> void:
	event.replay()


func _ready() -> void:
	new_loop()

func _physics_process(delta: float) -> void:
	delta_sum_ += delta
	
	for i in range(0, loops.size() - 1):
		var loop := loops[i]
		
		while loop.play_back_cursor < loop.events.size() and loop.events[loop.play_back_cursor].time <= delta_sum_:
			replay_event(loop.events[loop.play_back_cursor])
			loop.play_back_cursor += 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
		new_loop()
