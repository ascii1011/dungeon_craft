extends CharacterBody2D

var npc_id: String = "blacksmith"
var dialogue_id: String = "blacksmith"
var shop_id: String = ""

@onready var interact_area: Area2D = $InteractArea
@onready var name_label: Label = $NameLabel

var _dialogue_ui: Node = null
var _shop_ui: Node = null
var _player_in_range: bool = false


func _ready() -> void:
	add_to_group("npc")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	name_label.text = npc_id.capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_in_range:
		interact()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_show_interact_prompt(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_show_interact_prompt(false)


func _show_interact_prompt(visible: bool) -> void:
	# Show/hide a prompt above the NPC name label.
	# In v1 we simply tint the label to indicate interaction availability.
	if visible:
		name_label.modulate = Color(1.0, 1.0, 0.0)
	else:
		name_label.modulate = Color(1.0, 1.0, 1.0)


func interact() -> void:
	var dialogue_path := "res://data/dialogue/%s.json" % dialogue_id
	var dialogue_data: Dictionary = DataLoader.load_json(dialogue_path)
	if dialogue_data.is_empty():
		push_warning("NPC: could not load dialogue for '%s'" % dialogue_id)
		return

	_dialogue_ui = _get_or_create_dialogue_ui()
	if _dialogue_ui == null:
		push_error("NPC: DialogueUI not found in scene tree")
		return

	_dialogue_ui.dialogue_action.connect(_on_dialogue_action, CONNECT_ONE_SHOT)
	_dialogue_ui.show_dialogue(dialogue_data)


func _on_dialogue_action(action: String, data: Dictionary) -> void:
	if action == "open_shop" and not shop_id.is_empty():
		var s_id: String = data.get("shop_id", shop_id)
		var shop_ui_node := _get_or_create_shop_ui()
		if shop_ui_node == null:
			push_error("NPC: ShopUI not found in scene tree")
			return
		var player := _find_player()
		if player == null:
			push_error("NPC: could not find player node for shop open")
			return
		var player_inventory: InventoryComponent = player.get_node_or_null("InventoryComponent")
		shop_ui_node.open_shop(s_id, player_inventory)


func _get_or_create_dialogue_ui() -> Node:
	# Look for an existing DialogueUI in the scene tree.
	var root := get_tree().root
	var found := root.find_child("DialogueUI", true, false)
	return found


func _get_or_create_shop_ui() -> Node:
	var root := get_tree().root
	var found := root.find_child("ShopUI", true, false)
	return found


func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null
