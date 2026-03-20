class_name DungeonManager
## DungeonManager
## Handles zone loading/unloading and entity spawning for dungeon floors.
## Reads zone data from DataLoader and populates the world with enemies and NPCs.
extends Node

signal zone_loaded(zone_id: String)
signal zone_unloaded(zone_id: String)

var current_zone_id: String = ""
var _zone_data: Dictionary = {}

## Load a zone by ID. Reads zone JSON, spawns entities into world_node,
## updates GameState, and emits zone_loaded.
func load_zone(zone_id: String, world_node: Node) -> void:
	_zone_data = DataLoader.load_zone(zone_id)
	current_zone_id = zone_id
	GameState.current_zone = zone_id
	_spawn_entities(world_node)
	EventBus.player_zone_changed.emit(zone_id)
	zone_loaded.emit(zone_id)

## Spawn enemies and NPCs into the provided world_node based on _zone_data.
func _spawn_entities(world_node: Node) -> void:
	var enemy_scene: PackedScene = load("res://scenes/entities/enemy.tscn")

	# Spawn enemies
	if _zone_data.has("enemy_spawns"):
		for spawn in _zone_data["enemy_spawns"]:
			var enemy_id: String = spawn.get("enemy_id", "")
			var pos_array: Array = spawn.get("position", [0, 0])
			var count: int = spawn.get("count", 1)
			var spawn_pos := Vector2(pos_array[0], pos_array[1])

			for i in range(count):
				var enemy: Node = enemy_scene.instantiate()
				enemy.initialize(enemy_id)
				# Offset each additional enemy slightly so they don't stack
				enemy.position = spawn_pos + Vector2(i * 16, 0)
				world_node.add_child(enemy)

	# Spawn NPCs — placeholder, entities will be wired up in a later pass
	if _zone_data.has("npc_spawns"):
		for spawn in _zone_data["npc_spawns"]:
			var npc_id: String = spawn.get("npc_id", "")
			var pos_array: Array = spawn.get("position", [0, 0])
			print("[DungeonManager] NPC spawn queued (not yet instantiated): %s at %s" % [
				npc_id,
				Vector2(pos_array[0], pos_array[1])
			])

## Returns the player spawn position defined in the current zone data.
## Returns Vector2.ZERO if zone data has not been loaded yet.
func get_player_spawn() -> Vector2:
	if not _zone_data.has("player_spawn"):
		return Vector2.ZERO
	var raw: Array = _zone_data["player_spawn"]
	return Vector2(raw[0], raw[1])

## Returns the full zone data dictionary for the currently loaded zone.
func get_zone_data() -> Dictionary:
	return _zone_data
