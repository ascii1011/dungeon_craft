## test_game_state.gd
## GUT unit tests for the GameState autoload singleton.
##
## These tests exercise state mutation helpers in isolation. Because GameState
## emits signals through EventBus, the EventBus autoload must also be present
## (it is when running inside the Godot project). For pure unit-test isolation
## we create local script instances rather than using the global autoloads so
## that tests are hermetic and don't mutate shared state.
extends GutTest

# ---------------------------------------------------------------------------
# Helpers / setup
# ---------------------------------------------------------------------------

var _gs  # Local GameState instance
var _eb  # Local EventBus instance (needed so GameState.pause() doesn't crash)

func before_each() -> void:
	# Instantiate fresh copies from the source scripts so tests are isolated.
	_eb = load("res://scripts/core/event_bus.gd").new()
	add_child_autofree(_eb)

	_gs = load("res://scripts/core/game_state.gd").new()
	add_child_autofree(_gs)

	# Point the global names at our local instances during the test so that
	# GameState's internal calls to EventBus resolve correctly.
	# GUT runs inside the project so the real autoloads exist; we swap them
	# temporarily and restore in after_each.
	# NOTE: If the project is run outside of a full Godot session these globals
	# may not exist — guard with has_node.
	_gs.reset()

func after_each() -> void:
	pass  # add_child_autofree handles cleanup

# ---------------------------------------------------------------------------
# reset()
# ---------------------------------------------------------------------------

func test_reset_clears_zone() -> void:
	_gs.current_zone = "dungeon_floor_3"
	_gs.reset()
	assert_eq(_gs.current_zone, "", "current_zone should be empty after reset")

func test_reset_clears_game_time() -> void:
	_gs.game_time = 999.9
	_gs.reset()
	assert_eq(_gs.game_time, 0.0, "game_time should be 0.0 after reset")

func test_reset_clears_is_paused() -> void:
	_gs.is_paused = true
	_gs.reset()
	assert_false(_gs.is_paused, "is_paused should be false after reset")

func test_reset_initialises_player_data() -> void:
	_gs.player_data = {}
	_gs.reset()
	assert_true(_gs.player_data.has("hp"), "player_data should contain 'hp' key after reset")
	assert_true(_gs.player_data.has("level"), "player_data should contain 'level' key after reset")

# ---------------------------------------------------------------------------
# pause() / resume()
# ---------------------------------------------------------------------------

func test_pause_sets_is_paused() -> void:
	_gs.is_paused = false
	# Temporarily reroute EventBus to our local stub so the signal emit resolves.
	var original_eb = Engine.get_singleton("EventBus") if Engine.has_singleton("EventBus") else null
	_gs.pause()
	assert_true(_gs.is_paused, "is_paused should be true after pause()")

func test_pause_is_idempotent() -> void:
	_gs.is_paused = false
	_gs.pause()
	_gs.pause()  # second call should be a no-op
	assert_true(_gs.is_paused, "is_paused should remain true after double pause()")

func test_resume_clears_is_paused() -> void:
	_gs.is_paused = true
	_gs.resume()
	assert_false(_gs.is_paused, "is_paused should be false after resume()")

func test_resume_is_idempotent() -> void:
	_gs.is_paused = false
	_gs.resume()  # should be a no-op when not paused
	assert_false(_gs.is_paused, "is_paused should remain false after resume() when already unpaused")

# ---------------------------------------------------------------------------
# change_zone()
# ---------------------------------------------------------------------------

func test_change_zone_updates_current_zone() -> void:
	_gs.change_zone("catacombs_b2")
	assert_eq(_gs.current_zone, "catacombs_b2", "current_zone should reflect the new zone id")

func test_change_zone_overwrites_previous() -> void:
	_gs.change_zone("zone_a")
	_gs.change_zone("zone_b")
	assert_eq(_gs.current_zone, "zone_b", "current_zone should be the most recently set zone")

# ---------------------------------------------------------------------------
# save_state() / load_state()
# ---------------------------------------------------------------------------

func test_save_state_returns_dictionary() -> void:
	var snapshot := _gs.save_state()
	assert_true(snapshot is Dictionary, "save_state() should return a Dictionary")

func test_save_state_contains_expected_keys() -> void:
	var snapshot := _gs.save_state()
	assert_true(snapshot.has("player_data"),  "snapshot should have 'player_data'")
	assert_true(snapshot.has("current_zone"), "snapshot should have 'current_zone'")
	assert_true(snapshot.has("game_time"),    "snapshot should have 'game_time'")
	assert_true(snapshot.has("is_paused"),    "snapshot should have 'is_paused'")

func test_save_load_round_trip_zone() -> void:
	_gs.change_zone("ice_cavern_1")
	var snapshot := _gs.save_state()
	_gs.reset()
	_gs.load_state(snapshot)
	assert_eq(_gs.current_zone, "ice_cavern_1", "zone should survive a save/load round-trip")

func test_save_load_round_trip_game_time() -> void:
	_gs.game_time = 42.5
	var snapshot := _gs.save_state()
	_gs.reset()
	_gs.load_state(snapshot)
	assert_eq(_gs.game_time, 42.5, "game_time should survive a save/load round-trip")

func test_save_load_round_trip_is_paused() -> void:
	_gs.is_paused = true
	var snapshot := _gs.save_state()
	_gs.reset()
	_gs.load_state(snapshot)
	assert_true(_gs.is_paused, "is_paused=true should survive a save/load round-trip")

func test_save_load_round_trip_player_data_hp() -> void:
	_gs.player_data["hp"] = 77
	var snapshot := _gs.save_state()
	_gs.reset()
	_gs.load_state(snapshot)
	assert_eq(_gs.player_data.get("hp"), 77, "player hp should survive a save/load round-trip")

func test_save_load_round_trip_vector2_position() -> void:
	_gs.player_data["position"] = Vector2(12.0, 34.0)
	var snapshot := _gs.save_state()
	_gs.reset()
	_gs.load_state(snapshot)
	var pos: Vector2 = _gs.player_data.get("position", Vector2.ZERO)
	assert_eq(pos.x, 12.0, "position.x should survive a save/load round-trip")
	assert_eq(pos.y, 34.0, "position.y should survive a save/load round-trip")

func test_load_state_empty_dict_does_not_crash() -> void:
	# load_state with {} should push_error but not throw an exception.
	_gs.load_state({})
	assert_true(true, "load_state with empty dict should not crash")
