extends GutTest

var clock: Node


func before_each() -> void:
	clock = load("res://scripts/core/game_clock.gd").new()
	add_child_autofree(clock)


func test_initial_tick_is_zero() -> void:
	assert_eq(clock.tick, 0, "Initial tick should be 0")


func test_is_not_running_by_default() -> void:
	assert_false(clock.is_running, "GameClock should not be running by default")


func test_start_sets_running() -> void:
	clock.start()
	assert_true(clock.is_running, "is_running should be true after start()")


func test_stop_clears_running() -> void:
	clock.start()
	clock.stop()
	assert_false(clock.is_running, "is_running should be false after stop()")


func test_reset_zeroes_tick_and_time() -> void:
	clock.start()
	clock._physics_process(1.0 / 60.0)
	clock._physics_process(1.0 / 60.0)
	clock.reset()
	assert_eq(clock.tick, 0, "tick should be 0 after reset()")
	assert_eq(clock.game_time_seconds, 0.0, "game_time_seconds should be 0.0 after reset()")


func test_seconds_to_ticks_at_60hz() -> void:
	assert_eq(clock.seconds_to_ticks(1.0), 60, "seconds_to_ticks(1.0) should equal 60")


func test_ticks_to_seconds_at_60hz() -> void:
	assert_eq(clock.ticks_to_seconds(120), 2.0, "ticks_to_seconds(120) should equal 2.0")


func test_physics_process_increments_tick() -> void:
	clock.is_running = true
	clock._physics_process(1.0 / 60.0)
	assert_eq(clock.tick, 1, "tick should be 1 after one _physics_process call")
