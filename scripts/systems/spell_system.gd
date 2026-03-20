## SpellSystem
## Handles spell casting logic, reading spell data from DataLoader,
## managing mana/cooldown checks, projectile spawning, and spell effects.
class_name SpellSystem
extends Node

signal spell_cast_failed(reason: String)
signal projectile_spawned(spell_id: String, position: Vector2)

## Reference to CombatSystem for applying damage/heals.
## Set this after instantiation, or the system will attempt get_node fallback.
var combat_system: CombatSystem = null


## Attempts to cast spell_id for caster toward target_position.
## Returns true if the cast succeeded, false otherwise.
func cast_spell(caster: Node, spell_id: String, target_position: Vector2) -> bool:
	# Load spell data
	var spell_data: Dictionary = DataLoader.load_spell(spell_id)
	if spell_data.is_empty():
		spell_cast_failed.emit("Unknown spell: %s" % spell_id)
		return false

	# Check caster has a SpellbookComponent
	var spellbook: Node = caster.get_node_or_null("SpellbookComponent")
	if spellbook == null:
		spell_cast_failed.emit("Caster has no SpellbookComponent")
		return false

	# Check spell is known
	if not spellbook.knows_spell(spell_id):
		spell_cast_failed.emit("Spell not known: %s" % spell_id)
		return false

	# Check cooldown
	if spellbook.is_on_cooldown(spell_id):
		spell_cast_failed.emit("Spell on cooldown: %s" % spell_id)
		return false

	# Check mana cost
	var mana_cost: int = spell_data.get("mana_cost", 0)
	if not spellbook.has_mana(mana_cost):
		spell_cast_failed.emit("Not enough mana for: %s" % spell_id)
		return false

	# Deduct mana and start cooldown
	spellbook.spend_mana(mana_cost)
	var cooldown_duration: float = spell_data.get("cooldown", 0.0)
	spellbook.start_cooldown(spell_id, cooldown_duration)

	# Execute the spell effect
	_execute_spell(caster, spell_data, target_position)

	# Notify the event bus
	if EventBus.has_signal("spell_cast"):
		EventBus.emit_signal("spell_cast", spell_id, caster)

	return true


## Dispatches spell execution based on spell_data["type"].
func _execute_spell(caster: Node, spell_data: Dictionary, target_pos: Vector2) -> void:
	var spell_type: String = spell_data.get("type", "")
	match spell_type:
		"damage":
			_spawn_projectile(caster, spell_data, target_pos)
		"heal":
			var heal_amount: int = spell_data.get("heal_amount", spell_data.get("amount", 0))
			_get_combat_system().apply_heal(caster, heal_amount)
		"debuff":
			_apply_debuff(caster, spell_data, target_pos)
		"buff":
			_apply_buff(caster, spell_data)
		"utility":
			var utility_type: String = spell_data.get("utility_type", "")
			if utility_type == "blink" or spell_data.get("id", "") == "blink":
				_execute_blink(caster, spell_data, target_pos)
		_:
			push_warning("SpellSystem: unknown spell type '%s'" % spell_type)


## Creates a projectile Area2D node that travels toward target_pos.
## The projectile auto-deletes after traveling spell_data["range"] or on first hit.
func _spawn_projectile(caster: Node, spell_data: Dictionary, target_pos: Vector2) -> void:
	var spell_id: String = spell_data.get("id", "unknown")
	var projectile_speed: float = float(spell_data.get("projectile_speed", 300.0))
	var area_radius: float = float(spell_data.get("area_radius", 16.0))
	var spell_range: float = float(spell_data.get("range", 400.0))

	# Build the projectile node tree
	var projectile := Area2D.new()
	projectile.name = "Projectile_%s" % spell_id

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = area_radius
	collision.shape = circle
	projectile.add_child(collision)

	# Place at caster position
	var start_pos: Vector2 = caster.global_position if "global_position" in caster else Vector2.ZERO
	projectile.global_position = start_pos

	# Compute direction and embed travel data as metadata
	var direction: Vector2 = (target_pos - start_pos).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	projectile.set_meta("velocity", direction * projectile_speed)
	projectile.set_meta("range_remaining", spell_range)
	projectile.set_meta("spell_data", spell_data)
	projectile.set_meta("caster", caster)
	projectile.set_meta("hit", false)

	# Connect body_entered for hit detection
	projectile.body_entered.connect(_on_projectile_body_entered.bind(projectile))

	# Attach a script to handle movement via _process
	var script := GDScript.new()
	script.source_code = _get_projectile_script()
	script.reload()
	projectile.set_script(script)

	# Add to the same scene tree as the caster
	var parent: Node = caster.get_parent() if caster.get_parent() != null else caster
	parent.add_child(projectile)

	projectile_spawned.emit(spell_id, start_pos)


## Called when a projectile Area2D enters a body.
func _on_projectile_body_entered(body: Node, projectile: Area2D) -> void:
	if projectile.get_meta("hit", false):
		return
	var caster: Node = projectile.get_meta("caster")
	if body == caster:
		return
	projectile.set_meta("hit", true)

	var spell_data: Dictionary = projectile.get_meta("spell_data")
	if body.has_node("HealthComponent"):
		_get_combat_system().resolve_spell_damage(caster, body, spell_data)

	projectile.queue_free()


## Applies a debuff (movement speed reduction) to the nearest enemy in range.
func _apply_debuff(caster: Node, spell_data: Dictionary, _target_pos: Vector2) -> void:
	var effect_range: float = float(spell_data.get("range", 200.0))
	var slow_amount: float = float(spell_data.get("slow_amount", 0.5))
	var duration: float = float(spell_data.get("duration", 3.0))

	# Find nearest node with a MovementComponent in range
	var candidates: Array = _find_entities_in_range(caster, effect_range)
	if candidates.is_empty():
		return
	var nearest: Node = candidates[0]
	var movement: Node = nearest.get_node_or_null("MovementComponent")
	if movement != null and "speed" in movement:
		# Apply slow by reducing speed; store original for restoration via timer
		var original_speed: float = movement.speed
		movement.speed *= (1.0 - slow_amount)
		_start_restoration_timer(nearest, movement, "speed", original_speed, duration)


## Applies a stat buff to the caster for a duration.
func _apply_buff(caster: Node, spell_data: Dictionary) -> void:
	var duration: float = float(spell_data.get("duration", 5.0))
	var stat_modifier: Dictionary = spell_data.get("stat_modifier", {})
	var stats: Node = caster.get_node_or_null("StatsComponent")
	if stats == null or stat_modifier.is_empty():
		return
	for stat_name: String in stat_modifier.keys():
		if stat_name in stats:
			var delta_value = stat_modifier[stat_name]
			stats.set(stat_name, stats.get(stat_name) + delta_value)
			_start_restoration_timer_delta(stats, stat_name, -delta_value, duration)


## Teleports the caster toward target_pos up to the spell's effect distance.
func _execute_blink(caster: Node, spell_data: Dictionary, target_pos: Vector2) -> void:
	var blink_distance: float = float(spell_data.get("effect_distance", spell_data.get("range", 200.0)))
	if not "global_position" in caster:
		return
	var direction: Vector2 = (target_pos - caster.global_position).normalized()
	var dist_to_target: float = caster.global_position.distance_to(target_pos)
	var travel: float = min(blink_distance, dist_to_target)
	caster.global_position = caster.global_position + direction * travel


# --- Utility helpers ---

func _get_combat_system() -> CombatSystem:
	if combat_system != null:
		return combat_system
	# Fallback: try to find CombatSystem in the scene tree
	var cs: Node = get_tree().get_first_node_in_group("combat_system") if get_tree() else null
	if cs is CombatSystem:
		return cs
	push_error("SpellSystem: no CombatSystem available")
	return null


func _find_entities_in_range(caster: Node, range_dist: float) -> Array:
	var result: Array = []
	if not "global_position" in caster:
		return result
	var tree: SceneTree = get_tree()
	if tree == null:
		return result
	# Collect all nodes with HealthComponent that are not the caster
	var nodes: Array = tree.get_nodes_in_group("enemies")
	for node: Node in nodes:
		if node == caster:
			continue
		if "global_position" in node:
			var dist: float = caster.global_position.distance_to(node.global_position)
			if dist <= range_dist:
				result.append(node)
	# Sort by distance
	result.sort_custom(func(a: Node, b: Node) -> bool:
		return caster.global_position.distance_to(a.global_position) < caster.global_position.distance_to(b.global_position)
	)
	return result


## Creates a timer that restores a property on a node to original_value after duration.
func _start_restoration_timer(target_node: Node, property_holder: Node, property: String, original_value: Variant, duration: float) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(property_holder) and property in property_holder:
			property_holder.set(property, original_value)
		timer.queue_free()
	)
	target_node.add_child(timer)
	timer.start()


## Creates a timer that applies a delta to a stat after duration (for buff reversal).
func _start_restoration_timer_delta(property_holder: Node, property: String, delta_value: Variant, duration: float) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(property_holder) and property in property_holder:
			property_holder.set(property, property_holder.get(property) + delta_value)
		timer.queue_free()
	)
	property_holder.add_child(timer)
	timer.start()


## Returns GDScript source code for the projectile movement script.
## The projectile is freed after range is exhausted.
func _get_projectile_script() -> String:
	return """extends Area2D

func _process(delta: float) -> void:
	if get_meta("hit", false):
		return
	var vel: Vector2 = get_meta("velocity", Vector2.ZERO)
	var remaining: float = get_meta("range_remaining", 0.0)
	var move: Vector2 = vel * delta
	var dist: float = move.length()
	if dist >= remaining:
		queue_free()
		return
	set_meta("range_remaining", remaining - dist)
	global_position += move
"""
