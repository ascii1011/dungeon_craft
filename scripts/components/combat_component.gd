## CombatComponent
## Handles melee attack logic for an entity.
## Performs an area scan in the attack direction and applies damage via target HealthComponents.
class_name CombatComponent
extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Radius of the melee hit-scan area in pixels.
@export var attack_range: float = 60.0

## Minimum seconds between attacks.
@export var attack_cooldown: float = 0.8

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted every time an attack is initiated, regardless of whether it hits.
signal attack_performed(direction: Vector2)

## Emitted once per target that is struck during a single attack.
signal hit_target(target: Node, damage: int)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _cooldown_timer: float = 0.0

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true when enough time has elapsed since the last attack.
func can_attack() -> bool:
	return _cooldown_timer <= 0.0


## Execute a melee attack in the given direction.
## Scans a circle at (parent position + direction * attack_range / 2) with
## radius attack_range / 2 and calls take_damage on any hit entity's
## HealthComponent that is not the attacker itself.
func perform_attack(direction: Vector2) -> void:
	if not can_attack():
		return

	_cooldown_timer = attack_cooldown
	attack_performed.emit(direction)

	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		push_error("CombatComponent: parent is not a Node2D")
		return

	# Determine damage from a sibling StatsComponent if available.
	var damage: int = _get_attack_damage()

	# Build the hit region: a small circle ahead of the attacker.
	var hit_origin: Vector2 = parent.global_position + direction * (attack_range * 0.5)
	var hit_radius: float = attack_range * 0.5

	# Use the scene tree to find candidate nodes. We look for nodes that have
	# a HealthComponent child and whose global_position is within range.
	var space_state: PhysicsDirectSpaceState2D = parent.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = hit_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, hit_origin)
	query.collision_mask = 0xFFFFFFFF  # Hit anything; filter by HealthComponent below.

	var results: Array = space_state.intersect_shape(query)
	for result in results:
		var collider: Object = result.get("collider")
		if collider == null or collider == parent:
			continue
		# Look for a HealthComponent on the collider or its owner.
		var health: HealthComponent = _find_health_component(collider as Node)
		if health != null and not health.is_dead():
			health.take_damage(damage)
			hit_target.emit(collider, damage)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Attempt to read attack power from a sibling StatsComponent.
## Falls back to a fixed default if none is present.
func _get_attack_damage() -> int:
	var stats: StatsComponent = _find_sibling(StatsComponent) as StatsComponent
	if stats != null:
		return stats.get_attack_power()
	return 10  # Default melee damage when no StatsComponent exists.


## Search upwards through node hierarchy for a HealthComponent.
func _find_health_component(node: Node) -> HealthComponent:
	if node == null:
		return null
	# Check direct children first (components are children of entity root).
	for child in node.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	# Then check if the node itself is a HealthComponent.
	if node is HealthComponent:
		return node as HealthComponent
	return null


## Find a sibling node of the given class under the same parent.
func _find_sibling(type) -> Node:
	var p: Node = get_parent()
	if p == null:
		return null
	for child in p.get_children():
		if is_instance_of(child, type):
			return child
	return null
