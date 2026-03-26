extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed(reason: String)
signal game_state_received(state: Dictionary)

var is_multiplayer: bool = false
var local_peer_id: int = 1
var connected_peers: Array[int] = []


func host_game(port: int = 7777) -> void:
	push_warning("Multiplayer not yet implemented")


func join_game(address: String, port: int = 7777) -> void:
	push_warning("Multiplayer not yet implemented")


func disconnect_from_game() -> void:
	push_warning("Multiplayer not yet implemented")


func send_input(input_data: Dictionary) -> void:
	pass


func broadcast_state(state_data: Dictionary) -> void:
	pass


func is_host() -> bool:
	return true


func get_ping(peer_id: int) -> int:
	return 0
