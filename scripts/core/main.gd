extends Node

@onready var world_scene_container: Node = $WorldContainer
@onready var _hud: Node = $HUD/HUD
@onready var _main_menu: Node = $MainMenu/MainMenu
@onready var _main_menu_layer: CanvasLayer = $MainMenu
@onready var _char_creation: Node = $CharacterCreation
@onready var _pause_overlay: Node = $PauseOverlay

var _current_world: Node = null
var _player: Node = null
var _game_over_canvas: CanvasLayer = null
var _game_over_label: Label = null

var _save_system: SaveSystem = null


func _ready() -> void:
	_save_system = SaveSystem.new()
	add_child(_save_system)

	_main_menu.new_game_requested.connect(_on_new_game_requested)
	_main_menu.continue_requested.connect(_on_continue_requested)
	_char_creation.character_confirmed.connect(_on_character_confirmed)


# ---------------------------------------------------------------------------
# Menu flow
# ---------------------------------------------------------------------------

func _on_new_game_requested() -> void:
	_main_menu_layer.visible = false
	_char_creation.visible = true


func _on_continue_requested() -> void:
	_main_menu_layer.visible = false
	_start_dungeon("", "")  # stats/inventory/spells all restored from save below
	_load_save()


func _on_character_confirmed(race_id: String, class_id: String) -> void:
	_char_creation.visible = false
	_start_dungeon(race_id, class_id)


# ---------------------------------------------------------------------------
# Game start / load
# ---------------------------------------------------------------------------

func _start_dungeon(race_id: String, class_id: String) -> void:
	# Clear any existing world.
	if _current_world != null:
		_current_world.queue_free()
		_current_world = null

	# Load and wire DungeonManager before adding to tree.
	var world_res: PackedScene = load("res://scenes/world/dungeon_floor_01.tscn")
	_current_world = world_res.instantiate()
	world_scene_container.add_child(_current_world)

	var dm: DungeonManager = _current_world.get_node_or_null("DungeonManager") as DungeonManager
	if dm != null:
		dm.load_zone("dungeon_floor_01", _current_world)
		dm.zone_exit_reached.connect(_on_zone_exit_reached)

	# Instantiate and place the player.
	var player_res: PackedScene = load("res://scenes/entities/player.tscn")
	_player = player_res.instantiate()

	var spawn_pos := Vector2(80, 80)
	if dm != null:
		spawn_pos = dm.get_player_spawn()

	_player.global_position = spawn_pos
	_player.add_to_group("player")

	var entities_node: Node = _current_world.get_node_or_null("Entities")
	if entities_node == null:
		entities_node = _current_world
	entities_node.add_child(_player)

	# Apply race + class (skipped when loading from save, which restores state directly).
	if not race_id.is_empty():
		_player.initialize(race_id, class_id)

	# Wire HUD.
	_hud.show_hud()
	if _player.has_node("HealthComponent"):
		var hc: Node = _player.get_node("HealthComponent")
		hc.health_changed.connect(_hud.update_hp)
		hc.died.connect(_on_player_died)
	elif _player.has_signal("died"):
		_player.died.connect(_on_player_died)
	if _player.has_node("SpellbookComponent"):
		var sb: Node = _player.get_node("SpellbookComponent")
		sb.mana_changed.connect(_hud.update_mana)


func _load_save() -> void:
	if _player != null and _save_system != null:
		_save_system.load_game(_player)


# ---------------------------------------------------------------------------
# Zone exit
# ---------------------------------------------------------------------------

func _on_zone_exit_reached(_target_zone: String) -> void:
	# V1: no floor 2 yet — show "Dungeon Cleared!" and return to menu.
	get_tree().paused = true
	var canvas := CanvasLayer.new()
	canvas.name = "DungeonClearedLayer"
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(vbox)
	var lbl := Label.new()
	lbl.text = "Dungeon Cleared!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 56)
	vbox.add_child(lbl)
	var btn := Button.new()
	btn.text = "Return to Menu"
	btn.pressed.connect(_on_return_to_menu)
	vbox.add_child(btn)
	add_child(canvas)


func _on_return_to_menu() -> void:
	get_tree().paused = false
	# Clear the cleared overlay.
	var cleared := get_node_or_null("DungeonClearedLayer")
	if cleared:
		cleared.queue_free()
	# Tear down world and player.
	if _current_world != null:
		_current_world.queue_free()
		_current_world = null
	_player = null
	_hud.hide_hud()
	_main_menu_layer.visible = true
	# Refresh Continue button visibility.
	_main_menu._continue_btn.visible = FileAccess.file_exists("user://savegame.json")


# ---------------------------------------------------------------------------
# Player death / game over
# ---------------------------------------------------------------------------

func _on_player_died() -> void:
	get_tree().paused = true
	if _game_over_canvas == null:
		_game_over_canvas = CanvasLayer.new()
		_game_over_canvas.name = "GameOverLayer"
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		_game_over_label = Label.new()
		_game_over_label.text = "GAME OVER"
		_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_game_over_label.add_theme_font_size_override("font_size", 64)
		vbox.add_child(_game_over_label)
		var restart_btn := Button.new()
		restart_btn.text = "Restart"
		restart_btn.pressed.connect(_restart_game)
		vbox.add_child(restart_btn)
		_game_over_canvas.add_child(vbox)
		add_child(_game_over_canvas)
	else:
		_game_over_canvas.visible = true


func _restart_game() -> void:
	get_tree().paused = false
	if _game_over_canvas != null:
		_game_over_canvas.queue_free()
		_game_over_canvas = null
		_game_over_label = null
	_main_menu_layer.visible = false
	_char_creation.visible = true


# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

func pause_game() -> void:
	GameState.pause()
	_pause_overlay.visible = true


func resume_game() -> void:
	GameState.resume()
	_pause_overlay.visible = false
