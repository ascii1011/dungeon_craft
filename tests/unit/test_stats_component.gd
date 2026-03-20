## Unit tests for StatsComponent.
## Run with the GUT framework.
extends GutTest

var _comp: StatsComponent

func before_each() -> void:
	_comp = StatsComponent.new()
	add_child_autofree(_comp)

# ---------------------------------------------------------------------------
# Base stats
# ---------------------------------------------------------------------------

func test_default_strength_is_ten() -> void:
	assert_eq(_comp.strength, 10, "Default strength should be 10")


func test_default_dexterity_is_ten() -> void:
	assert_eq(_comp.dexterity, 10, "Default dexterity should be 10")


func test_default_intelligence_is_ten() -> void:
	assert_eq(_comp.intelligence, 10, "Default intelligence should be 10")


func test_default_vitality_is_ten() -> void:
	assert_eq(_comp.vitality, 10, "Default vitality should be 10")


func test_get_total_returns_base_when_no_modifiers() -> void:
	assert_eq(_comp.get_total("strength"), 10)
	assert_eq(_comp.get_total("dexterity"), 10)
	assert_eq(_comp.get_total("intelligence"), 10)
	assert_eq(_comp.get_total("vitality"), 10)

# ---------------------------------------------------------------------------
# add_modifier / get_total
# ---------------------------------------------------------------------------

func test_add_modifier_increases_total() -> void:
	_comp.add_modifier("strength", "sword_of_power", 5)
	assert_eq(_comp.get_total("strength"), 15, "Modifier should add to base stat")


func test_add_modifier_negative_decreases_total() -> void:
	_comp.add_modifier("dexterity", "slow_curse", -3)
	assert_eq(_comp.get_total("dexterity"), 7, "Negative modifier should reduce stat")


func test_multiple_modifiers_stack() -> void:
	_comp.add_modifier("strength", "ring_of_might", 4)
	_comp.add_modifier("strength", "potion_of_strength", 6)
	assert_eq(_comp.get_total("strength"), 20, "Multiple modifiers should stack")


func test_single_source_can_modify_multiple_stats() -> void:
	_comp.add_modifier("strength", "full_plate", 2)
	_comp.add_modifier("vitality", "full_plate", 3)
	assert_eq(_comp.get_total("strength"), 12)
	assert_eq(_comp.get_total("vitality"), 13)

# ---------------------------------------------------------------------------
# remove_modifier
# ---------------------------------------------------------------------------

func test_remove_modifier_restores_base_stat() -> void:
	_comp.add_modifier("intelligence", "mage_hat", 8)
	_comp.remove_modifier("mage_hat")
	assert_eq(_comp.get_total("intelligence"), 10, "Stat should return to base after removal")


func test_remove_nonexistent_modifier_is_safe() -> void:
	# Should not throw or change anything.
	_comp.remove_modifier("ghost_source")
	assert_eq(_comp.get_total("strength"), 10)


func test_removing_one_source_leaves_others_intact() -> void:
	_comp.add_modifier("strength", "ring_a", 3)
	_comp.add_modifier("strength", "ring_b", 4)
	_comp.remove_modifier("ring_a")
	assert_eq(_comp.get_total("strength"), 14, "Only the removed source should be gone")

# ---------------------------------------------------------------------------
# apply_race_data
# ---------------------------------------------------------------------------

func test_apply_race_data_sets_all_stats() -> void:
	var race_data := {
		"strength": 14,
		"dexterity": 12,
		"intelligence": 8,
		"vitality": 16,
	}
	_comp.apply_race_data(race_data)
	assert_eq(_comp.strength, 14)
	assert_eq(_comp.dexterity, 12)
	assert_eq(_comp.intelligence, 8)
	assert_eq(_comp.vitality, 16)


func test_apply_race_data_partial_dict_leaves_others_unchanged() -> void:
	var race_data := {"strength": 18}
	_comp.apply_race_data(race_data)
	assert_eq(_comp.strength, 18, "Strength should be updated")
	assert_eq(_comp.dexterity, 10, "Dexterity should remain unchanged")
	assert_eq(_comp.intelligence, 10, "Intelligence should remain unchanged")
	assert_eq(_comp.vitality, 10, "Vitality should remain unchanged")


func test_apply_race_data_get_total_reflects_new_base() -> void:
	_comp.add_modifier("strength", "weapon", 2)
	_comp.apply_race_data({"strength": 15})
	assert_eq(_comp.get_total("strength"), 17, "get_total should use new base + existing modifier")
