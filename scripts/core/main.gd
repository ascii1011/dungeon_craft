extends Node

@onready var world_scene_container: Node = $WorldContainer
var _current_world: Node = null
var _player: Node = null

var _hud: Node = null
var _main_menu: Node = null
var _pause_overlay: Node = null
var _game_over_label: Label = null

func _ready() -> void:
	_hud = $HUD/HUD
	_main_menu = $MainMenu/MainMenu
	_pause_overlay = $PauseOverlay
	_show_main_menu()

func _show_main_menu() -> void:
	_main_menu.visible = true
	if not _main_menu.new_game_requested.is_connected(_on_new_game_requested):
		_main_menu.new_game_requested.connect(_on_new_game_requested)

func _on_new_game_requested() -> void:
	start_new_game()

func start_new_game() -> void:
	_main_menu.visible = false

	# Clear any existing world
	if _current_world != null:
		_current_world.queue_free()
		_current_world = null

	# Load dungeon floor
	var world_res = load("res://scenes/world/dungeon_floor_01.tscn")
	if world_res:
		_current_world = world_res.instantiate()
		world_scene_container.add_child(_current_world)

	# Instance player
	var player_res = load("res://scenes/entities/player.tscn")
	_player = player_res.instantiate()
	_player.initialize("human")

	# Get spawn position
	var spawn_pos := Vector2(80, 80)
	if _current_world != null and _current_world.has_node("DungeonManager"):
		var dm = _current_world.get_node("DungeonManager")
		if dm.has_method("get_spawn_position"):
			spawn_pos = dm.get_spawn_position()

	_player.global_position = spawn_pos
	_player.add_to_group("player")

	# Add player to world Entities node, or world_scene_container if not available
	var entities_node: Node = null
	if _current_world != null and _current_world.has_node("Entities"):
		entities_node = _current_world.get_node("Entities")
	elif _current_world != null:
		entities_node = _current_world
	else:
		entities_node = world_scene_container

	entities_node.add_child(_player)

	# Show HUD
	_hud.show_hud()

	# Connect player HealthComponent signals to HUD
	if _player.has_node("HealthComponent"):
		var health_comp = _player.get_node("HealthComponent")
		if health_comp.has_signal("health_changed"):
			health_comp.health_changed.connect(_hud.update_hp)
		if health_comp.has_signal("died"):
			health_comp.died.connect(_on_player_died)
	elif _player.has_signal("died"):
		_player.died.connect(_on_player_died)

	# Connect zone exit signal
	if _current_world != null and _current_world.has_signal("zone_exit_reached"):
		_current_world.zone_exit_reached.connect(_on_zone_exit_reached)

func _on_player_died() -> void:
	# Disable input
	get_tree().paused = true

	# Show Game Over label
	if _game_over_label == null:
		_game_over_label = Label.new()
		_game_over_label.text = "GAME OVER"
		_game_over_label.add_theme_font_size_override("font_size", 64)
		_game_over_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var canvas = CanvasLayer.new()
		canvas.name = "GameOverLayer"
		canvas.add_child(_game_over_label)
		add_child(canvas)

		# Restart button
		var restart_btn = Button.new()
		restart_btn.text = "Restart"
		restart_btn.pressed.connect(_restart_game)
		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(_game_over_label)
		vbox.add_child(restart_btn)
		canvas.add_child(vbox)
	else:
		_game_over_label.get_parent().get_parent().visible = true

func _restart_game() -> void:
	get_tree().paused = false
	if _game_over_label != null:
		_game_over_label.get_parent().get_parent().queue_free()
		_game_over_label = null
	start_new_game()

func _on_zone_exit_reached(target_zone: String) -> void:
	# Stub for v1: log the transition target
	push_warning("Zone exit reached — target: %s (stub, not yet implemented)" % target_zone)

func pause_game() -> void:
	GameState.pause()
	_pause_overlay.visible = true

func resume_game() -> void:
	GameState.resume()
	_pause_overlay.visible = false
