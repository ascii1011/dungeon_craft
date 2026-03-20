extends GutTest

# Integration test: full player -> attack -> enemy -> death -> loot chain

var combat_system
var player_health: HealthComponent
var enemy_health: HealthComponent
var player_stats: StatsComponent
var enemy_stats: StatsComponent


func before_each() -> void:
	player_health = HealthComponent.new()
	player_health.max_hp = 100
	player_health.current_hp = 100
	add_child_autofree(player_health)

	enemy_health = HealthComponent.new()
	enemy_health.max_hp = 30
	enemy_health.current_hp = 30
	add_child_autofree(enemy_health)

	player_stats = StatsComponent.new()
	player_stats.strength = 10
	add_child_autofree(player_stats)

	enemy_stats = StatsComponent.new()
	enemy_stats.vitality = 5
	add_child_autofree(enemy_stats)

	combat_system = CombatSystem.new()
	add_child_autofree(combat_system)


func test_player_attack_reduces_enemy_hp() -> void:
	var hp_before: int = enemy_health.current_hp
	combat_system.resolve_damage(player_stats, enemy_health, enemy_stats)
	assert_lt(enemy_health.current_hp, hp_before, "Enemy HP should decrease after player attack")


func test_enemy_dies_when_hp_reaches_zero() -> void:
	# Deal enough damage to kill the enemy
	enemy_health.take_damage(enemy_health.current_hp)
	assert_true(enemy_health.is_dead(), "Enemy should be dead when HP reaches zero")


func test_enemy_died_signal_propagates() -> void:
	var signal_emitted := false
	var emitted_enemy_id: String = ""

	var spy := func(enemy_id: String) -> void:
		signal_emitted = true
		emitted_enemy_id = enemy_id

	EventBus.enemy_died.connect(spy)

	# Create a mock enemy node and attach HealthComponent
	var mock_enemy := Node.new()
	mock_enemy.set_meta("enemy_id", "goblin_01")
	var mock_enemy_health := HealthComponent.new()
	mock_enemy_health.max_hp = 10
	mock_enemy_health.current_hp = 10
	mock_enemy.add_child(mock_enemy_health)
	add_child_autofree(mock_enemy)

	mock_enemy_health.take_damage(10)

	assert_true(signal_emitted, "EventBus.enemy_died signal should have been emitted")
	assert_eq(emitted_enemy_id, "goblin_01", "Signal should carry the correct enemy_id")

	EventBus.enemy_died.disconnect(spy)


func test_defense_reduces_incoming_damage() -> void:
	# Give enemy high defense and compare raw vs actual damage
	enemy_stats.vitality = 50
	var raw_damage: int = player_stats.strength
	combat_system.resolve_damage(player_stats, enemy_health, enemy_stats)
	var actual_damage: int = enemy_health.max_hp - enemy_health.current_hp
	assert_lt(actual_damage, raw_damage, "Defense should reduce incoming damage below raw damage")


func test_minimum_damage_is_one() -> void:
	# Set defense so high that it would normally negate all damage
	enemy_stats.vitality = 9999
	var hp_before: int = enemy_health.current_hp
	combat_system.resolve_damage(player_stats, enemy_health, enemy_stats)
	var actual_damage: int = hp_before - enemy_health.current_hp
	assert_gte(actual_damage, 1, "Minimum damage should always be at least 1")
