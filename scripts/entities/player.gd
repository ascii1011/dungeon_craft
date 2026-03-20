## Player
## Top-down CharacterBody2D player entity.
## Assembles all core components and routes input to them each frame.
class_name Player
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Component references (resolved at runtime via @onready)
# ---------------------------------------------------------------------------

@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Direction the player is facing (used for attacks when no stick input exists).
var _facing: Vector2 = Vector2.DOWN

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Connect the death signal to the global EventBus so the game can react.
	health_component.died.connect(EventBus.player_died)


func _physics_process(delta: float) -> void:
	# Delegate all movement to the MovementComponent.
	movement_component.move(delta)

	# Track the last non-zero movement direction so attacks feel intentional.
	var dir: Vector2 = movement_component.get_input_vector()
	if dir != Vector2.ZERO:
		_facing = dir


func _process(_delta: float) -> void:
	_handle_attack_input()
	_handle_spell_input()
	_handle_interact_input()

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Load a race by ID and apply its stat bonuses to the StatsComponent.
## Call this after adding the player to the scene tree.
func initialize(race_id: String) -> void:
	var race_data: Dictionary = DataLoader.load_race(race_id)
	if race_data.is_empty():
		push_warning("Player.initialize: no race data found for '%s'" % race_id)
		return
	stats_component.apply_race_data(race_data)

# ---------------------------------------------------------------------------
# Private input handlers
# ---------------------------------------------------------------------------

func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack"):
		combat_component.perform_attack(_facing)


func _handle_spell_input() -> void:
	# Spell inputs broadcast through EventBus so spell systems can respond
	# without the player needing direct references to them.
	if Input.is_action_just_pressed("spell_1"):
		EventBus.spell_cast.emit(1, self)
	elif Input.is_action_just_pressed("spell_2"):
		EventBus.spell_cast.emit(2, self)
	elif Input.is_action_just_pressed("spell_3"):
		EventBus.spell_cast.emit(3, self)


func _handle_interact_input() -> void:
	if Input.is_action_just_pressed("interact"):
		EventBus.player_interact.emit(self)
