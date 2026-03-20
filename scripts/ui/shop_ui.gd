extends Control

var _shop_data: Dictionary = {}
var _player_inventory: InventoryComponent = null
var _economy: EconomySystem = null

@onready var shop_name_label: Label = $Panel/VBoxContainer/ShopNameLabel
@onready var shop_item_list: VBoxContainer = $Panel/VBoxContainer/HBoxContainer/ShopStock/ScrollContainer/ShopItemList
@onready var player_item_list: VBoxContainer = $Panel/VBoxContainer/HBoxContainer/PlayerInventory/ScrollContainer/PlayerItemList
@onready var gold_label: Label = $Panel/VBoxContainer/Footer/GoldLabel
@onready var close_button: Button = $Panel/VBoxContainer/Footer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(close_shop)
	# Locate EconomySystem in scene tree (added as child of GameState or scene root).
	_economy = _find_economy_system()
	hide()


func open_shop(shop_id: String, player_inventory: InventoryComponent) -> void:
	_shop_data = DataLoader.load_shop(shop_id)
	_player_inventory = player_inventory
	shop_name_label.text = _shop_data.get("name", shop_id.capitalize())
	refresh()
	show()
	EventBus.shop_opened.emit(shop_id)


func close_shop() -> void:
	hide()
	EventBus.shop_closed.emit()


func refresh() -> void:
	_rebuild_shop_list()
	_rebuild_player_list()
	_update_gold_label()


func _rebuild_shop_list() -> void:
	# Clear existing children.
	for child in shop_item_list.get_children():
		child.queue_free()

	var inventory: Array = _shop_data.get("inventory", [])
	for entry in inventory:
		var item_id: String = entry.get("item_id", "")
		var stock: int = entry.get("stock", -1)
		var price: int = _economy.get_buy_price(item_id, _shop_data) if _economy else 0

		var row := HBoxContainer.new()

		var name_lbl := Label.new()
		var stock_text: String = "∞" if stock == -1 else str(stock)
		name_lbl.text = "%s  [%s]  %dg" % [item_id.replace("_", " ").capitalize(), stock_text, price]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id))
		if stock == 0:
			buy_btn.disabled = true
		row.add_child(buy_btn)

		shop_item_list.add_child(row)


func _rebuild_player_list() -> void:
	for child in player_item_list.get_children():
		child.queue_free()

	if _player_inventory == null:
		return

	var items: Array = _player_inventory.get_items()
	for item_id in items:
		var sell_price: int = _economy.get_sell_price(item_id, _shop_data) if _economy else 0

		var row := HBoxContainer.new()

		var name_lbl := Label.new()
		name_lbl.text = "%s  %dg" % [item_id.replace("_", " ").capitalize(), sell_price]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.pressed.connect(_on_sell_pressed.bind(item_id))
		row.add_child(sell_btn)

		player_item_list.add_child(row)


func _update_gold_label() -> void:
	var gold: int = GameState.player_data.get("gold", 0)
	gold_label.text = "Gold: %d" % gold


func _on_buy_pressed(item_id: String) -> void:
	if _economy == null:
		push_error("ShopUI: EconomySystem not found")
		return
	_economy.buy_item(_player_inventory, item_id, _shop_data)
	refresh()


func _on_sell_pressed(item_id: String) -> void:
	if _economy == null:
		push_error("ShopUI: EconomySystem not found")
		return
	_economy.sell_item(_player_inventory, item_id, _shop_data)
	refresh()


func _find_economy_system() -> EconomySystem:
	var root := get_tree().root
	var found := root.find_child("EconomySystem", true, false)
	if found is EconomySystem:
		return found
	return null
