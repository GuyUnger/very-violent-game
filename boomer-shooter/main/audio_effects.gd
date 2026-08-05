extends Node

const MASTER_BUS := &"Master"
const LOW_PASS_DISABLED_CUTOFF := 16000.0

var master_bus_index: int
var master_low_pass_effect_index: int
var master_low_pass: AudioEffectLowPassFilter
var low_pass: float = LOW_PASS_DISABLED_CUTOFF:
	set = set_low_pass


func _ready() -> void:
	master_bus_index = AudioServer.get_bus_index(MASTER_BUS)

	for effect_index in AudioServer.get_bus_effect_count(master_bus_index):
		var effect := AudioServer.get_bus_effect(master_bus_index, effect_index)
		if effect is AudioEffectLowPassFilter:
			master_low_pass_effect_index = effect_index
			master_low_pass = effect
			break


func set_low_pass(value: float) -> void:
	low_pass = value
	master_low_pass.cutoff_hz = value
	var should_be_enabled := value < LOW_PASS_DISABLED_CUTOFF
	var is_enabled := AudioServer.is_bus_effect_enabled(
		master_bus_index,
		master_low_pass_effect_index
	)
	if is_enabled != should_be_enabled:
		AudioServer.set_bus_effect_enabled(
			master_bus_index,
			master_low_pass_effect_index,
			should_be_enabled
		)
