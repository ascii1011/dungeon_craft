## Unit tests for EnemyAI state machine.
## Run with the GUT framework.
extends GutTest

var _ai: EnemyAI

func before_each() -> void:
	_ai = EnemyAI.new()
	add_child_autofree(_ai)


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_state_is_idle() -> void:
	assert_eq(_ai.current_state, EnemyAI.State.IDLE, "AI should start in IDLE state")


# ---------------------------------------------------------------------------
# enter_state signal
# ---------------------------------------------------------------------------

func test_enter_state_emits_signal() -> void:
	watch_signals(_ai)
	_ai.enter_state(EnemyAI.State.PATROL)
	assert_signal_emitted(_ai, "state_changed")


func test_enter_state_signal_carries_new_state() -> void:
	watch_signals(_ai)
	_ai.enter_state(EnemyAI.State.CHASE)
	assert_signal_emitted_with_parameters(_ai, "state_changed", [EnemyAI.State.CHASE])


# ---------------------------------------------------------------------------
# Export defaults
# ---------------------------------------------------------------------------

func test_aggro_range_export_default() -> void:
	assert_eq(_ai.aggro_range, 150.0, "Default aggro_range should be 150.0")


func test_attack_range_export_default() -> void:
	assert_eq(_ai.attack_range, 40.0, "Default attack_range should be 40.0")


# ---------------------------------------------------------------------------
# DEAD state is terminal
# ---------------------------------------------------------------------------

func test_dead_state_stays_dead() -> void:
	_ai.enter_state(EnemyAI.State.DEAD)
	assert_eq(_ai.current_state, EnemyAI.State.DEAD, "Should have entered DEAD state")
	# Attempt to re-enter IDLE — the state must not change.
	_ai.enter_state(EnemyAI.State.IDLE)
	assert_eq(_ai.current_state, EnemyAI.State.DEAD, "DEAD state should block all further transitions")


func test_dead_state_does_not_emit_signal_on_blocked_transition() -> void:
	_ai.enter_state(EnemyAI.State.DEAD)
	watch_signals(_ai)
	_ai.enter_state(EnemyAI.State.IDLE)
	assert_signal_not_emitted(_ai, "state_changed")


# ---------------------------------------------------------------------------
# Speed invariant
# ---------------------------------------------------------------------------

func test_patrol_speed_less_than_chase_speed() -> void:
	assert_lt(_ai.patrol_speed, _ai.chase_speed, "patrol_speed must be less than chase_speed")
