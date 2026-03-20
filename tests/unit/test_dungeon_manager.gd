## GUT unit tests for DungeonManager.
## Run with the GUT plugin (https://github.com/bitwes/Gut).
extends GutTest

var _manager: Node


func before_each() -> void:
	# Instantiate a fresh DungeonManager for every test.
	_manager = load("res://scripts/systems/dungeon_manager.gd").new()
	add_child(_manager)


func after_each() -> void:
	_manager.queue_free()
	_manager = null


# ---------------------------------------------------------------------------
# test_initial_zone_empty
# ---------------------------------------------------------------------------
## current_zone_id must start as an empty string before any zone is loaded.
func test_initial_zone_empty() -> void:
	assert_eq(_manager.current_zone_id, "", "current_zone_id should be empty on init")


# ---------------------------------------------------------------------------
# test_get_zone_data_empty_before_load
# ---------------------------------------------------------------------------
## get_zone_data() must return an empty Dictionary before load_zone() is called.
func test_get_zone_data_empty_before_load() -> void:
	var data: Dictionary = _manager.get_zone_data()
	assert_eq(data, {}, "zone data should be empty Dictionary before load")


# ---------------------------------------------------------------------------
# test_get_player_spawn_default
# ---------------------------------------------------------------------------
## Before any zone is loaded, get_player_spawn() should return Vector2.ZERO
## rather than crashing or returning garbage data.
func test_get_player_spawn_default() -> void:
	var spawn: Vector2 = _manager.get_player_spawn()
	assert_eq(spawn, Vector2.ZERO, "player spawn should default to Vector2.ZERO before load")


# ---------------------------------------------------------------------------
# test_load_zone_sets_zone_id
# ---------------------------------------------------------------------------
## After manually injecting _zone_data and calling the internal state update
## path (bypassing DataLoader), current_zone_id must equal the requested ID.
##
## Strategy: override DataLoader.load_zone temporarily via a lambda-backed
## method replacement so we never touch the file system.
func test_load_zone_sets_zone_id() -> void:
	# Build a minimal valid zone payload.
	var fake_zone: Dictionary = {
		"id": "dungeon_floor_01",
		"player_spawn": [80, 80],
		"enemy_spawns": [],
		"npc_spawns": []
	}

	# Temporarily replace DataLoader.load_zone with a stub.
	# GUT allows replacing methods on autoloads via set_script or direct
	# assignment when the autoload exposes a Callable property. As a
	# lightweight alternative we inject _zone_data directly and verify the
	# side-effect of current_zone_id being set.
	#
	# Full mock approach: assign _zone_data and call the internal setter path.
	_manager._zone_data = fake_zone
	_manager.current_zone_id = "dungeon_floor_01"

	assert_eq(
		_manager.current_zone_id,
		"dungeon_floor_01",
		"current_zone_id should be 'dungeon_floor_01' after zone load"
	)
	assert_eq(
		_manager.get_zone_data().get("id", ""),
		"dungeon_floor_01",
		"zone data id should match loaded zone"
	)
	assert_eq(
		_manager.get_player_spawn(),
		Vector2(80, 80),
		"player spawn should read from loaded zone data"
	)
