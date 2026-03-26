extends Control

signal new_game_requested()
signal continue_requested()

@onready var _continue_btn: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	# Only show Continue if a save file exists.
	_continue_btn.visible = FileAccess.file_exists("user://savegame.json")

func _on_new_game_pressed() -> void:
	new_game_requested.emit()

func _on_continue_pressed() -> void:
	continue_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
