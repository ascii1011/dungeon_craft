## test_data_loader.gd
## GUT unit tests for the DataLoader autoload singleton.
##
## Unit tests cannot rely on actual data files being present (the `data/`
## directory may not be populated during CI), so the tests focus on:
##   1. Cache behaviour — inject data manually and confirm it is returned.
##   2. Error handling  — requesting a non-existent file returns {} without
##      crashing.
##   3. clear_cache()   — verifies the cache is emptied correctly.
##   4. Public helper signatures — each helper builds the right path prefix.
extends GutTest

# ---------------------------------------------------------------------------
# Helpers / setup
# ---------------------------------------------------------------------------

var _dl  # Local DataLoader instance

func before_each() -> void:
	_dl = load("res://scripts/core/data_loader.gd").new()
	add_child_autofree(_dl)

func after_each() -> void:
	pass  # add_child_autofree handles teardown

# ---------------------------------------------------------------------------
# Internal cache tests
# (We bypass the file system by writing directly into _cache.)
# ---------------------------------------------------------------------------

func test_cache_hit_returns_cached_data() -> void:
	var fake_path := "res://data/items/test_sword.json"
	var fake_data := {"id": "test_sword", "damage": 15}
	_dl._cache[fake_path] = fake_data

	var result := _dl._load_json(fake_path)
	assert_eq(result, fake_data, "_load_json should return cached data without hitting disk")

func test_cache_is_populated_after_manual_insert() -> void:
	var fake_path := "res://data/items/test_bow.json"
	_dl._cache[fake_path] = {"id": "test_bow"}
	assert_true(_dl._cache.has(fake_path), "Cache should contain the inserted key")

func test_clear_cache_empties_cache() -> void:
	_dl._cache["res://data/items/dagger.json"] = {"id": "dagger"}
	_dl._cache["res://data/spells/fireball.json"] = {"id": "fireball"}
	_dl.clear_cache()
	assert_eq(_dl._cache.size(), 0, "clear_cache() should empty the internal cache")

func test_clear_cache_on_empty_cache_does_not_crash() -> void:
	_dl.clear_cache()
	_dl.clear_cache()  # second call — should be a no-op
	assert_true(true, "clear_cache() on an already-empty cache should not crash")

# ---------------------------------------------------------------------------
# File-not-found / error handling
# ---------------------------------------------------------------------------

func test_load_json_missing_file_returns_empty_dict() -> void:
	# Use a path that will never exist so we exercise the error branch.
	var result := _dl._load_json("res://data/items/__definitely_does_not_exist__.json")
	assert_eq(result, {}, "Missing file should return an empty dictionary")

func test_load_race_missing_returns_empty_dict() -> void:
	var result := _dl.load_race("__no_such_race__")
	assert_eq(result, {}, "load_race with unknown id should return {}")

func test_load_item_missing_returns_empty_dict() -> void:
	var result := _dl.load_item("__no_such_item__")
	assert_eq(result, {}, "load_item with unknown id should return {}")

func test_load_spell_missing_returns_empty_dict() -> void:
	var result := _dl.load_spell("__no_such_spell__")
	assert_eq(result, {}, "load_spell with unknown id should return {}")

func test_load_enemy_missing_returns_empty_dict() -> void:
	var result := _dl.load_enemy("__no_such_enemy__")
	assert_eq(result, {}, "load_enemy with unknown id should return {}")

func test_load_zone_missing_returns_empty_dict() -> void:
	var result := _dl.load_zone("__no_such_zone__")
	assert_eq(result, {}, "load_zone with unknown id should return {}")

func test_load_shop_missing_returns_empty_dict() -> void:
	var result := _dl.load_shop("__no_such_shop__")
	assert_eq(result, {}, "load_shop with unknown id should return {}")

# ---------------------------------------------------------------------------
# Path construction — verify helpers call _load_json with correct prefixes
# (done by pre-seeding the cache with the expected path key)
# ---------------------------------------------------------------------------

func test_load_race_uses_correct_path() -> void:
	var expected_path := "res://data/races/elf.json"
	_dl._cache[expected_path] = {"id": "elf"}
	var result := _dl.load_race("elf")
	assert_eq(result.get("id"), "elf", "load_race should resolve to res://data/races/{id}.json")

func test_load_item_uses_correct_path() -> void:
	var expected_path := "res://data/items/health_potion.json"
	_dl._cache[expected_path] = {"id": "health_potion"}
	var result := _dl.load_item("health_potion")
	assert_eq(result.get("id"), "health_potion", "load_item should resolve to res://data/items/{id}.json")

func test_load_spell_uses_correct_path() -> void:
	var expected_path := "res://data/spells/fireball.json"
	_dl._cache[expected_path] = {"id": "fireball"}
	var result := _dl.load_spell("fireball")
	assert_eq(result.get("id"), "fireball", "load_spell should resolve to res://data/spells/{id}.json")

func test_load_enemy_uses_correct_path() -> void:
	var expected_path := "res://data/enemies/goblin.json"
	_dl._cache[expected_path] = {"id": "goblin"}
	var result := _dl.load_enemy("goblin")
	assert_eq(result.get("id"), "goblin", "load_enemy should resolve to res://data/enemies/{id}.json")

func test_load_zone_uses_correct_path() -> void:
	var expected_path := "res://data/zones/catacombs.json"
	_dl._cache[expected_path] = {"id": "catacombs"}
	var result := _dl.load_zone("catacombs")
	assert_eq(result.get("id"), "catacombs", "load_zone should resolve to res://data/zones/{id}.json")

func test_load_shop_uses_correct_path() -> void:
	var expected_path := "res://data/shops/blacksmith.json"
	_dl._cache[expected_path] = {"id": "blacksmith"}
	var result := _dl.load_shop("blacksmith")
	assert_eq(result.get("id"), "blacksmith", "load_shop should resolve to res://data/shops/{id}.json")

# ---------------------------------------------------------------------------
# Cache population after a successful load (integration-flavoured unit test)
# (Pre-seeded in cache, simulates what a real file load would leave behind.)
# ---------------------------------------------------------------------------

func test_second_call_uses_cache_not_disk() -> void:
	var path := "res://data/items/staff.json"
	var expected := {"id": "staff", "magic": true}
	_dl._cache[path] = expected

	# Call twice — both should return the same object from cache.
	var first  := _dl._load_json(path)
	var second := _dl._load_json(path)
	assert_eq(first, expected,  "First call should return cached data")
	assert_eq(second, expected, "Second call should also return cached data")
