extends Control

signal new_game_requested()

func _ready() -> void:
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_new_game_pressed() -> void:
	new_game_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
