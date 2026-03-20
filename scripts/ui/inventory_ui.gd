## InventoryUI
## Control node that displays the player's inventory grid and equipment slots.
## Toggle with the "open_inventory" input action (default: I key).
##
## Set the `inventory_component` NodePath export in the Godot editor to point
## at the InventoryComponent node in the scene tree, or assign _inv directly
## from code before _ready() runs.
extends Control

# ---------------------------------------------------------------------------
# Exports / references
# ---------------------------------------------------------------------------

## NodePath pointing to the InventoryComponent to display.
## Set this in the Godot editor or via code before the node enters the tree.
@export var inventory_component: NodePath

## Resolved reference to the active InventoryComponent.
var _inv: InventoryComponent

# ---------------------------------------------------------------------------
# Cached node references (populated in _ready)
# ---------------------------------------------------------------------------

var _item_grid: GridContainer
var _weapon_slot: Panel
var _armor_slot: Panel
var _ring_slot: Panel

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Resolve the inventory component from the NodePath export if set.
	if not inventory_component.is_empty():
		var node := get_node_or_null(inventory_component)
		if node is InventoryComponent:
			_inv = node

	# Cache UI node references.
	_item_grid = get_node_or_null("Background/VBoxContainer/ItemGrid")
	_weapon_slot = get_node_or_null("Background/VBoxContainer/EquipmentSlots/Weapon/WeaponSlot")
	_armor_slot  = get_node_or_null("Background/VBoxContainer/EquipmentSlots/Armor/ArmorSlot")
	_ring_slot   = get_node_or_null("Background/VBoxContainer/EquipmentSlots/Ring/RingSlot")

	# Connect a close button if present.
	var close_btn := get_node_or_null("Background/CloseButton")
	if close_btn is Button:
		close_btn.pressed.connect(hide_inventory)

	# Connect inventory signals for auto-refresh.
	if _inv != null:
		_inv.item_added.connect(_on_inventory_changed)
		_inv.item_removed.connect(_on_inventory_changed)
		_inv.item_equipped.connect(_on_equipment_changed)
		_inv.item_unequipped.connect(_on_slot_unequipped)

	# Start hidden.
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		_on_open_inventory_action()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Rebuild the grid and equipment slot labels from the current inventory state.
func refresh() -> void:
	_refresh_grid()
	_refresh_equipment()


## Make the inventory panel visible and refresh its contents.
func show_inventory() -> void:
	refresh()
	visible = true


## Hide the inventory panel.
func hide_inventory() -> void:
	visible = false

# ---------------------------------------------------------------------------
# Input action handler
# ---------------------------------------------------------------------------

## Toggle inventory visibility when the "open_inventory" action fires.
func _on_open_inventory_action() -> void:
	if visible:
		hide_inventory()
	else:
		show_inventory()

# ---------------------------------------------------------------------------
# Slot click handler
# ---------------------------------------------------------------------------

## Called when the player clicks on an inventory slot.
## Presents a context menu with equip / use / drop options.
func _on_item_slot_clicked(slot_index: int) -> void:
	if _inv == null:
		return

	# Find the item in this slot.
	var item_entry: Dictionary = {}
	for entry in _inv.get_all_items():
		if entry["slot_index"] == slot_index:
			item_entry = entry
			break

	if item_entry.is_empty():
		return

	# Show a simple PopupMenu as a context menu.
	var menu := PopupMenu.new()
	add_child(menu)
	menu.add_item("Equip", 0)
	menu.add_item("Use",   1)
	menu.add_item("Drop",  2)
	menu.id_pressed.connect(func(id: int) -> void:
		_handle_context_action(id, item_entry["item_id"])
		menu.queue_free()
	)
	menu.popup_centered()


## Handle the context menu action selected by the player.
func _handle_context_action(action_id: int, item_id: String) -> void:
	match action_id:
		0:  # Equip
			if _inv != null:
				_inv.equip_item(item_id)
		1:  # Use — placeholder for future consumable logic
			pass
		2:  # Drop
			if _inv != null:
				_inv.remove_item(item_id)

# ---------------------------------------------------------------------------
# Signal handlers for auto-refresh
# ---------------------------------------------------------------------------

func _on_inventory_changed(_item_id: String, _quantity: int) -> void:
	refresh()


func _on_equipment_changed(_item_id: String, _slot: String) -> void:
	_refresh_equipment()


func _on_slot_unequipped(_slot: String) -> void:
	_refresh_equipment()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Update every ItemSlot label in the grid to reflect current inventory state.
func _refresh_grid() -> void:
	if _item_grid == null or _inv == null:
		return

	var all_items: Array[Dictionary] = _inv.get_all_items()

	# Build a lookup from slot_index → item entry.
	var by_slot: Dictionary = {}
	for entry in all_items:
		by_slot[entry["slot_index"]] = entry

	# Update each slot panel child (labelled "ItemSlot0" … "ItemSlot19").
	for i in range(_item_grid.get_child_count()):
		var slot_panel: Node = _item_grid.get_child(i)
		var label: Label = slot_panel.get_node_or_null("Label")
		if label == null:
			continue

		if by_slot.has(i):
			var entry: Dictionary = by_slot[i]
			var item_data: Dictionary = DataLoader.load_item(entry["item_id"])
			var display_name: String = item_data.get("name", entry["item_id"])
			if entry["quantity"] > 1:
				label.text = "%s\nx%d" % [display_name, entry["quantity"]]
			else:
				label.text = display_name
		else:
			label.text = "Empty"


## Update the three equipment slot panels to show what is currently equipped.
func _refresh_equipment() -> void:
	if _inv == null:
		return

	_update_equip_slot_label(_weapon_slot, _inv.get_equipped("weapon"))
	_update_equip_slot_label(_armor_slot,  _inv.get_equipped("armor"))
	_update_equip_slot_label(_ring_slot,   _inv.get_equipped("ring"))


## Set the label inside an equipment slot Panel to show the equipped item name.
func _update_equip_slot_label(slot_panel: Panel, item_id: String) -> void:
	if slot_panel == null:
		return
	var label: Label = slot_panel.get_node_or_null("Label")
	if label == null:
		return
	if item_id.is_empty():
		label.text = ""
	else:
		var item_data: Dictionary = DataLoader.load_item(item_id)
		label.text = item_data.get("name", item_id)
