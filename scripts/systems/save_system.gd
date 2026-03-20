class_name SaveSystem
## SaveSystem
## Handles serializing and writing full game state (player + GameState) to disk
## as a versioned JSON file. Add this node to the main scene manually.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal game_saved()
signal game_loaded()
signal save_failed(reason: String)
signal load_failed(reason: String)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Serialize the player and global GameState then write to SAVE_PATH.
## Returns true on success, false on any error.
func save_game(player: Node) -> bool:
	var save_dict: Dictionary = _get_save_dict_from_player(player)

	var json_string: String = JSON.stringify(save_dict, "\t")

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var reason: String = "Cannot open '%s' for writing (error %d)" % [
			SAVE_PATH, FileAccess.get_open_error()
		]
		push_error("SaveSystem.save_game: " + reason)
		save_failed.emit(reason)
		return false

	file.store_string(json_string)
	file.close()

	game_saved.emit()
	return true


## Read the JSON save file, validate it, and restore all state.
## Returns true on success, false on any error.
func load_game(player: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		var reason: String = "Save file not found at '%s'" % SAVE_PATH
		push_error("SaveSystem.load_game: " + reason)
		load_failed.emit(reason)
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var reason: String = "Cannot open '%s' for reading (error %d)" % [
			SAVE_PATH, FileAccess.get_open_error()
		]
		push_error("SaveSystem.load_game: " + reason)
		load_failed.emit(reason)
		return false

	var raw: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(raw)
	if parse_error != OK:
		var reason: String = "JSON parse error at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		]
		push_error("SaveSystem.load_game: " + reason)
		load_failed.emit(reason)
		return false

	var data: Dictionary = json.data
	if not data is Dictionary:
		var reason: String = "Save file root is not a Dictionary"
		push_error("SaveSystem.load_game: " + reason)
		load_failed.emit(reason)
		return false

	# Version check.
	if data.get("version", -1) != SAVE_VERSION:
		var reason: String = "Unsupported save version %s (expected %d)" % [
			str(data.get("version", "missing")), SAVE_VERSION
		]
		push_error("SaveSystem.load_game: " + reason)
		load_failed.emit(reason)
		return false

	# Restore global game state.
	if data.has("game_state"):
		GameState.load_state(data["game_state"])

	# Restore player components.
	if data.has("player"):
		_restore_player(player, data["player"])

	game_loaded.emit()
	return true


## Returns true when a save file exists at SAVE_PATH.
func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file. Does nothing if it does not exist.
func delete_save() -> void:
	DirAccess.remove_absolute(SAVE_PATH)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Build and return the full save dictionary for player.
## Extracted so tests can call this without touching the filesystem.
func _get_save_dict_from_player(player: Node) -> Dictionary:
	var hp_comp: HealthComponent = _find_child_of_type(player, "HealthComponent")
	var sb_comp: SpellbookComponent = _find_child_of_type(player, "SpellbookComponent")
	var stats_comp: StatsComponent = _find_child_of_type(player, "StatsComponent")
	var inv_comp: InventoryComponent = _find_child_of_type(player, "InventoryComponent")

	# Base stats dict — serialise only the four base values.
	var base_stats: Dictionary = {}
	if stats_comp != null:
		base_stats = {
			"strength": stats_comp.strength,
			"dexterity": stats_comp.dexterity,
			"intelligence": stats_comp.intelligence,
			"vitality": stats_comp.vitality,
		}

	var player_dict: Dictionary = {
		"race_id": player.get("race_id") if player.get("race_id") != null else "",
		"position": {
			"x": player.position.x,
			"y": player.position.y,
		},
		"health": {
			"current": hp_comp.current_hp if hp_comp != null else 0,
			"max": hp_comp.max_hp if hp_comp != null else 0,
		},
		"mana": {
			"current": sb_comp.current_mana if sb_comp != null else 0,
			"max": sb_comp.max_mana if sb_comp != null else 0,
		},
		"stats": base_stats,
		"inventory": inv_comp.get_all_items() if inv_comp != null else [],
		"equipment": inv_comp._equipment.duplicate() if inv_comp != null else {},
		"known_spells": Array(sb_comp._known_spells) if sb_comp != null else [],
		"gold": GameState.player_data.get("gold", 0),
		"xp": GameState.player_data.get("xp", 0),
	}

	return {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"game_state": GameState.save_state(),
		"player": player_dict,
	}


## Restore all player components from the saved player sub-dictionary.
func _restore_player(player: Node, pdata: Dictionary) -> void:
	# Position
	var pos_data = pdata.get("position", null)
	if pos_data is Dictionary:
		player.position = Vector2(
			float(pos_data.get("x", 0.0)),
			float(pos_data.get("y", 0.0))
		)

	# race_id property (if the player node exposes it)
	if pdata.has("race_id") and player.get("race_id") != null:
		player.set("race_id", pdata["race_id"])

	# HealthComponent
	var hp_comp: HealthComponent = _find_child_of_type(player, "HealthComponent")
	if hp_comp != null:
		var hdata: Dictionary = pdata.get("health", {})
		hp_comp.max_hp = int(hdata.get("max", hp_comp.max_hp))
		hp_comp.current_hp = int(hdata.get("current", hp_comp.current_hp))

	# SpellbookComponent
	var sb_comp: SpellbookComponent = _find_child_of_type(player, "SpellbookComponent")
	if sb_comp != null:
		var mdata: Dictionary = pdata.get("mana", {})
		sb_comp.max_mana = int(mdata.get("max", sb_comp.max_mana))
		sb_comp.current_mana = int(mdata.get("current", sb_comp.current_mana))
		# Restore known spells.
		var known: Array = pdata.get("known_spells", [])
		sb_comp._known_spells.clear()
		for spell_id in known:
			sb_comp._known_spells.append(str(spell_id))

	# StatsComponent
	var stats_comp: StatsComponent = _find_child_of_type(player, "StatsComponent")
	if stats_comp != null:
		var sdata: Dictionary = pdata.get("stats", {})
		if sdata.has("strength"):
			stats_comp.strength = int(sdata["strength"])
		if sdata.has("dexterity"):
			stats_comp.dexterity = int(sdata["dexterity"])
		if sdata.has("intelligence"):
			stats_comp.intelligence = int(sdata["intelligence"])
		if sdata.has("vitality"):
			stats_comp.vitality = int(sdata["vitality"])

	# InventoryComponent
	var inv_comp: InventoryComponent = _find_child_of_type(player, "InventoryComponent")
	if inv_comp != null:
		inv_comp.clear()
		var items: Array = pdata.get("inventory", [])
		for entry in items:
			if entry is Dictionary:
				inv_comp._items.append(entry.duplicate())
		var equip: Dictionary = pdata.get("equipment", {})
		for slot in equip:
			if inv_comp._equipment.has(slot):
				inv_comp._equipment[slot] = str(equip[slot])

	# Gold / XP back into GameState.player_data
	if pdata.has("gold"):
		GameState.player_data["gold"] = int(pdata["gold"])
	if pdata.has("xp"):
		GameState.player_data["xp"] = int(pdata["xp"])


## Walk direct children of node looking for one whose class_name matches type_name.
## Returns null when not found.
func _find_child_of_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.get_class() == type_name or child.is_class(type_name):
			return child
	return null
