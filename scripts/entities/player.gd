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
@onready var _body: Polygon2D = $Body

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
	health_component.died.connect(EventBus.player_died.emit)
	# Ensure this camera is the active 2D camera immediately.
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()


func _physics_process(delta: float) -> void:
	# Delegate all movement to the MovementComponent.
	movement_component.move(delta)

	# Track the last non-zero movement direction so attacks feel intentional.
	var dir: Vector2 = movement_component.get_input_vector()
	if dir != Vector2.ZERO:
		_facing = dir
		# Rotate body polygon so the arrow always points the way the player faces.
		# Polygon default points up (-Y); angle() + 90° aligns it to facing.
		_body.rotation = _facing.angle() + PI * 0.5


func _process(_delta: float) -> void:
	_handle_attack_input()
	_handle_spell_input()
	_handle_interact_input()

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Load race and optional class data, applying all stats/items/spells.
## Call this after adding the player to the scene tree.
func initialize(race_id: String, class_id: String = "") -> void:
	var race_data: Dictionary = DataLoader.load_race(race_id)
	if race_data.is_empty():
		push_warning("Player.initialize: no race data found for '%s'" % race_id)
		return

	# Apply core stats from race base_stats (nested under "base_stats" key).
	var base_stats: Dictionary = race_data.get("base_stats", {})
	stats_component.apply_race_data(base_stats)
	if base_stats.has("hp"):
		health_component.set_max_hp(int(base_stats["hp"]))
	var spellbook: SpellbookComponent = get_node_or_null("SpellbookComponent")
	if spellbook and base_stats.has("mana"):
		spellbook.max_mana = int(base_stats["mana"])
		spellbook.current_mana = spellbook.max_mana

	GameState.player_data["race"] = race_id

	if class_id.is_empty():
		return

	var class_data: Dictionary = DataLoader.load_class(class_id)
	if class_data.is_empty():
		push_warning("Player.initialize: no class data found for '%s'" % class_id)
		return

	GameState.player_data["class"] = class_id

	# Apply class stat modifiers (strength, dexterity, intelligence, vitality).
	var mods: Dictionary = class_data.get("stat_modifiers", {})
	for stat in ["strength", "dexterity", "intelligence", "vitality"]:
		var val: int = int(mods.get(stat, 0))
		if val != 0:
			stats_component.add_modifier(stat, class_id, val)

	# Apply mana bonus from class (e.g. mage +20 mana).
	var mana_bonus: int = int(mods.get("mana", 0))
	if mana_bonus != 0 and spellbook != null:
		spellbook.max_mana += mana_bonus
		spellbook.current_mana = spellbook.max_mana

	# Learn starting spells.
	if spellbook != null:
		for spell_id in class_data.get("starting_spells", []):
			spellbook.learn_spell(spell_id)

	# Give starting items.
	var inventory: InventoryComponent = get_node_or_null("InventoryComponent")
	if inventory != null:
		for item_id in class_data.get("starting_items", []):
			inventory.add_item(item_id)

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
