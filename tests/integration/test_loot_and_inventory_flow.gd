extends GutTest

# Integration test: loot roll -> inventory add chain

var inventory: InventoryComponent
var loot_system: LootSystem


func before_each() -> void:
	inventory = InventoryComponent.new()
	add_child_autofree(inventory)

	loot_system = LootSystem.new()
	add_child_autofree(loot_system)


func test_item_added_to_inventory_on_pickup() -> void:
	inventory.add_item("potion_health", 1)
	assert_true(inventory.has_item("potion_health"), "Inventory should contain potion_health after add_item")


func test_stackable_items_stack_correctly() -> void:
	inventory.add_item("potion_health", 1)
	inventory.add_item("potion_health", 1)
	assert_eq(inventory.get_quantity("potion_health"), 2, "Stackable items should combine into a stack of 2")


func test_inventory_full_blocks_addition() -> void:
	# Register mock data for all filler items so DataLoader doesn't hit disk.
	var non_stackable := {"stackable": false, "max_stack": 1}
	for i in range(20):
		DataLoader.set_mock_item("unique_item_%d" % i, non_stackable)
	DataLoader.set_mock_item("overflow_item", non_stackable)

	var result_ref := {"emitted": false}
	var spy := func() -> void:
		result_ref["emitted"] = true
	inventory.inventory_full.connect(spy)

	for i in range(20):
		inventory.add_item("unique_item_%d" % i, 1)

	var result: bool = inventory.add_item("overflow_item", 1)
	assert_false(result, "add_item should return false when inventory is full")
	assert_true(result_ref["emitted"], "inventory_full signal should be emitted when inventory is full")

	inventory.inventory_full.disconnect(spy)

	for i in range(20):
		DataLoader.clear_mock_item("unique_item_%d" % i)
	DataLoader.clear_mock_item("overflow_item")


func test_equip_item_updates_equipment_slot() -> void:
	# Inject mock item data into DataLoader cache
	var mock_item_data := {
		"id": "sword_iron",
		"name": "Iron Sword",
		"type": "weapon",
		"slot": "weapon",
		"value": 50,
		"stackable": false,
		"max_stack": 1,
		"requirements": {}
	}
	DataLoader.set_mock_item("sword_iron", mock_item_data)

	inventory.add_item("sword_iron", 1)
	inventory.equip_item("sword_iron")

	assert_eq(inventory.get_equipped("weapon"), "sword_iron", "Equipping sword_iron should update the weapon slot")

	DataLoader.clear_mock_item("sword_iron")


func test_loot_probability_over_iterations() -> void:
	var loot_table := {
		"items": [
			{"item_id": "coin_gold", "chance": 0.5}
		]
	}
	var roll_count := 200
	var success_count := 0

	for _i in range(roll_count):
		var drops: Array = loot_system.roll_loot(loot_table)
		for drop in drops:
			if drop.get("item_id") == "coin_gold":
				success_count += 1

	assert_gte(success_count, 70, "50%% loot over 200 rolls should yield at least 70 results")
	assert_lte(success_count, 130, "50%% loot over 200 rolls should yield at most 130 results")
