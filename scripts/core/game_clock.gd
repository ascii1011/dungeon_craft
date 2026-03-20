extends Node

signal tick_updated(tick: int)

var tick: int = 0
var tick_rate: int = 60
var game_time_seconds: float = 0.0
var is_running: bool = false

# Tracks accumulated ticks since last tick_updated emission
var _ticks_since_last_signal: int = 0


func start() -> void:
	is_running = true


func stop() -> void:
	is_running = false


func reset() -> void:
	tick = 0
	game_time_seconds = 0.0
	_ticks_since_last_signal = 0


func _physics_process(delta: float) -> void:
	if not is_running:
		return

	tick += 1
	game_time_seconds += delta
	_ticks_since_last_signal += 1

	if _ticks_since_last_signal >= tick_rate:
		_ticks_since_last_signal = 0
		tick_updated.emit(tick)


func get_tick() -> int:
	return tick


func seconds_to_ticks(seconds: float) -> int:
	return int(seconds * tick_rate)


func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / float(tick_rate)
