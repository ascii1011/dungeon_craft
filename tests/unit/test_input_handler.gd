extends GutTest

var handler: Node


func before_each() -> void:
	handler = load("res://scripts/core/input_handler.gd").new()
	add_child_autofree(handler)


func test_is_local_by_default() -> void:
	assert_true(handler.is_local, "InputHandler should be local by default")


func test_peer_id_default_is_one() -> void:
	assert_eq(handler.peer_id, 1, "Default peer_id should be 1")


func test_move_direction_zero_by_default() -> void:
	assert_eq(handler.move_direction, Vector2.ZERO, "move_direction should be Vector2.ZERO by default")


func test_set_remote_input_updates_state() -> void:
	handler.set_remote_input({
		"move_x": 1.0,
		"move_y": 0.0,
		"attack": true,
		"spell": 2,
		"interact": false,
		"inventory": false,
	})
	assert_eq(handler.move_direction.x, 1.0, "move_direction.x should be 1.0")
	assert_true(handler.attack_pressed, "attack_pressed should be true")
	assert_eq(handler.spell_slot, 2, "spell_slot should be 2")


func test_serialize_returns_dict_with_required_keys() -> void:
	var result: Dictionary = handler.serialize()
	assert_has(result, "move_x", "serialize() must include 'move_x'")
	assert_has(result, "move_y", "serialize() must include 'move_y'")
	assert_has(result, "attack", "serialize() must include 'attack'")
	assert_has(result, "spell", "serialize() must include 'spell'")
	assert_has(result, "interact", "serialize() must include 'interact'")
	assert_has(result, "inventory", "serialize() must include 'inventory'")


func test_clear_just_pressed_resets_flags() -> void:
	handler.set_remote_input({
		"move_x": 0.0,
		"move_y": 0.0,
		"attack": true,
		"spell": 0,
		"interact": true,
		"inventory": true,
	})
	handler.clear_just_pressed()
	assert_false(handler.attack_just_pressed, "attack_just_pressed should be false after clear")
	assert_false(handler.interact_just_pressed, "interact_just_pressed should be false after clear")
	assert_false(handler.inventory_just_pressed, "inventory_just_pressed should be false after clear")
