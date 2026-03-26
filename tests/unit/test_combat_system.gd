## GUT unit tests for CombatSystem.
## Tests damage resolution formula, spell damage, and heal delegation.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers — build minimal mock nodes with component children
# ---------------------------------------------------------------------------

class MockStats extends Node:
	var attack_power: int = 0
	var defense: int = 0
	var spell_power: int = 0

	func _init(atk: int = 0, def: int = 0, sp: int = 0) -> void:
		name = "StatsComponent"
		attack_power = atk
		defense = def
		spell_power = sp


class MockHealth extends Node:
	var last_damage: int = 0
	var last_heal: int = 0

	func _init() -> void:
		name = "HealthComponent"

	func take_damage(amount: int) -> void:
		last_damage = amount

	func heal(amount: int) -> void:
		last_heal = amount


func _make_entity(attack_power: int = 0, defense: int = 0, spell_power: int = 0) -> Node:
	var entity := Node.new()
	entity.add_child(MockStats.new(attack_power, defense, spell_power))
	entity.add_child(MockHealth.new())
	return entity


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

var _system: CombatSystem

func before_each() -> void:
	_system = CombatSystem.new()
	add_child_autofree(_system)


# ---------------------------------------------------------------------------
# resolve_damage tests
# ---------------------------------------------------------------------------

func test_resolve_damage_basic_positive() -> void:
	var attacker := add_child_autofree(_make_entity(5, 0))
	var target := add_child_autofree(_make_entity(0, 2))

	var result: int = _system.resolve_damage(attacker, target, 10)

	# 10 + 5 (attack_power) - 2 (defense) = 13
	assert_eq(result, 13, "resolve_damage should apply attack bonus and defense reduction")


func test_resolve_damage_no_stats_components() -> void:
	# Entities with no StatsComponent — bonuses default to 0
	var attacker := add_child_autofree(_make_entity(0, 0))
	var target := add_child_autofree(_make_entity(0, 0))

	var result: int = _system.resolve_damage(attacker, target, 7)

	assert_eq(result, 7, "resolve_damage with no stat bonuses should equal raw_damage")


func test_resolve_damage_minimum_one() -> void:
	# raw_damage + attacker_bonus - defense would be <= 0
	var attacker := add_child_autofree(_make_entity(0, 0))
	var target := add_child_autofree(_make_entity(0, 50))

	var result: int = _system.resolve_damage(attacker, target, 3)

	assert_eq(result, 1, "resolve_damage should never return less than 1")


func test_resolve_damage_calls_health_component() -> void:
	var attacker := add_child_autofree(_make_entity(0, 0))
	var target := add_child_autofree(_make_entity(0, 0))

	_system.resolve_damage(attacker, target, 8)

	var health: MockHealth = target.get_node("HealthComponent") as MockHealth
	assert_eq(health.last_damage, 8, "resolve_damage should call HealthComponent.take_damage with final amount")


func test_resolve_damage_defense_reduction() -> void:
	var attacker := add_child_autofree(_make_entity(0, 0))
	var target := add_child_autofree(_make_entity(0, 4))

	var result: int = _system.resolve_damage(attacker, target, 10)

	assert_eq(result, 6, "defense should reduce raw damage by its value")


func test_resolve_damage_emits_signal() -> void:
	var attacker := add_child_autofree(_make_entity(0, 0))
	var target := add_child_autofree(_make_entity(0, 0))

	watch_signals(_system)
	_system.resolve_damage(attacker, target, 5)

	assert_signal_emitted(_system, "damage_dealt", "damage_dealt signal should fire after resolve_damage")


# ---------------------------------------------------------------------------
# resolve_spell_damage tests
# ---------------------------------------------------------------------------

func test_resolve_spell_damage_uses_spell_data_damage() -> void:
	var caster := add_child_autofree(_make_entity(0, 0, 0))
	var target := add_child_autofree(_make_entity(0, 0))

	var spell_data := {"damage": 20, "damage_type": "fire"}
	var result: int = _system.resolve_spell_damage(caster, target, spell_data)

	assert_eq(result, 20, "resolve_spell_damage should use spell_data['damage'] as base")


func test_resolve_spell_damage_adds_spell_power() -> void:
	var caster := add_child_autofree(_make_entity(0, 0, 10))
	var target := add_child_autofree(_make_entity(0, 0))

	var spell_data := {"damage": 15, "damage_type": "fire"}
	var result: int = _system.resolve_spell_damage(caster, target, spell_data)

	assert_eq(result, 25, "resolve_spell_damage should add caster spell_power to base damage")


func test_resolve_spell_damage_minimum_one() -> void:
	var caster := add_child_autofree(_make_entity(0, 0, 0))
	var target := add_child_autofree(_make_entity(0, 0))

	var spell_data := {"damage": 0, "damage_type": "arcane"}
	var result: int = _system.resolve_spell_damage(caster, target, spell_data)

	assert_eq(result, 1, "resolve_spell_damage minimum should be 1")


func test_resolve_spell_damage_calls_health_component() -> void:
	var caster := add_child_autofree(_make_entity(0, 0, 5))
	var target := add_child_autofree(_make_entity(0, 0))

	var spell_data := {"damage": 10, "damage_type": "fire"}
	_system.resolve_spell_damage(caster, target, spell_data)

	var health: MockHealth = target.get_node("HealthComponent") as MockHealth
	assert_eq(health.last_damage, 15, "resolve_spell_damage should call HealthComponent.take_damage")


# ---------------------------------------------------------------------------
# apply_heal tests
# ---------------------------------------------------------------------------

func test_apply_heal_calls_health_component() -> void:
	var target := add_child_autofree(_make_entity(0, 0))

	_system.apply_heal(target, 30)

	var health: MockHealth = target.get_node("HealthComponent") as MockHealth
	assert_eq(health.last_heal, 30, "apply_heal should call HealthComponent.heal with the given amount")


func test_apply_heal_emits_signal() -> void:
	var target := add_child_autofree(_make_entity(0, 0))

	watch_signals(_system)
	_system.apply_heal(target, 10)

	assert_signal_emitted(_system, "heal_applied", "heal_applied signal should fire after apply_heal")
