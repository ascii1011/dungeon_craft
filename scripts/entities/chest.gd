## Chest
## An interactable StaticBody2D that holds loot.
## The player triggers interact() (e.g. via the interact input action) when
## standing inside the InteractArea. The chest rolls a loot table via
## LootSystem and plays a simple open animation (frame advance on Sprite2D).
##
## loot_table_id must match a file in `data/loot_tables/`.
extends StaticBody2D

# ---------------------------------------------------------------------------
# Exports / public properties
# ---------------------------------------------------------------------------

## ID of the loot table file to roll when this chest is opened.
## Corresponds to `data/loot_tables/{loot_table_id}.json`.
@export var loot_table_id: String = "common_chest"

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the chest is successfully opened.
signal chest_opened(loot_table_id: String)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _opened: bool = false

# ---------------------------------------------------------------------------
# Child node references
# ---------------------------------------------------------------------------

@onready var sprite: Sprite2D = $Sprite2D

## LootSystem reference — resolved from the scene tree if present, otherwise
## instantiated locally so the chest is self-contained.
@onready var loot_system: Node = _resolve_loot_system()

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass  # Interaction is triggered externally via interact().

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by the player (or interaction system) when the chest should open.
## Rolls the loot table and advances the sprite to the open frame.
## No-op if the chest is already open.
func interact() -> void:
	if _opened:
		return

	_opened = true

	# Roll loot if a LootSystem is available.
	if loot_system != null:
		var world: Node = get_tree().current_scene
		if world != null:
			loot_system.roll_chest_loot(loot_table_id, global_position, world)
	else:
		push_warning("Chest.interact: no LootSystem found; loot will not spawn")

	# Play open animation: advance sprite to frame 1 (closed=0, open=1).
	if sprite != null:
		sprite.frame = 1

	chest_opened.emit(loot_table_id)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Attempt to find a LootSystem already in the scene tree (e.g. as a sibling
## or parent node). Falls back to instantiating a detached instance so the
## chest is self-contained during tests.
func _resolve_loot_system() -> Node:
	# Check common locations: parent, or a "/root/LootSystem" singleton path.
	var parent_search := get_parent()
	if parent_search != null:
		var sibling := parent_search.get_node_or_null("LootSystem")
		if sibling != null:
			return sibling

	# Fall back: look anywhere in the scene tree under the current scene root.
	var scene_root := get_tree().current_scene if get_tree() != null else null
	if scene_root != null:
		var found := _find_loot_system_in(scene_root)
		if found != null:
			return found

	# Last resort: create a local instance (useful in tests / standalone scenes).
	var ls_script := load("res://scripts/systems/loot_system.gd")
	if ls_script != null:
		var ls: Node = ls_script.new()
		add_child(ls)
		return ls

	return null


func _find_loot_system_in(node: Node) -> Node:
	if node.get_script() != null:
		var script_path: String = node.get_script().resource_path
		if script_path.ends_with("loot_system.gd"):
			return node
	for child in node.get_children():
		var result := _find_loot_system_in(child)
		if result != null:
			return result
	return null
