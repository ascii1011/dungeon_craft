## MovementComponent
## Handles WASD movement for a CharacterBody2D parent entity.
## Call move(delta) from the parent's _physics_process.
class_name MovementComponent
extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var base_speed: float = 150.0
@export var current_speed: float = 150.0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted the first frame the entity begins moving.
signal movement_started()

## Emitted the first frame the entity comes to a stop.
signal movement_stopped()

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _was_moving: bool = false

# Speed multiplier restoration timer.
var _speed_timer: float = 0.0
var _original_speed: float = 0.0
var _speed_multiplier_active: bool = false

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Tick the temporary speed multiplier countdown.
	if _speed_multiplier_active:
		_speed_timer -= delta
		if _speed_timer <= 0.0:
			current_speed = _original_speed
			_speed_multiplier_active = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Read WASD input actions and return a normalised direction vector.
## Returns Vector2.ZERO when no directional input is held.
func get_input_vector() -> Vector2:
	var direction := Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")
	return direction.normalized()


## Move the parent CharacterBody2D according to current input.
## Call this from the parent's _physics_process(delta).
func move(delta: float) -> void:
	var parent: CharacterBody2D = get_parent() as CharacterBody2D
	if parent == null:
		push_error("MovementComponent: parent is not a CharacterBody2D")
		return

	var direction: Vector2 = get_input_vector()
	var is_moving: bool = direction != Vector2.ZERO

	parent.velocity = direction * current_speed
	parent.move_and_slide()

	# Emit movement state change signals only on transitions.
	if is_moving and not _was_moving:
		movement_started.emit()
	elif not is_moving and _was_moving:
		movement_stopped.emit()

	_was_moving = is_moving


## Apply a temporary speed multiplier for a given duration (seconds).
## Stacks with the current speed by replacing it; original speed is restored
## automatically once the timer expires.
func set_speed_multiplier(mult: float, duration: float) -> void:
	if not _speed_multiplier_active:
		# Save the current speed so we can restore it later.
		_original_speed = current_speed
	current_speed = base_speed * mult
	_speed_timer = duration
	_speed_multiplier_active = true
