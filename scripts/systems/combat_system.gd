## CombatSystem
## Handles damage resolution, spell damage, and healing between entities.
## Not registered as an autoload — instantiated by GameState or the main scene.
class_name CombatSystem
extends Node

signal damage_dealt(attacker: Node, target: Node, amount: int, damage_type: String)
signal heal_applied(target: Node, amount: int)


## Resolves physical damage from attacker to target.
## Formula: final = max(1, raw_damage + attacker_bonus - target_defense)
## Calls target's HealthComponent.take_damage(final) and returns final damage dealt.
func resolve_damage(attacker: Node, target: Node, raw_damage: int) -> int:
	var attacker_bonus: int = 0
	var target_defense: int = 0

	var attacker_stats: Node = attacker.get_node_or_null("StatsComponent")
	if attacker_stats != null and attacker_stats.has_method("get_attack_power"):
		attacker_bonus = attacker_stats.get_attack_power()

	var target_stats: Node = target.get_node_or_null("StatsComponent")
	if target_stats != null and target_stats.has_method("get_defense"):
		target_defense = target_stats.get_defense()

	var final_damage: int = max(1, raw_damage + attacker_bonus - target_defense)

	var health_component: Node = target.get_node("HealthComponent")
	health_component.take_damage(final_damage)

	damage_dealt.emit(attacker, target, final_damage, "physical")
	return final_damage


## Resolves spell damage from caster to target using spell_data dictionary.
## Uses spell_data["damage"] + caster's spell_power bonus.
## Returns final damage dealt.
func resolve_spell_damage(caster: Node, target: Node, spell_data: Dictionary) -> int:
	var base_damage: int = spell_data.get("damage", 0)
	var spell_power_bonus: int = 0

	var caster_stats: Node = caster.get_node_or_null("StatsComponent")
	if caster_stats != null:
		spell_power_bonus = caster_stats.spell_power if "spell_power" in caster_stats else 0

	var damage_type: String = spell_data.get("damage_type", "magic")
	var final_damage: int = max(1, base_damage + spell_power_bonus)

	var health_component: Node = target.get_node("HealthComponent")
	health_component.take_damage(final_damage)

	damage_dealt.emit(caster, target, final_damage, damage_type)
	return final_damage


## Applies healing to the target via HealthComponent.heal(amount).
func apply_heal(target: Node, amount: int) -> void:
	var health_component: Node = target.get_node("HealthComponent")
	health_component.heal(amount)
	heal_applied.emit(target, amount)
