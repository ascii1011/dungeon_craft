## HealthComponent
## Manages hit points for any entity. Attach as a child node.
## Emits health_changed whenever HP changes, and died when HP reaches zero.
class_name HealthComponent
extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var max_hp: int = 100
@export var current_hp: int = 100

## HP regenerated per second. Set to 0.0 to disable regen.
@export var regen_per_second: float = 0.0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted whenever current HP changes. Carries new current and max values.
signal health_changed(current: int, max: int)

## Emitted once when the entity's HP reaches zero.
signal died()

# Internal flag so we only emit died() once per death event.
var _is_dead: bool = false

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Clamp current_hp in case exported values are inconsistent.
	current_hp = clampi(current_hp, 0, max_hp)
	_is_dead = current_hp == 0


func _process(delta: float) -> void:
	# Apply passive HP regeneration each frame (skip if dead or regen disabled).
	if _is_dead or regen_per_second <= 0.0:
		return
	if current_hp < max_hp:
		var new_hp: int = mini(current_hp + int(regen_per_second * delta), max_hp)
		if new_hp != current_hp:
			current_hp = new_hp
			health_changed.emit(current_hp, max_hp)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Reduce HP by amount. Clamps to 0. Triggers death logic if HP hits zero.
func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_hp = clampi(current_hp - amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		_on_died()


## Increase HP by amount. Clamps to max_hp.
func heal(amount: int) -> void:
	if _is_dead:
		return
	current_hp = clampi(current_hp + amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)


## Update the maximum HP value and clamp current HP if it now exceeds the new max.
func set_max_hp(value: int) -> void:
	max_hp = maxi(value, 1)
	current_hp = clampi(current_hp, 0, max_hp)
	health_changed.emit(current_hp, max_hp)


## Returns true when the entity has died (current_hp == 0).
func is_dead() -> bool:
	return _is_dead


## Returns current HP as a fraction of max HP in the range [0.0, 1.0].
func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _on_died() -> void:
	_is_dead = true
	died.emit()
