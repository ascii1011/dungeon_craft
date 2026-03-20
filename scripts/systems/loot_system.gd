## LootSystem
## Rolls loot tables and spawns item pickups in the world.
## Reads enemy and chest loot table data, applies per-entry chance rolls,
## and emits EventBus signals for gold and XP rewards.
##
## Usage:
##   loot_system.roll_enemy_loot("goblin", enemy_position, get_tree().current_scene)
##   loot_system.roll_chest_loot("common_chest", chest_position, get_tree().current_scene)
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after any loot roll completes.
## source — the enemy_id or loot_table_id that was rolled.
## items  — Array of item_id Strings that were awarded (may be empty).
signal loot_rolled(source: String, items: Array)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const ITEM_PICKUP_SCENE := "res://scenes/entities/item_pickup.tscn"
const SPAWN_OFFSET_RANGE := 8.0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Roll loot for a defeated enemy and spawn pickups in the world.
## Loads enemy data via DataLoader, rolls gold and each loot table entry,
## then emits XP via EventBus.
func roll_enemy_loot(enemy_id: String, position: Vector2, world_node: Node) -> void:
	var enemy_data: Dictionary = DataLoader.load_enemy(enemy_id)
	if enemy_data.is_empty():
		push_warning("LootSystem.roll_enemy_loot: no data found for enemy '%s'" % enemy_id)
		loot_rolled.emit(enemy_id, [])
		return

	# --- Gold ---
	var awarded_items: Array = []
	var gold_data: Dictionary = enemy_data.get("gold_drop", {})
	if not gold_data.is_empty():
		var gold_min: int = int(gold_data.get("min", 0))
		var gold_max: int = int(gold_data.get("max", 0))
		if gold_max > 0:
			var gold_amount: int = randi_range(gold_min, gold_max)
			if gold_amount > 0:
				EventBus.gold_changed.emit(gold_amount)

	# --- Loot table entries ---
	var loot_table: Array = enemy_data.get("loot_table", [])
	for entry in loot_table:
		var item_id: String = entry.get("item_id", "")
		var chance: float = float(entry.get("chance", 0.0))
		if item_id.is_empty():
			continue
		if _roll_chance(chance):
			spawn_item_pickup(item_id, position, world_node)
			awarded_items.append(item_id)

	# --- XP ---
	var xp_reward: int = int(enemy_data.get("xp_reward", 0))
	if xp_reward > 0:
		EventBus.xp_gained.emit(xp_reward)

	loot_rolled.emit(enemy_id, awarded_items)


## Roll loot for a chest and spawn pickups in the world.
## Loads the loot table from `data/loot_tables/{loot_table_id}.json`.
func roll_chest_loot(loot_table_id: String, position: Vector2, world_node: Node) -> void:
	var path := "res://data/loot_tables/%s.json" % loot_table_id
	var table_data: Dictionary = _load_loot_table(path)
	if table_data.is_empty():
		push_warning("LootSystem.roll_chest_loot: could not load loot table '%s'" % loot_table_id)
		loot_rolled.emit(loot_table_id, [])
		return

	# --- Gold ---
	var awarded_items: Array = []
	var gold_data: Dictionary = table_data.get("gold", {})
	if not gold_data.is_empty():
		var gold_min: int = int(gold_data.get("min", 0))
		var gold_max: int = int(gold_data.get("max", 0))
		if gold_max > 0:
			var gold_amount: int = randi_range(gold_min, gold_max)
			if gold_amount > 0:
				EventBus.gold_changed.emit(gold_amount)

	# --- Item entries ---
	var items: Array = table_data.get("items", [])
	for entry in items:
		var item_id: String = entry.get("item_id", "")
		var chance: float = float(entry.get("chance", 0.0))
		if item_id.is_empty():
			continue
		if _roll_chance(chance):
			spawn_item_pickup(item_id, position, world_node)
			awarded_items.append(item_id)

	loot_rolled.emit(loot_table_id, awarded_items)


## Spawn a single item pickup in the world at position with a small random offset
## so stacked drops spread apart visually.
func spawn_item_pickup(item_id: String, position: Vector2, world_node: Node) -> void:
	var pickup_scene := load(ITEM_PICKUP_SCENE)
	if pickup_scene == null:
		push_error("LootSystem.spawn_item_pickup: could not load scene '%s'" % ITEM_PICKUP_SCENE)
		return

	var pickup: Node = pickup_scene.instantiate()
	pickup.item_id = item_id
	pickup.position = position + _random_offset()
	world_node.add_child(pickup)

# ---------------------------------------------------------------------------
# Testable helpers
# ---------------------------------------------------------------------------

## Returns true if a random roll beats the given chance threshold [0.0, 1.0].
## Separated into its own function so tests can assess probability logic
## without spawning nodes.
func _roll_chance(chance: float) -> bool:
	return randf() < chance


## Returns a random Vector2 offset in the range [-SPAWN_OFFSET_RANGE, +SPAWN_OFFSET_RANGE]
## on both axes.
func _random_offset() -> Vector2:
	var ox: float = randf_range(-SPAWN_OFFSET_RANGE, SPAWN_OFFSET_RANGE)
	var oy: float = randf_range(-SPAWN_OFFSET_RANGE, SPAWN_OFFSET_RANGE)
	return Vector2(ox, oy)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Load a loot table JSON file from an absolute resource path.
func _load_loot_table(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("LootSystem._load_loot_table: file not found — %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LootSystem._load_loot_table: failed to open file — %s" % path)
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		push_error("LootSystem._load_loot_table: JSON parse error in %s — %s" % [
			path, json.get_error_message()
		])
		return {}

	var result = json.get_data()
	if not result is Dictionary:
		push_error("LootSystem._load_loot_table: expected a Dictionary in %s" % path)
		return {}

	return result
