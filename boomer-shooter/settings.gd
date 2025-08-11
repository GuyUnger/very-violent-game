class_name Settings
extends Node

enum Difficulty {
	EASY,
	REGULAR,
	HARD,
}

static var difficulty: int = Difficulty.REGULAR
static var look_sensitivity: float = 1.0