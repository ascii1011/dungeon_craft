extends Node

signal transaction_completed(type: String, item_id: String, gold_amount: int)
signal transaction_failed(reason: String)

## Allows tests to inject a mock data loader instead of using the global autoload.
var _data_loader = null


func _ready() -> void:
	if _data_loader == null:
		_data_loader = DataLoader


func buy_item(player_inventory: InventoryComponent, item_id: String, shop_data: Dictionary) -> bool:
	# Find the item entry in the shop inventory.
	var shop_item: Dictionary = _find_shop_item(item_id, shop_data)
	if shop_item.is_empty():
		transaction_failed.emit("Item '%s' not found in shop." % item_id)
		return false

	# Check stock.
	var stock: int = shop_item.get("stock", -1)
	if stock == 0:
		transaction_failed.emit("'%s' is out of stock." % item_id)
		return false

	# Load item base value from DataLoader.
	var price: int = get_buy_price(item_id, shop_data)

	# Check player gold.
	var current_gold: int = GameState.player_data.get("gold", 0)
	if current_gold < price:
		transaction_failed.emit("Not enough gold to buy '%s'. Need %d, have %d." % [item_id, price, current_gold])
		return false

	# Deduct gold.
	GameState.player_data["gold"] = current_gold - price

	# Add item to player inventory.
	player_inventory.add_item(item_id)

	# Reduce shop stock if finite.
	if stock != -1:
		shop_item["stock"] = stock - 1

	EventBus.gold_changed.emit(GameState.player_data["gold"])
	EventBus.item_picked_up.emit(item_id)
	transaction_completed.emit("buy", item_id, price)
	return true


func sell_item(player_inventory: InventoryComponent, item_id: String, shop_data: Dictionary) -> bool:
	# Remove item from player inventory first (validates the player owns it).
	if not player_inventory.remove_item(item_id):
		transaction_failed.emit("Item '%s' not found in player inventory." % item_id)
		return false

	var sell_price: int = get_sell_price(item_id, shop_data)

	# Add gold to player.
	GameState.player_data["gold"] = GameState.player_data.get("gold", 0) + sell_price

	EventBus.gold_changed.emit(GameState.player_data["gold"])
	transaction_completed.emit("sell", item_id, sell_price)
	return true


func get_buy_price(item_id: String, shop_data: Dictionary) -> int:
	var base_value: int = _get_item_base_value(item_id)
	var multiplier: float = shop_data.get("price_multiplier", 1.0)
	return int(base_value * multiplier)


func get_sell_price(item_id: String, shop_data: Dictionary) -> int:
	var base_value: int = _get_item_base_value(item_id)
	var multiplier: float = shop_data.get("buy_multiplier", 0.5)
	return int(base_value * multiplier)


# --- Private helpers ---

func _find_shop_item(item_id: String, shop_data: Dictionary) -> Dictionary:
	var inventory: Array = shop_data.get("inventory", [])
	for entry in inventory:
		if entry.get("item_id", "") == item_id:
			return entry
	return {}


func _get_item_base_value(item_id: String) -> int:
	var item_data: Dictionary = _data_loader.load_item(item_id)
	return item_data.get("value", 0)
