## Unit tests for HealthComponent.
## Run with the GUT framework.
extends GutTest

var _comp: HealthComponent

func before_each() -> void:
	_comp = HealthComponent.new()
	_comp.max_hp = 100
	_comp.current_hp = 100
	_comp.regen_per_second = 0.0
	add_child_autofree(_comp)


# ---------------------------------------------------------------------------
# take_damage
# ---------------------------------------------------------------------------

func test_take_damage_reduces_hp() -> void:
	_comp.take_damage(30)
	assert_eq(_comp.current_hp, 70, "HP should decrease by the damage amount")


func test_take_damage_clamps_to_zero() -> void:
	_comp.take_damage(9999)
	assert_eq(_comp.current_hp, 0, "HP must not go below 0")


func test_take_damage_does_not_overshoot_zero() -> void:
	_comp.take_damage(100)
	_comp.take_damage(50)  # Entity is already dead; second call should be ignored.
	assert_eq(_comp.current_hp, 0, "HP must remain 0 after death")

# ---------------------------------------------------------------------------
# heal
# ---------------------------------------------------------------------------

func test_heal_increases_hp() -> void:
	_comp.current_hp = 50
	_comp.heal(20)
	assert_eq(_comp.current_hp, 70, "HP should increase by the heal amount")


func test_heal_clamps_to_max_hp() -> void:
	_comp.current_hp = 90
	_comp.heal(50)
	assert_eq(_comp.current_hp, 100, "HP must not exceed max_hp after heal")

# ---------------------------------------------------------------------------
# is_dead
# ---------------------------------------------------------------------------

func test_is_dead_returns_false_when_alive() -> void:
	assert_false(_comp.is_dead(), "Should not be dead at full HP")


func test_is_dead_returns_true_after_lethal_damage() -> void:
	_comp.take_damage(100)
	assert_true(_comp.is_dead(), "Should be dead when HP hits 0")

# ---------------------------------------------------------------------------
# get_hp_percent
# ---------------------------------------------------------------------------

func test_get_hp_percent_returns_one_at_full_hp() -> void:
	assert_eq(_comp.get_hp_percent(), 1.0, "Full HP should be 100 %")


func test_get_hp_percent_returns_correct_fraction() -> void:
	_comp.current_hp = 25
	assert_eq(_comp.get_hp_percent(), 0.25, "Quarter HP should return 0.25")


func test_get_hp_percent_returns_zero_when_dead() -> void:
	_comp.take_damage(100)
	assert_eq(_comp.get_hp_percent(), 0.0, "Dead entity should have 0.0 HP percent")

# ---------------------------------------------------------------------------
# set_max_hp
# ---------------------------------------------------------------------------

func test_set_max_hp_updates_max() -> void:
	_comp.set_max_hp(200)
	assert_eq(_comp.max_hp, 200, "max_hp should be updated to 200")


func test_set_max_hp_clamps_current_hp_down() -> void:
	_comp.current_hp = 100
	_comp.set_max_hp(60)
	assert_eq(_comp.current_hp, 60, "current_hp must be clamped to new max")

# ---------------------------------------------------------------------------
# health_changed signal
# ---------------------------------------------------------------------------

func test_health_changed_signal_emitted_on_damage() -> void:
	watch_signals(_comp)
	_comp.take_damage(10)
	assert_signal_emitted(_comp, "health_changed")


func test_health_changed_signal_emitted_on_heal() -> void:
	_comp.current_hp = 50
	watch_signals(_comp)
	_comp.heal(10)
	assert_signal_emitted(_comp, "health_changed")

# ---------------------------------------------------------------------------
# died signal
# ---------------------------------------------------------------------------

func test_died_signal_emitted_when_hp_hits_zero() -> void:
	watch_signals(_comp)
	_comp.take_damage(100)
	assert_signal_emitted(_comp, "died")


func test_died_signal_not_emitted_for_non_lethal_damage() -> void:
	watch_signals(_comp)
	_comp.take_damage(50)
	assert_signal_not_emitted(_comp, "died")
