extends GutTest

# ---------------------------------------------------------------------------
# Helpers / mocks
# ---------------------------------------------------------------------------

const STARTING_GOLD := 100

## Minimal mock shop data used across all tests.
## price_multiplier=2.0  →  buy price  = base_value * 2
## buy_multiplier=0.5    →  sell price = base_value * 0.5
var _shop_data: Dictionary = {
	"name": "Test Shop",
	"price_multiplier": 2.0,
	"buy_multiplier": 0.5,
	"inventory": [
		{"item_id": "sword_iron", "stock": 3},
		{"item_id": "potion_health", "stock": -1},
		{"item_id": "out_of_stock_item", "stock": 0}
	]
}

## Stub InventoryComponent used in tests.
## Real InventoryComponent is not loaded so we use a lightweight inner class.
class MockInventory:
	var _items: Array = []

	func add_item(item_id: String) -> void:
		_items.append(item_id)

	func remove_item(item_id: String) -> bool:
		var idx := _items.find(item_id)
		if idx == -1:
			return false
		_items.remove_at(idx)
		return true

	func get_items() -> Array:
		return _items.duplicate()

	func has_item(item_id: String) -> bool:
		return _items.has(item_id)


## Stub DataLoader that returns predictable item data.
## Overrides DataLoader autoload during tests.
class MockDataLoader:
	func load_item(item_id: String) -> Dictionary:
		match item_id:
			"sword_iron":
				return {"id": "sword_iron", "value": 50}
			"potion_health":
				return {"id": "potion_health", "value": 20}
			"out_of_stock_item":
				return {"id": "out_of_stock_item", "value": 10}
			_:
				return {"id": item_id, "value": 0}

	func load_shop(_shop_id: String) -> Dictionary:
		return {}

	func load_json(_path: String) -> Dictionary:
		return {}


var _economy: EconomySystem
var _inventory: MockInventory
var _original_data_loader


func before_each() -> void:
	# Reset gold before every test.
	GameState.player_data["gold"] = STARTING_GOLD

	# Replace DataLoader with mock so we don't touch the filesystem.
	_original_data_loader = DataLoader
	# GDScript does not support runtime autoload replacement directly,
	# so we monkey-patch the singleton reference stored in the EconomySystem
	# by subclassing and injecting. Instead we rely on the economy system
	# using a settable data loader reference:
	_economy = EconomySystem.new()
	_economy._data_loader = MockDataLoader.new()
	add_child(_economy)

	_inventory = MockInventory.new()


func after_each() -> void:
	_economy.queue_free()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_buy_item_deducts_gold() -> void:
	# sword_iron base value=50, price_multiplier=2.0 → cost=100
	var result := _economy.buy_item(_inventory, "sword_iron", _shop_data)
	assert_true(result, "buy_item should return true on success")
	assert_eq(GameState.player_data["gold"], 0,
		"Gold should be deducted by buy price (100 - 100 = 0)")


func test_buy_item_adds_to_inventory() -> void:
	_economy.buy_item(_inventory, "sword_iron", _shop_data)
	assert_true(_inventory.has_item("sword_iron"),
		"sword_iron should be in player inventory after purchase")


func test_buy_item_fails_insufficient_gold() -> void:
	# potion_health: base=20, multiplier=2.0 → cost=40 — affordable.
	# sword_iron: cost=100 — just barely affordable with 100g.
	# Try to buy sword_iron twice: first OK, second fails (0g left).
	_economy.buy_item(_inventory, "sword_iron", _shop_data)
	var result := _economy.buy_item(_inventory, "potion_health", _shop_data)
	assert_false(result, "Second buy should fail: not enough gold")
	assert_eq(GameState.player_data["gold"], 0,
		"Gold should not change after failed purchase")


func test_buy_item_fails_out_of_stock() -> void:
	var result := _economy.buy_item(_inventory, "out_of_stock_item", _shop_data)
	assert_false(result, "buy_item should fail when stock=0")
	assert_eq(GameState.player_data["gold"], STARTING_GOLD,
		"Gold should be unchanged after out-of-stock failure")


func test_sell_item_adds_gold() -> void:
	# Give player a sword_iron to sell.
	_inventory.add_item("sword_iron")
	# sell price = base_value(50) * buy_multiplier(0.5) = 25
	var result := _economy.sell_item(_inventory, "sword_iron", _shop_data)
	assert_true(result, "sell_item should return true on success")
	assert_eq(GameState.player_data["gold"], STARTING_GOLD + 25,
		"Gold should increase by sell price (100 + 25 = 125)")


func test_sell_item_removes_from_inventory() -> void:
	_inventory.add_item("sword_iron")
	_economy.sell_item(_inventory, "sword_iron", _shop_data)
	assert_false(_inventory.has_item("sword_iron"),
		"sword_iron should be removed from inventory after selling")


func test_get_buy_price_applies_multiplier() -> void:
	# sword_iron base=50, price_multiplier=2.0 → 100
	var price := _economy.get_buy_price("sword_iron", _shop_data)
	assert_eq(price, 100, "Buy price should be base_value * price_multiplier")


func test_get_sell_price_applies_buy_multiplier() -> void:
	# sword_iron base=50, buy_multiplier=0.5 → 25
	var price := _economy.get_sell_price("sword_iron", _shop_data)
	assert_eq(price, 25, "Sell price should be base_value * buy_multiplier")
