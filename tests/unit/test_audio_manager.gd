## Unit tests for AudioManager
## Uses the GUT framework (https://github.com/bitwes/Gut).
##
## Audio asset files do not exist during this test pass — every test that
## touches file loading relies on the graceful missing-file path
## (push_warning + early return) rather than real assets.

extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _audio_manager: Node

func before_each() -> void:
	# Load the script directly so tests are isolated from the autoload.
	var script: GDScript = load("res://scripts/core/audio_manager.gd")
	_audio_manager = script.new()
	# _ready is called automatically when added to the scene tree.
	add_child_autofree(_audio_manager)


# ---------------------------------------------------------------------------
# SOUND_MAP
# ---------------------------------------------------------------------------

func test_sound_map_has_expected_keys() -> void:
	var expected_keys := [
		"player_attack",
		"player_hurt",
		"player_died",
		"enemy_died",
		"item_pickup",
		"spell_cast",
		"gold_pickup",
		"chest_open",
		"shop_open",
		"ui_click",
		"music_dungeon_01",
		"music_menu",
	]
	assert_eq(
		_audio_manager.SOUND_MAP.size(),
		expected_keys.size(),
		"SOUND_MAP should have exactly %d keys" % expected_keys.size()
	)
	for key in expected_keys:
		assert_true(
			_audio_manager.SOUND_MAP.has(key),
			"SOUND_MAP should contain key: %s" % key
		)

# ---------------------------------------------------------------------------
# Missing-file safety
# ---------------------------------------------------------------------------

func test_play_sfx_missing_file_does_not_crash() -> void:
	# Should push_warning and return without throwing an error.
	_audio_manager.play_sfx("res://nonexistent.ogg")
	# If we reach this line, no crash occurred.
	assert_true(true, "play_sfx with missing file should not crash")


func test_play_music_missing_file_does_not_crash() -> void:
	_audio_manager.play_music("res://nonexistent.ogg", false)
	assert_true(true, "play_music with missing file should not crash")

# ---------------------------------------------------------------------------
# Volume setters
# ---------------------------------------------------------------------------

func test_set_music_volume_stores_value() -> void:
	_audio_manager.set_music_volume(-20.0)
	assert_eq(_audio_manager.music_volume_db, -20.0, "music_volume_db should be updated")


func test_set_sfx_volume_stores_value() -> void:
	_audio_manager.set_sfx_volume(-5.0)
	assert_eq(_audio_manager.sfx_volume_db, -5.0, "sfx_volume_db should be updated")

# ---------------------------------------------------------------------------
# SFX pool
# ---------------------------------------------------------------------------

func test_sfx_pool_has_eight_players() -> void:
	assert_eq(_audio_manager._sfx_pool.size(), 8, "SFX pool should contain 8 AudioStreamPlayers")
