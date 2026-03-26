extends GutTest

# Integration test: full player -> attack -> enemy -> death chain

var combat_system: CombatSystem
var attacker: Node       # mock entity with StatsComponent child
var target: Node         # mock entity with HealthComponent + StatsComponent children
var target_health: HealthComponent
var target_stats: StatsComponent


func before_each() -> void:
	combat_system = CombatSystem.new()
	add_child_autofree(combat_system)

	# Build a mock attacker node with a StatsComponent child
	attacker = Node.new()
	var attacker_stats := StatsComponent.new()
	attacker_stats.name = "StatsComponent"
	attacker_stats.strength = 10
	attacker.add_child(attacker_stats)
	add_child_autofree(attacker)

	# Build a mock target node with HealthComponent + StatsComponent children
	target = Node.new()
	target_health = HealthComponent.new()
	target_health.name = "HealthComponent"
	target_health.max_hp = 30
	target_health.current_hp = 30
	target_stats = StatsComponent.new()
	target_stats.name = "StatsComponent"
	target_stats.vitality = 5
	target.add_child(target_health)
	target.add_child(target_stats)
	add_child_autofree(target)


func test_player_attack_reduces_enemy_hp() -> void:
	var hp_before: int = target_health.current_hp
	combat_system.resolve_damage(attacker, target, 10)
	assert_lt(target_health.current_hp, hp_before, "Enemy HP should decrease after player attack")


func test_enemy_dies_when_hp_reaches_zero() -> void:
	target_health.take_damage(target_health.current_hp)
	assert_true(target_health.is_dead(), "Enemy should be dead when HP reaches zero")


func test_enemy_died_signal_propagates() -> void:
	# Use a Dictionary as a mutable reference so the lambda can update outer scope
	var result := {"emitted": false, "enemy_id": ""}

	var mock_enemy := Node.new()
	mock_enemy.name = "MockEnemy"
	var mock_hp := HealthComponent.new()
	mock_hp.name = "HealthComponent"
	mock_hp.max_hp = 10
	mock_hp.current_hp = 10
	mock_enemy.add_child(mock_hp)
	add_child_autofree(mock_enemy)

	var enemy_id := "goblin_01"
	# Wire died -> EventBus.enemy_died (mimicking enemy.gd)
	mock_hp.died.connect(func() -> void:
		EventBus.enemy_died.emit(enemy_id, Vector2.ZERO)
	)

	var spy := func(eid: String, _pos: Vector2) -> void:
		result["emitted"] = true
		result["enemy_id"] = eid
	EventBus.enemy_died.connect(spy)

	mock_hp.take_damage(10)

	assert_true(result["emitted"], "EventBus.enemy_died signal should have been emitted")
	assert_eq(result["enemy_id"], "goblin_01", "Signal should carry the correct enemy_id")

	EventBus.enemy_died.disconnect(spy)


func test_defense_reduces_incoming_damage() -> void:
	# vitality=50 -> get_defense()=40, raw_damage=20 -> final = max(1, 20+bonus-40)
	# With default attacker strength=10, get_attack_power()=25, final=max(1,5)=5 < 20
	target_stats.vitality = 50
	var raw_damage: int = 20
	combat_system.resolve_damage(attacker, target, raw_damage)
	var actual_damage: int = target_health.max_hp - target_health.current_hp
	assert_lt(actual_damage, raw_damage, "Defense should reduce incoming damage below raw damage")


func test_minimum_damage_is_one() -> void:
	target_stats.vitality = 9999
	var hp_before: int = target_health.current_hp
	combat_system.resolve_damage(attacker, target, 10)
	var actual_damage: int = hp_before - target_health.current_hp
	assert_gte(actual_damage, 1, "Minimum damage should always be at least 1")
