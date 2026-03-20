## Enemy
## Top-down CharacterBody2D enemy entity.
## Assembles all core components, delegates AI to EnemyAI, and responds to
## death by notifying the EventBus and freeing itself after a short delay.
class_name Enemy
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Component references (resolved at runtime via @onready)
# ---------------------------------------------------------------------------

@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var enemy_ai: EnemyAI = $EnemyAI
@onready var sprite: Sprite2D = $Sprite2D

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## String identifier matching the key used in DataLoader (e.g. "goblin").
var enemy_id: String = "goblin"

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemy")
	health_component.died.connect(_on_died)


# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Load enemy data by id, apply stats, and register with the enemy group.
## Call this after adding the enemy to the scene tree.
func initialize(id: String) -> void:
	enemy_id = id
	var data: Dictionary = DataLoader.load_enemy(id)
	if data.is_empty():
		push_warning("Enemy.initialize: no data found for '%s'" % id)
		return

	# Apply HP from data.
	var stats_data: Dictionary = data.get("stats", {}) as Dictionary
	if stats_data.has("hp"):
		var hp: int = int(stats_data["hp"])
		health_component.set_max_hp(hp)
		health_component.current_hp = hp

	# Apply stat overrides from data if the fields are recognised.
	if stats_data.has("attack"):
		stats_component.strength = int(stats_data["attack"])
	if stats_data.has("defense"):
		stats_component.vitality = int(stats_data["defense"])

	# Apply AI tuning from data.
	if stats_data.has("aggro_range"):
		enemy_ai.aggro_range = float(stats_data["aggro_range"])
	if stats_data.has("attack_range"):
		enemy_ai.attack_range = float(stats_data["attack_range"])
		combat_component.attack_range = float(stats_data["attack_range"])
	if stats_data.has("attack_speed"):
		enemy_ai.attack_cooldown = float(stats_data["attack_speed"])
		combat_component.attack_cooldown = float(stats_data["attack_speed"])
	if stats_data.has("speed"):
		enemy_ai.chase_speed = float(stats_data["speed"])

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_died() -> void:
	# Transition the AI into the DEAD state so it stops processing.
	enemy_ai.enter_state(EnemyAI.State.DEAD)

	# Notify the rest of the game via EventBus.
	EventBus.enemy_died.emit(enemy_id, global_position)

	# Play a simple death visual (modulate to red then fade) and queue_free.
	# If an AnimationPlayer is present a death animation can be triggered here.
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.8)
	tween.tween_callback(queue_free)
