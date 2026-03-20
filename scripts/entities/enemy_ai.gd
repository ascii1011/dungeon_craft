## EnemyAI
## Node script implementing a simple state machine for enemy behaviour.
## States: IDLE, PATROL, CHASE, ATTACK, DEAD.
##
## Attach as a child of a CharacterBody2D enemy entity.
## The parent must have a CombatComponent sibling for attacks to work.
class_name EnemyAI
extends Node

# ---------------------------------------------------------------------------
# State enum
# ---------------------------------------------------------------------------

enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var aggro_range: float = 150.0
@export var attack_range: float = 40.0
@export var patrol_radius: float = 80.0
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 90.0
@export var attack_cooldown: float = 1.2

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted whenever the AI transitions to a new state.
signal state_changed(new_state: State)

# ---------------------------------------------------------------------------
# State variables
# ---------------------------------------------------------------------------

var current_state: State = State.IDLE
var _target: Node2D = null
var _patrol_origin: Vector2
var _patrol_target: Vector2
var _attack_timer: float = 0.0

## Internal idle wait timer (randomised 1-2s before picking a patrol point).
var _idle_timer: float = 0.0

# ---------------------------------------------------------------------------
# Built-in callbacks
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Record the spawn position as the patrol origin.
	if get_parent() is Node2D:
		_patrol_origin = (get_parent() as Node2D).global_position
	_idle_timer = _random_idle_wait()
	_target = _get_player()


func _physics_process(delta: float) -> void:
	# Refresh player reference lazily in case it enters the tree after us.
	if _target == null:
		_target = _get_player()

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DEAD:
			pass  # Dead entities do nothing.

# ---------------------------------------------------------------------------
# State processors
# ---------------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	# Aggro check has priority over idle behaviour.
	if _target != null and _distance_to_player() <= aggro_range:
		enter_state(State.CHASE)
		return

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		# Pick a random patrol point within patrol_radius of the origin.
		var angle: float = randf() * TAU
		_patrol_target = _patrol_origin + Vector2(cos(angle), sin(angle)) * (randf() * patrol_radius)
		enter_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	# Aggro check has priority over patrol behaviour.
	if _target != null and _distance_to_player() <= aggro_range:
		enter_state(State.CHASE)
		return

	# Move toward patrol target.
	var parent := get_parent() as CharacterBody2D
	if parent == null:
		return

	var dist: float = parent.global_position.distance_to(_patrol_target)
	if dist <= 4.0:
		# Arrived at waypoint — return to idle.
		enter_state(State.IDLE)
		return

	_move_toward(_patrol_target, patrol_speed, delta)


func _process_chase(delta: float) -> void:
	if _target == null:
		enter_state(State.IDLE)
		return

	var dist: float = _distance_to_player()

	if dist <= attack_range:
		enter_state(State.ATTACK)
		return

	# Lose aggro if the player is too far away.
	if dist > aggro_range * 1.5:
		enter_state(State.IDLE)
		return

	_move_toward(_target.global_position, chase_speed, delta)


func _process_attack(delta: float) -> void:
	if _target == null:
		enter_state(State.CHASE)
		return

	# Face the player (rotate or flip is handled at the entity level if needed).
	var parent := get_parent() as Node2D
	if parent != null:
		var _dir: Vector2 = (_target.global_position - parent.global_position).normalized()

	# Tick the attack cooldown.
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = attack_cooldown

	# Chase again if the player has moved out of attack range.
	if _distance_to_player() > attack_range:
		enter_state(State.CHASE)

# ---------------------------------------------------------------------------
# State transition
# ---------------------------------------------------------------------------

## Transition to a new state. Blocks transitions out of DEAD.
## Runs entry logic for the new state and emits state_changed.
func enter_state(new_state: State) -> void:
	# Once dead, no further transitions are allowed.
	if current_state == State.DEAD:
		return

	current_state = new_state
	state_changed.emit(new_state)

	# Entry logic per state.
	match new_state:
		State.IDLE:
			_idle_timer = _random_idle_wait()
		State.PATROL:
			pass  # _patrol_target is set before entering this state.
		State.CHASE:
			pass
		State.ATTACK:
			# Reset timer so the first attack fires after one cooldown.
			_attack_timer = attack_cooldown
		State.DEAD:
			# Stop movement.
			var parent := get_parent() as CharacterBody2D
			if parent != null:
				parent.velocity = Vector2.ZERO

# ---------------------------------------------------------------------------
# Helper methods
# ---------------------------------------------------------------------------

## Find the player node by group.
func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


## Execute a melee attack via the parent's CombatComponent.
func _perform_attack() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var combat: CombatComponent = null
	for child in parent.get_children():
		if child is CombatComponent:
			combat = child as CombatComponent
			break
	if combat == null:
		return
	var direction: Vector2 = Vector2.DOWN
	if _target != null and parent is Node2D:
		direction = ((parent as Node2D).global_position.direction_to(_target.global_position))
	combat.perform_attack(direction)


## Return the distance from the parent to the player. Returns INF if no target.
func _distance_to_player() -> float:
	if _target == null:
		return INF
	var parent := get_parent() as Node2D
	if parent == null:
		return INF
	return parent.global_position.distance_to(_target.global_position)


## Move the parent CharacterBody2D toward target_pos at speed using move_and_slide.
func _move_toward(target_pos: Vector2, speed: float, delta: float) -> void:
	var parent := get_parent() as CharacterBody2D
	if parent == null:
		return
	var direction: Vector2 = parent.global_position.direction_to(target_pos)
	parent.velocity = direction * speed
	parent.move_and_slide()


## Return a random idle wait duration in the range [1.0, 2.0] seconds.
func _random_idle_wait() -> float:
	return 1.0 + randf()
