## InventoryComponent
## Manages item storage and equipment slots for any entity.
## Attach as a child node to any entity that needs an inventory.
## Items are identified by string IDs that map to data/items/*.json files.
##
## Each inventory entry: { item_id: String, quantity: int, slot_index: int }
## Equipment slots: { slot_name: item_id } — empty slot stored as ""
class_name InventoryComponent
extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Total number of item slots available.
@export var max_slots: int = 20

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Flat list of item stacks currently in the inventory.
## Each entry: { "item_id": String, "quantity": int, "slot_index": int }
var _items: Array[Dictionary] = []

## Currently equipped items keyed by slot name.
## Empty string means the slot is unoccupied.
var _equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"ring": "",
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted after an item is successfully added to the inventory.
signal item_added(item_id: String, quantity: int)

## Emitted after items are removed from the inventory.
signal item_removed(item_id: String, quantity: int)

## Emitted after an item is moved into an equipment slot.
## Also emits EventBus.item_equipped.
signal item_equipped(item_id: String, slot: String)

## Emitted after an equipment slot is cleared.
signal item_unequipped(slot: String)

## Emitted when add_item() is called but no slot is available.
signal inventory_full()

# ---------------------------------------------------------------------------
# Public API — item storage
# ---------------------------------------------------------------------------

## Add quantity of item_id to the inventory.
## If the item is stackable and already present, the quantity is merged into
## the existing stack (up to max_stack). Non-stackable items always occupy a
## fresh slot. Returns false if there is no room for a new slot.
func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_data: Dictionary = DataLoader.load_item(item_id)
	var stackable: bool = item_data.get("stackable", false)
	var max_stack: int = item_data.get("max_stack", 1)

	if stackable:
		# Try to top up an existing stack first.
		for entry in _items:
			if entry["item_id"] == item_id:
				var space_left: int = max_stack - entry["quantity"]
				if space_left > 0:
					var to_add: int = mini(quantity, space_left)
					entry["quantity"] += to_add
					quantity -= to_add
					if quantity <= 0:
						item_added.emit(item_id, entry["quantity"])
						return true
				# Stack is full — fall through to open a new slot.

	# Need at least one free slot for the remainder (or for non-stackable items).
	if _items.size() >= max_slots:
		inventory_full.emit()
		return false

	var slot_index: int = _find_free_slot_index()
	_items.append({
		"item_id": item_id,
		"quantity": quantity,
		"slot_index": slot_index,
	})
	item_added.emit(item_id, quantity)
	return true


## Remove quantity of item_id from the inventory.
## Reduces the stack; removes the entry when quantity reaches zero.
## Returns false if the item is not present in sufficient quantity.
func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(_items.size()):
		var entry: Dictionary = _items[i]
		if entry["item_id"] == item_id:
			if entry["quantity"] < quantity:
				return false
			entry["quantity"] -= quantity
			if entry["quantity"] <= 0:
				_items.remove_at(i)
			item_removed.emit(item_id, quantity)
			return true
	return false


## Returns true if at least one of item_id is present in the inventory.
func has_item(item_id: String) -> bool:
	for entry in _items:
		if entry["item_id"] == item_id:
			return true
	return false


## Returns the total quantity of item_id held across all stacks.
func get_quantity(item_id: String) -> int:
	var total: int = 0
	for entry in _items:
		if entry["item_id"] == item_id:
			total += entry["quantity"]
	return total


## Returns a shallow copy of the internal items array.
## Each element is a Dictionary: { item_id, quantity, slot_index }.
func get_all_items() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in _items:
		copy.append(entry.duplicate())
	return copy


## Clear all items and reset equipment slots. Intended for tests and new-game.
func clear() -> void:
	_items.clear()
	_equipment = {
		"weapon": "",
		"armor": "",
		"ring": "",
	}

# ---------------------------------------------------------------------------
# Public API — equipment
# ---------------------------------------------------------------------------

## Attempt to equip item_id into its designated slot.
## Loads item data, resolves the target slot, and checks stat requirements
## against the parent node's StatsComponent (if present).
## Returns false when:
##   - item data cannot be loaded
##   - item has no valid equipment slot
##   - stat requirements are not met
func equip_item(item_id: String) -> bool:
	var item_data: Dictionary = DataLoader.load_item(item_id)
	if item_data.is_empty():
		push_warning("InventoryComponent: cannot equip '%s' — item data not found" % item_id)
		return false

	# Resolve the slot. Items store their slot as e.g. "weapon", "body", "ring".
	# Map "body" → "armor" to match internal equipment dict keys.
	var raw_slot: String = str(item_data.get("slot", ""))
	if raw_slot.is_empty() or raw_slot == "null":
		push_warning("InventoryComponent: '%s' has no equipment slot" % item_id)
		return false

	var slot: String = _normalise_slot(raw_slot)
	if not _equipment.has(slot):
		push_warning("InventoryComponent: unknown equipment slot '%s' for item '%s'" % [slot, item_id])
		return false

	# Check stat requirements against the parent entity's StatsComponent.
	var requirements: Dictionary = item_data.get("requirements", {})
	if not requirements.is_empty():
		var stats: StatsComponent = _get_stats_component()
		if stats != null:
			for stat_name in requirements:
				var required: int = int(requirements[stat_name])
				var current: int = stats.get_total(stat_name)
				if current < required:
					push_warning("InventoryComponent: cannot equip '%s' — %s %d required, have %d" % [
						item_id, stat_name, required, current
					])
					return false

	_equipment[slot] = item_id
	item_equipped.emit(item_id, slot)
	EventBus.item_equipped.emit(item_id, slot)
	return true


## Clear the given equipment slot. Does nothing if the slot does not exist.
func unequip_slot(slot: String) -> void:
	if _equipment.has(slot):
		_equipment[slot] = ""
		item_unequipped.emit(slot)


## Returns the item_id currently in the given equipment slot, or "" if empty.
func get_equipped(slot: String) -> String:
	return _equipment.get(slot, "")

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Find the lowest slot_index not currently occupied by any entry.
func _find_free_slot_index() -> int:
	var used: Array = []
	for entry in _items:
		used.append(entry["slot_index"])
	for idx in range(max_slots):
		if not used.has(idx):
			return idx
	return _items.size()  # Fallback (should not be reached after size check).


## Map raw item JSON slot names to internal equipment dictionary keys.
func _normalise_slot(raw: String) -> String:
	match raw:
		"body":
			return "armor"
		_:
			return raw


## Retrieve a StatsComponent from the parent node, if one is attached.
func _get_stats_component() -> StatsComponent:
	var p: Node = get_parent()
	if p == null:
		return null
	for child in p.get_children():
		if child is StatsComponent:
			return child
	return null
