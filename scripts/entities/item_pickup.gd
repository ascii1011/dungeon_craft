## ItemPickup
## An Area2D representing a dropped item lying on the ground.
## When a node in the "player" group enters the collision area, the item
## is automatically added to that player's InventoryComponent and the node
## frees itself from the world.
##
## item_id must be set before (or immediately after) adding to the scene tree.
extends Area2D

# ---------------------------------------------------------------------------
# Exports / public properties
# ---------------------------------------------------------------------------

## The data identifier for this item (matches a key in DataLoader.load_item).
var item_id: String = ""

## Reserved for future use (e.g. magnet range upgrade).
var auto_pickup: bool = false

# ---------------------------------------------------------------------------
# Child node references
# ---------------------------------------------------------------------------

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_load_display()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Called when a physics body enters the pickup's collision area.
## Attempts to add the item to the player's inventory and removes the pickup.
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# Look for an InventoryComponent on the player.
	var inventory: Node = body.get_node_or_null("InventoryComponent")
	if inventory == null:
		push_warning("ItemPickup: player body has no InventoryComponent child node")
		return

	var success: bool = inventory.add_item(item_id)
	if success:
		EventBus.item_picked_up.emit(item_id)
		queue_free()

# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

## Load item data and update the label with the item's display name.
## The label is hidden by default and shown on hover (future: mouse_entered).
func _load_display() -> void:
	if item_id.is_empty():
		return

	var item_data: Dictionary = DataLoader.load_item(item_id)
	if item_data.is_empty():
		return

	var item_name: String = item_data.get("name", item_id)
	label.text = item_name
	label.visible = false  # Hidden by default; shown on hover.
