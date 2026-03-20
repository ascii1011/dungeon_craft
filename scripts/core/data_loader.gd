## DataLoader
## Autoload singleton responsible for loading and caching JSON data files from
## the `res://data/` directory tree.  All load helpers follow the same pattern:
##   1. Build the full path for the requested id.
##   2. Delegate to _load_json() which handles caching and error reporting.
##   3. Return the parsed Dictionary, or {} on failure.
##
## The cache avoids repeated disk reads for the same file within one session.
## Call clear_cache() to force a fresh read (useful during hot-reload or tests).
extends Node

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## In-memory cache keyed by the full resource path string.
var _cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Public load helpers
# ---------------------------------------------------------------------------

## Load race definition from `res://data/races/{race_id}.json`.
func load_race(race_id: String) -> Dictionary:
	return _load_json("res://data/races/%s.json" % race_id)

## Load item definition from `res://data/items/{item_id}.json`.
func load_item(item_id: String) -> Dictionary:
	return _load_json("res://data/items/%s.json" % item_id)

## Load spell definition from `res://data/spells/{spell_id}.json`.
func load_spell(spell_id: String) -> Dictionary:
	return _load_json("res://data/spells/%s.json" % spell_id)

## Load enemy definition from `res://data/enemies/{enemy_id}.json`.
func load_enemy(enemy_id: String) -> Dictionary:
	return _load_json("res://data/enemies/%s.json" % enemy_id)

## Load zone definition from `res://data/zones/{zone_id}.json`.
func load_zone(zone_id: String) -> Dictionary:
	return _load_json("res://data/zones/%s.json" % zone_id)

## Load shop definition from `res://data/shops/{shop_id}.json`.
func load_shop(shop_id: String) -> Dictionary:
	return _load_json("res://data/shops/%s.json" % shop_id)

# ---------------------------------------------------------------------------
# Cache management
# ---------------------------------------------------------------------------

## Clear the in-memory cache. After calling this, the next load of any
## previously cached path will re-read from disk.
func clear_cache() -> void:
	_cache.clear()

## Inject mock item data directly into the cache (for unit/integration tests).
## The key matches the path DataLoader would normally build for load_item().
func set_mock_item(item_id: String, data: Dictionary) -> void:
	_cache["res://data/items/%s.json" % item_id] = data

## Remove a previously injected mock item from the cache.
func clear_mock_item(item_id: String) -> void:
	_cache.erase("res://data/items/%s.json" % item_id)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Read, parse, and cache a JSON file at the given resource path.
## Returns the parsed Dictionary on success, or {} on any failure.
## Errors are reported via push_error so they appear in the Godot console
## without crashing the game.
func _load_json(path: String) -> Dictionary:
	# Return cached data if available.
	if _cache.has(path):
		return _cache[path]

	# Verify the file exists before trying to open it.
	if not FileAccess.file_exists(path):
		push_error("DataLoader: file not found — %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: failed to open file — %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		push_error("DataLoader: JSON parse error in %s at line %d — %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return {}

	var result = json.get_data()
	if not result is Dictionary:
		push_error("DataLoader: expected a JSON object (Dictionary) in %s, got %s" % [
			path, typeof(result)
		])
		return {}

	# Store in cache before returning.
	_cache[path] = result
	return result
