extends GutTest

# Integration test: full shop transaction flow

var inventory: InventoryComponent
var economy_system: EconomySystem
var shop_data: Dictionary
var mock_item_data: Dictionary


func before_each() -> void:
	# Set player gold
	GameState.player_data["gold"] = 100

	inventory = InventoryComponent.new()
	add_child_autofree(inventory)

	economy_system = EconomySystem.new()
	add_child_autofree(economy_system)

	shop_data = {
		"inventory": [
			{"item_id": "sword_iron", "stock": 5, "price_multiplier": 1.0}
		],
		"buy_multiplier": 0.4
	}

	mock_item_data = {
		"id": "sword_iron",
		"name": "Iron Sword",
		"value": 50,
		"slot": "weapon"
	}
	DataLoader.set_mock_item("sword_iron", mock_item_data)


func after_each() -> void:
	DataLoader.clear_mock_item("sword_iron")


func test_buy_reduces_player_gold() -> void:
	economy_system.buy_item("sword_iron", inventory, shop_data)
	assert_eq(GameState.player_data["gold"], 50, "Buying sword_iron (cost 50) should reduce gold from 100 to 50")


func test_buy_adds_item_to_inventory() -> void:
	economy_system.buy_item("sword_iron", inventory, shop_data)
	assert_true(inventory.has_item("sword_iron"), "sword_iron should be in inventory after purchase")


func test_buy_reduces_stock() -> void:
	economy_system.buy_item("sword_iron", inventory, shop_data)
	var stock_entry: Dictionary = shop_data["inventory"][0]
	assert_eq(stock_entry["stock"], 4, "Stock should decrease from 5 to 4 after purchase")


func test_buy_fails_insufficient_gold() -> void:
	GameState.player_data["gold"] = 10
	var result: bool = economy_system.buy_item("sword_iron", inventory, shop_data)
	assert_false(result, "Buy should return false when player has insufficient gold")
	assert_eq(GameState.player_data["gold"], 10, "Gold should remain unchanged on failed purchase")


func test_buy_fails_out_of_stock() -> void:
	shop_data["inventory"][0]["stock"] = 0
	var result: bool = economy_system.buy_item("sword_iron", inventory, shop_data)
	assert_false(result, "Buy should return false when item is out of stock")


func test_sell_increases_gold() -> void:
	inventory.add_item("sword_iron", 1)
	var gold_before: int = GameState.player_data["gold"]
	var sell_price: int = economy_system.get_sell_price("sword_iron", shop_data)
	economy_system.sell_item("sword_iron", inventory, shop_data)
	assert_eq(GameState.player_data["gold"], gold_before + sell_price,
		"Selling sword_iron should increase gold by the sell price")


func test_sell_removes_item_from_inventory() -> void:
	inventory.add_item("sword_iron", 1)
	economy_system.sell_item("sword_iron", inventory, shop_data)
	assert_false(inventory.has_item("sword_iron"), "sword_iron should be removed from inventory after selling")


func test_buy_then_sell_net_loss() -> void:
	# Buy at 50gp, sell back at 0.4x = 20gp -> net loss of 30gp
	var gold_start: int = GameState.player_data["gold"]
	economy_system.buy_item("sword_iron", inventory, shop_data)
	economy_system.sell_item("sword_iron", inventory, shop_data)
	var net_change: int = GameState.player_data["gold"] - gold_start
	assert_eq(net_change, -30, "Buying for 50gp and selling at 0.4x (20gp) should result in a net loss of 30gp")
