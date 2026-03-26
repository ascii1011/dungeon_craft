extends CanvasLayer

@onready var hp_bar: ProgressBar = $Control/TopLeft/HPRow/HPBar
@onready var mana_bar: ProgressBar = $Control/TopLeft/ManaRow/ManaBar
@onready var hp_label: Label = $Control/TopLeft/HPRow/HPLabel
@onready var mana_label: Label = $Control/TopLeft/ManaRow/ManaLabel
@onready var gold_label: Label = $Control/TopRight/GoldLabel
@onready var xp_label: Label = $Control/TopRight/XPLabel
@onready var hotbar: HBoxContainer = $Control/Hotbar
@onready var minimap_container: Control = $Control/MinimapContainer

func _ready() -> void:
	if EventBus.has_signal("player_health_changed"):
		EventBus.player_health_changed.connect(_on_player_health_changed)
	if EventBus.has_signal("gold_changed"):
		EventBus.gold_changed.connect(update_gold)
	if EventBus.has_signal("xp_gained"):
		EventBus.xp_gained.connect(update_xp)

func _on_player_health_changed(current: int, max_val: int) -> void:
	update_hp(current, max_val)

func update_hp(current: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = current
	hp_label.text = "%d / %d" % [current, max_val]

func update_mana(current: int, max_val: int) -> void:
	mana_bar.max_value = max_val
	mana_bar.value = current
	mana_label.text = "%d / %d" % [current, max_val]

func update_gold(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func update_xp(amount: int) -> void:
	xp_label.text = "XP: %d" % amount

func set_spell_slot(slot: int, spell_id: String, on_cooldown: bool) -> void:
	# slot is 1-indexed
	if slot < 1 or slot > hotbar.get_child_count():
		return
	var slot_node = hotbar.get_child(slot - 1)
	if slot_node == null:
		return
	# Find the spell label within the slot panel
	var spell_label: Label = null
	for child in slot_node.get_children():
		if child is Label and child.name != "KeyLabel":
			spell_label = child
			break
	if spell_label == null:
		# Fallback: look for any child Label beyond the key label
		for child in slot_node.get_children():
			if child is Label:
				spell_label = child
				break
	if spell_label:
		spell_label.text = spell_id if not on_cooldown else "(cd)"

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false
