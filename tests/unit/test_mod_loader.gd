extends GutTest
## Unit tests for ModLoader.
## Run with the GUT plugin from the Godot editor or via the GUT CLI.

var _loader: Node


func before_each() -> void:
	# Instantiate a fresh ModLoader for each test without triggering _ready().
	_loader = load("res://scripts/core/mod_loader.gd").new()
	# Suppress _ready() side-effects by adding without calling it automatically;
	# GUT does not call _ready() when using .new() directly on a script.
	add_child_autofree(_loader)


# ---------------------------------------------------------------------------
# test_scan_mods_returns_empty_when_no_mod_dir
# ---------------------------------------------------------------------------
func test_scan_mods_returns_empty_when_no_mod_dir() -> void:
	# user://mods/ does not exist in the headless test environment.
	# scan_mods() must return an empty array rather than crashing.
	var result = _loader.scan_mods()
	assert_is(result, Array, "scan_mods() should return an Array")
	assert_eq(result.size(), 0, "scan_mods() should return [] when MOD_DIR is absent")


# ---------------------------------------------------------------------------
# test_get_mod_data_returns_empty_dict_when_not_found
# ---------------------------------------------------------------------------
func test_get_mod_data_returns_empty_dict_when_not_found() -> void:
	var result = _loader.get_mod_data("races", "nonexistent_race")
	assert_is(result, Dictionary, "get_mod_data() should return a Dictionary")
	assert_eq(result.size(), 0, "get_mod_data() should return {} for unknown entries")


# ---------------------------------------------------------------------------
# test_loaded_mods_initially_empty
# ---------------------------------------------------------------------------
func test_loaded_mods_initially_empty() -> void:
	# A freshly created ModLoader (before load_all_mods runs) should have no mods.
	var mods = _loader.get_loaded_mods()
	assert_is(mods, Array, "get_loaded_mods() should return an Array")
	assert_eq(mods.size(), 0, "loaded_mods should be empty before any mods are loaded")


# ---------------------------------------------------------------------------
# test_load_mod_fails_gracefully_on_missing_path
# ---------------------------------------------------------------------------
func test_load_mod_fails_gracefully_on_missing_path() -> void:
	# Calling load_mod() with a name that has no corresponding directory must
	# return false and must not raise an error or crash.
	var result = _loader.load_mod("nonexistent_mod_xyzzy")
	assert_eq(result, false, "load_mod() should return false for a missing mod directory")


# ---------------------------------------------------------------------------
# test_mod_loaded_signal_not_emitted_on_failure
# ---------------------------------------------------------------------------
func test_mod_loaded_signal_not_emitted_on_failure() -> void:
	# When load_mod() fails, mod_loaded must NOT be emitted.
	# We watch the signal and verify it was never fired.
	watch_signals(_loader)
	_loader.load_mod("nonexistent_mod_xyzzy")
	assert_signal_not_emitted(_loader, "mod_loaded",
			"mod_loaded signal must not fire when the mod directory is missing")
