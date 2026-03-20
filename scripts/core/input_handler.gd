extends Node

var peer_id: int = 1
var is_local: bool = true

# Input state — polled each frame by player.gd
var move_direction: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var attack_just_pressed: bool = false
var spell_slot: int = 0
var interact_just_pressed: bool = false
var inventory_just_pressed: bool = false


func _process(_delta: float) -> void:
	if not is_local:
		return

	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	attack_pressed = Input.is_action_pressed("attack")
	attack_just_pressed = Input.is_action_just_pressed("attack")

	interact_just_pressed = Input.is_action_just_pressed("interact")
	inventory_just_pressed = Input.is_action_just_pressed("inventory")

	if Input.is_action_just_pressed("spell_1"):
		spell_slot = 1
	elif Input.is_action_just_pressed("spell_2"):
		spell_slot = 2
	elif Input.is_action_just_pressed("spell_3"):
		spell_slot = 3
	else:
		spell_slot = 0


func set_remote_input(data: Dictionary) -> void:
	move_direction = Vector2(
		data.get("move_x", 0.0),
		data.get("move_y", 0.0)
	)
	attack_pressed = data.get("attack", false)
	attack_just_pressed = data.get("attack", false)
	spell_slot = data.get("spell", 0)
	interact_just_pressed = data.get("interact", false)
	inventory_just_pressed = data.get("inventory", false)


func serialize() -> Dictionary:
	return {
		"move_x": move_direction.x,
		"move_y": move_direction.y,
		"attack": attack_pressed,
		"spell": spell_slot,
		"interact": interact_just_pressed,
		"inventory": inventory_just_pressed,
	}


func clear_just_pressed() -> void:
	attack_just_pressed = false
	interact_just_pressed = false
	inventory_just_pressed = false
