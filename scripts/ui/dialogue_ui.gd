extends Control

signal dialogue_action(action: String, data: Dictionary)

@onready var speaker_label: Label = $Panel/VBoxContainer/SpeakerLabel
@onready var dialogue_text: Label = $Panel/VBoxContainer/DialogueText
@onready var options_container: HBoxContainer = $Panel/VBoxContainer/OptionsContainer

var _dialogue_data: Dictionary = {}


func _ready() -> void:
	hide()


func show_dialogue(dialogue_data: Dictionary) -> void:
	_dialogue_data = dialogue_data
	speaker_label.text = dialogue_data.get("id", "???").capitalize()
	dialogue_text.text = dialogue_data.get("greeting", "...")
	_populate_options(dialogue_data.get("options", []))
	show()


func _populate_options(options: Array) -> void:
	# Remove any buttons from a previous interaction.
	for child in options_container.get_children():
		child.queue_free()

	for option in options:
		var btn := Button.new()
		btn.text = option.get("text", "")
		btn.pressed.connect(_on_option_pressed.bind(option))
		options_container.add_child(btn)


func _on_option_pressed(option: Dictionary) -> void:
	var action: String = option.get("action", "close")

	match action:
		"open_shop":
			hide()
			dialogue_action.emit(action, {"shop_id": option.get("shop_id", "")})
		"dialogue":
			# Show the response text and replace options with a single Back button.
			dialogue_text.text = option.get("response", "")
			_populate_options([{"text": "Back", "action": "back"}])
		"back":
			# Restore original greeting and options.
			dialogue_text.text = _dialogue_data.get("greeting", "...")
			_populate_options(_dialogue_data.get("options", []))
		"close", _:
			hide()
			dialogue_action.emit("close", {})
