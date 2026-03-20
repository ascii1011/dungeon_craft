## Unit tests for MovementComponent.
## Run with the GUT framework.
##
## Note: get_input_vector() reads live Input actions and cannot be tested
## without an input simulation harness, so those tests focus on the pure
## data/timer logic. move() requires a CharacterBody2D parent which is
## covered in integration tests; we verify it does not crash when the parent
## is missing via the guard in the component itself.
extends GutTest

var _comp: MovementComponent

func before_each() -> void:
	_comp = MovementComponent.new()
	add_child_autofree(_comp)

# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------

func test_base_speed_default() -> void:
	assert_eq(_comp.base_speed, 150.0, "base_speed default should be 150.0")


func test_current_speed_default() -> void:
	assert_eq(_comp.current_speed, 150.0, "current_speed default should be 150.0")

# ---------------------------------------------------------------------------
# set_speed_multiplier — immediate effect
# ---------------------------------------------------------------------------

func test_set_speed_multiplier_changes_current_speed() -> void:
	_comp.set_speed_multiplier(0.5, 5.0)
	assert_eq(_comp.current_speed, 75.0,
		"current_speed should be base_speed * multiplier = 75.0")


func test_set_speed_multiplier_above_one_increases_speed() -> void:
	_comp.set_speed_multiplier(2.0, 3.0)
	assert_eq(_comp.current_speed, 300.0,
		"current_speed should be base_speed * 2 = 300.0")

# ---------------------------------------------------------------------------
# set_speed_multiplier — restoration after duration
# ---------------------------------------------------------------------------

func test_speed_restored_after_duration_elapsed() -> void:
	# Apply a slow for 1 second.
	_comp.set_speed_multiplier(0.5, 1.0)
	assert_eq(_comp.current_speed, 75.0, "Speed should be halved immediately")

	# Simulate time passing: tick _process manually with a total of 1.01 s.
	# We use a single large step to keep the test simple.
	_comp._process(1.01)
	assert_eq(_comp.current_speed, 150.0,
		"Speed should be restored to base after duration expires")


func test_speed_not_restored_before_duration_elapses() -> void:
	_comp.set_speed_multiplier(0.5, 2.0)
	# Only 1 second has passed; 1 more second remains.
	_comp._process(1.0)
	assert_eq(_comp.current_speed, 75.0,
		"Speed should still be modified before duration expires")


func test_speed_restored_across_multiple_ticks() -> void:
	_comp.set_speed_multiplier(0.25, 0.5)
	# Three ticks totalling 0.6 s (> 0.5 s duration).
	_comp._process(0.2)
	_comp._process(0.2)
	_comp._process(0.2)
	assert_eq(_comp.current_speed, 150.0,
		"Speed should be restored after accumulated delta exceeds duration")

# ---------------------------------------------------------------------------
# Stacking / overwriting multiplier
# ---------------------------------------------------------------------------

func test_applying_new_multiplier_overwrites_previous() -> void:
	_comp.set_speed_multiplier(0.5, 10.0)   # Slow
	_comp.set_speed_multiplier(2.0, 5.0)    # Haste overwrites slow (saves original)
	assert_eq(_comp.current_speed, 300.0,
		"Latest multiplier should take effect")


func test_original_speed_preserved_across_overwrite() -> void:
	# First call saves original speed (150).
	_comp.set_speed_multiplier(0.5, 10.0)
	# Second call should NOT overwrite the saved original because a multiplier
	# is already active.
	_comp.set_speed_multiplier(2.0, 2.0)
	_comp._process(2.01)
	assert_eq(_comp.current_speed, 150.0,
		"Speed should restore to the original base after all multipliers expire")
