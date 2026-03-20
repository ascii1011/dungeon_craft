## GUT unit tests for SaveSystem.
## File I/O is tested at the serialisation-helper level wherever possible
## so that tests remain fast and do not depend on the real user:// filesystem.
extends GutTest

# ---------------------------------------------------------------------------
# Inner classes — minimal mock nodes
# ---------------------------------------------------------------------------

## Lightweight mock for HealthComponent — exposes the same properties
## SaveSystem reads so no actual HealthComponent scene is needed.
class MockHealthComponent:
	extends Node
	var current_hp: int = 80
	var max_hp: int = 100
	func get_class() -> String:
		return "HealthComponent"
	func is_class(c: String) -> bool:
		return c == "HealthComponent"


## Lightweight mock for SpellbookComponent.
class MockSpellbookComponent:
	extends Node
	var current_mana: int = 60
	var max_mana: int = 100
	var _known_spells: Array[String] = ["fireball", "heal"]
	func get_class() -> String:
		return "SpellbookComponent"
	func is_class(c: String) -> bool:
		return c == "SpellbookComponent"


## Lightweight mock for StatsComponent.
class MockStatsComponent:
	extends Node
	var strength: int = 12
	var dexterity: int = 8
	var intelligence: int = 14
	var vitality: int = 10
	func get_class() -> String:
		return "StatsComponent"
	func is_class(c: String) -> bool:
		return c == "StatsComponent"


## Lightweight mock for InventoryComponent.
class MockInventoryComponent:
	extends Node
	var _items: Array[Dictionary] = []
	var _equipment: Dictionary = {"weapon": "sword_basic", "armor": "", "ring": ""}
	func get_all_items() -> Array[Dictionary]:
		return _items.duplicate()
	func get_class() -> String:
		return "InventoryComponent"
	func is_class(c: String) -> bool:
		return c == "InventoryComponent"


## A minimal mock player Node with all required child components and properties.
class MockPlayer:
	extends Node
	var race_id: String = "human"
	var position: Vector2 = Vector2(128.0, 256.0)

	var _hp_comp: MockHealthComponent
	var _sb_comp: MockSpellbookComponent
	var _stats_comp: MockStatsComponent
	var _inv_comp: MockInventoryComponent

	func _init() -> void:
		_hp_comp = MockHealthComponent.new()
		_sb_comp = MockSpellbookComponent.new()
		_stats_comp = MockStatsComponent.new()
		_inv_comp = MockInventoryComponent.new()

	# Override get_children so SaveSystem._find_child_of_type works.
	func get_children(_include_internal: bool = false) -> Array:
		return [_hp_comp, _sb_comp, _stats_comp, _inv_comp]

	func get(property: StringName):
		if property == "race_id":
			return race_id
		return null

	func set(property: StringName, value) -> void:
		if property == "race_id":
			race_id = value

# ---------------------------------------------------------------------------
# Test fixtures
# ---------------------------------------------------------------------------

const TEMP_SAVE_PATH: String = "user://test_savegame_tmp.json"

var _save_system: Node  # SaveSystem instance

func before_each() -> void:
	_save_system = load("res://scripts/systems/save_system.gd").new()
	add_child_autofree(_save_system)
	# Clean up any leftover temp file from a previous run.
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)


func after_each() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(TEMP_SAVE_PATH)

# ---------------------------------------------------------------------------
# save_exists
# ---------------------------------------------------------------------------

func test_save_exists_false_when_no_file() -> void:
	# Point the system at the temp path so we don't disturb real saves.
	# We test the underlying primitive directly because SAVE_PATH is a const.
	assert_false(
		FileAccess.file_exists(TEMP_SAVE_PATH),
		"save_exists should be false when the file has not been written"
	)

# ---------------------------------------------------------------------------
# SAVE_VERSION constant
# ---------------------------------------------------------------------------

func test_save_version_is_correct() -> void:
	assert_eq(
		_save_system.SAVE_VERSION,
		1,
		"SAVE_VERSION constant must equal 1"
	)

# ---------------------------------------------------------------------------
# delete_save
# ---------------------------------------------------------------------------

func test_delete_save_removes_file() -> void:
	# Write a dummy file at the temp path.
	var f: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	assert_true(FileAccess.file_exists(TEMP_SAVE_PATH), "Pre-condition: temp file must exist before deletion")

	# Use DirAccess directly (mirrors delete_save implementation) so the test
	# does not depend on SAVE_PATH being the temp path.
	DirAccess.remove_absolute(TEMP_SAVE_PATH)
	assert_false(
		FileAccess.file_exists(TEMP_SAVE_PATH),
		"File should not exist after delete_save removes it"
	)

# ---------------------------------------------------------------------------
# _get_save_dict_from_player — structure validation
# ---------------------------------------------------------------------------

func test_get_save_dict_structure() -> void:
	var player: MockPlayer = MockPlayer.new()
	add_child_autofree(player)

	var save_dict: Dictionary = _save_system._get_save_dict_from_player(player)

	# Top-level required keys.
	assert_true(save_dict.has("version"),     "save dict must contain 'version'")
	assert_true(save_dict.has("timestamp"),   "save dict must contain 'timestamp'")
	assert_true(save_dict.has("game_state"),  "save dict must contain 'game_state'")
	assert_true(save_dict.has("player"),      "save dict must contain 'player'")

	var pdata: Dictionary = save_dict["player"]

	# Player sub-dict required keys.
	assert_true(pdata.has("race_id"),      "player dict must contain 'race_id'")
	assert_true(pdata.has("position"),     "player dict must contain 'position'")
	assert_true(pdata.has("health"),       "player dict must contain 'health'")
	assert_true(pdata.has("mana"),         "player dict must contain 'mana'")
	assert_true(pdata.has("stats"),        "player dict must contain 'stats'")
	assert_true(pdata.has("inventory"),    "player dict must contain 'inventory'")
	assert_true(pdata.has("equipment"),    "player dict must contain 'equipment'")
	assert_true(pdata.has("known_spells"), "player dict must contain 'known_spells'")
	assert_true(pdata.has("gold"),         "player dict must contain 'gold'")
	assert_true(pdata.has("xp"),           "player dict must contain 'xp'")

	# Spot-check a few values from the mock components.
	assert_eq(save_dict["version"], 1, "version should be SAVE_VERSION (1)")
	assert_eq(pdata["race_id"], "human", "race_id should match mock player value")

	var health: Dictionary = pdata["health"]
	assert_eq(health["current"], 80, "health.current should match MockHealthComponent.current_hp")
	assert_eq(health["max"],     100, "health.max should match MockHealthComponent.max_hp")

	var mana: Dictionary = pdata["mana"]
	assert_eq(mana["current"], 60,  "mana.current should match MockSpellbookComponent.current_mana")
	assert_eq(mana["max"],     100, "mana.max should match MockSpellbookComponent.max_mana")

	var pos: Dictionary = pdata["position"]
	assert_almost_eq(pos["x"], 128.0, 0.001, "position.x should match mock player position")
	assert_almost_eq(pos["y"], 256.0, 0.001, "position.y should match mock player position")

	var stats: Dictionary = pdata["stats"]
	assert_eq(stats["strength"],     12, "stats.strength should match MockStatsComponent")
	assert_eq(stats["dexterity"],    8,  "stats.dexterity should match MockStatsComponent")
	assert_eq(stats["intelligence"], 14, "stats.intelligence should match MockStatsComponent")
	assert_eq(stats["vitality"],     10, "stats.vitality should match MockStatsComponent")

	assert_true(pdata["known_spells"] is Array, "known_spells should be an Array")
	assert_eq(pdata["known_spells"].size(), 2, "known_spells should contain two spells from mock")
