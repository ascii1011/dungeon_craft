class_name DungeonManager
## DungeonManager
## Drives DungeonRenderer (generation + visuals), then spawns enemies, NPCs,
## chests, and exit sensors. Entity positions come from the generated room
## centers so everything lands on valid floor tiles.
extends Node

signal zone_loaded(zone_id: String)
signal zone_unloaded(zone_id: String)
signal zone_exit_reached(target_zone: String)

const ZONE_WIDTH:  int = 55
const ZONE_HEIGHT: int = 42

var current_zone_id: String = ""
var _zone_data: Dictionary = {}
var _room_centers: Array[Vector2] = []
var _spawn_pos: Vector2 = Vector2(80, 80)
var _exit_pos: Vector2  = Vector2(720, 480)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func load_zone(zone_id: String, world_node: Node) -> void:
	_zone_data = DataLoader.load_zone(zone_id)
	current_zone_id = zone_id
	GameState.current_zone = zone_id

	# Generate + render the dungeon, then use its room centers.
	var renderer = world_node.get_node_or_null("DungeonRenderer")
	if renderer != null:
		renderer.generate(ZONE_WIDTH, ZONE_HEIGHT)
		_room_centers = renderer.get_room_centers()
		_spawn_pos    = renderer.get_spawn_position()
		_exit_pos     = renderer.get_exit_position()

	_spawn_entities(world_node)
	_spawn_exit_sensor(world_node)

	EventBus.player_zone_changed.emit(zone_id)
	zone_loaded.emit(zone_id)


func get_player_spawn() -> Vector2:
	return _spawn_pos


func get_spawn_position() -> Vector2:
	return _spawn_pos


func get_zone_data() -> Dictionary:
	return _zone_data

# ---------------------------------------------------------------------------
# Entity spawning
# ---------------------------------------------------------------------------

## Distribute enemies, NPCs, and chests across the generated room centers.
## rooms[0] = player spawn (kept empty of enemies).
## rooms[1..n-2] = content rooms.
## rooms[n-1] = boss / exit room.
func _spawn_entities(world_node: Node) -> void:
	var enemy_scene: PackedScene = load("res://scenes/entities/enemy.tscn")
	var npc_scene:   PackedScene = load("res://scenes/entities/npc.tscn")
	var chest_scene: PackedScene = load("res://scenes/entities/chest.tscn")

	var entities_node: Node = world_node.get_node_or_null("Entities")
	if entities_node == null:
		entities_node = world_node

	# Build an ordered list of "content slot" positions:
	# all room centers except the first (player spawn).
	var slots: Array[Vector2] = []
	for i in range(1, _room_centers.size()):
		slots.append(_room_centers[i])

	# Fallback if no room data: use hardcoded zone positions.
	var use_generated: bool = slots.size() > 0

	var slot_idx: int = 0

	# ---- Enemies ----
	if _zone_data.has("enemy_spawns"):
		for spawn in _zone_data["enemy_spawns"]:
			var enemy_id: String  = spawn.get("enemy_id", "")
			var count: int        = spawn.get("count", 1)

			var base_pos: Vector2
			if use_generated and slot_idx < slots.size():
				base_pos = slots[slot_idx]
				slot_idx += 1
			else:
				var pa: Array = spawn.get("position", [0, 0])
				base_pos = Vector2(pa[0], pa[1])

			for i in range(count):
				var enemy: Node = enemy_scene.instantiate()
				# Scatter multiple enemies around the slot center.
				var offset := Vector2(i * 24 - (count - 1) * 12, 0)
				enemy.position = base_pos + offset
				entities_node.add_child(enemy)
				enemy.initialize(enemy_id)

	# ---- NPCs ----
	if _zone_data.has("npc_spawns") and npc_scene != null:
		for spawn in _zone_data["npc_spawns"]:
			var npc_id: String = spawn.get("npc_id", "")

			var pos: Vector2
			if use_generated and slot_idx < slots.size():
				pos = slots[slot_idx]
				slot_idx += 1
			else:
				var pa: Array = spawn.get("position", [0, 0])
				pos = Vector2(pa[0], pa[1])

			var npc: Node = npc_scene.instantiate()
			npc.npc_id      = npc_id
			npc.dialogue_id = spawn.get("dialogue_id", npc_id)
			npc.shop_id     = spawn.get("shop_id", npc_id)
			npc.position    = pos
			entities_node.add_child(npc)

	# ---- Chests ----
	if _zone_data.has("chest_positions") and chest_scene != null:
		for entry in _zone_data["chest_positions"]:
			var pos: Vector2
			if use_generated and slot_idx < slots.size():
				pos = slots[slot_idx]
				slot_idx += 1
			else:
				var pa: Array = entry.get("position", [0, 0])
				pos = Vector2(pa[0], pa[1])

			var chest: Node = chest_scene.instantiate()
			chest.loot_table_id = entry.get("loot_table", "common_chest")
			chest.position      = pos
			entities_node.add_child(chest)

# ---------------------------------------------------------------------------
# Exit sensor
# ---------------------------------------------------------------------------

func _spawn_exit_sensor(world_node: Node) -> void:
	var area := Area2D.new()
	area.name        = "ExitArea"
	area.position    = _exit_pos
	area.monitoring  = true
	area.monitorable = false

	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape   = circle
	area.add_child(shape)

	area.body_entered.connect(_on_exit_body_entered.bind("dungeon_floor_02"))
	world_node.add_child(area)

func _on_exit_body_entered(body: Node, target_zone: String) -> void:
	if body.is_in_group("player"):
		zone_exit_reached.emit(target_zone)
