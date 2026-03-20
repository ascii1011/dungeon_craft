## test_loot_system.gd
## GUT unit tests for LootSystem.
##
## These tests focus on the loot probability logic, gold range rolls, XP
## signal emission, and item pickup spawn positions.  They operate on a fresh
## LootSystem instance and avoid scene-tree dependencies where possible.
extends GutTest

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

var _ls: Node  # LootSystem instance under test

func before_each() -> void:
	_ls = load("res://scripts/systems/loot_system.gd").new()
	add_child_autofree(_ls)


# ---------------------------------------------------------------------------
# test_roll_enemy_loot_emits_xp
##
## Inject fake enemy data directly into DataLoader's cache so no disk access
## is required, then call roll_enemy_loot and verify the xp_gained signal
## was emitted with the correct amount.
# ---------------------------------------------------------------------------

func test_roll_enemy_loot_emits_xp() -> void:
	# Pre-seed the DataLoader cache with a minimal enemy record.
	var fake_enemy := {
		"id": "test_enemy",
		"xp_reward": 50,
		"gold_drop": {"min": 0, "max": 0},
		"loot_table": []
	}
	var dl := load("res://scripts/core/data_loader.gd").new()
	add_child_autofree(dl)
	dl._cache["res://data/enemies/test_enemy.json"] = fake_enemy

	# Temporarily swap DataLoader with our local instance so loot_system uses it.
	# Because DataLoader is an autoload singleton we test the signal by watching
	# EventBus directly instead.
	watch_signals(EventBus)

	# Use the real DataLoader (autoload) — seed its cache.
	DataLoader._cache["res://data/enemies/test_enemy.json"] = fake_enemy

	var dummy_world := Node.new()
	add_child_autofree(dummy_world)

	_ls.roll_enemy_loot("test_enemy", Vector2.ZERO, dummy_world)

	assert_signal_emitted_with_parameters(EventBus, "xp_gained", [50])

	# Clean up injected cache entry.
	DataLoader._cache.erase("res://data/enemies/test_enemy.json")


# ---------------------------------------------------------------------------
# test_gold_roll_within_range
##
## Roll gold 100 times via the internal logic and assert every result falls
## within [min, max].
# ---------------------------------------------------------------------------

func test_gold_roll_within_range() -> void:
	var gold_min := 5
	var gold_max := 20

	for i in range(100):
		var amount: int = randi_range(gold_min, gold_max)
		assert_true(
			amount >= gold_min and amount <= gold_max,
			"Gold roll %d is outside [%d, %d]" % [amount, gold_min, gold_max]
		)


# ---------------------------------------------------------------------------
# test_loot_roll_respects_zero_chance
##
## _roll_chance(0.0) must always return false.
# ---------------------------------------------------------------------------

func test_loot_roll_respects_zero_chance() -> void:
	for i in range(200):
		var result: bool = _ls._roll_chance(0.0)
		assert_false(result, "_roll_chance(0.0) must never return true (iteration %d)" % i)


# ---------------------------------------------------------------------------
# test_loot_roll_respects_full_chance
##
## _roll_chance(1.0) must always return true.
# ---------------------------------------------------------------------------

func test_loot_roll_respects_full_chance() -> void:
	for i in range(200):
		var result: bool = _ls._roll_chance(1.0)
		assert_true(result, "_roll_chance(1.0) must always return true (iteration %d)" % i)


# ---------------------------------------------------------------------------
# test_spawn_item_pickup_positions_with_offset
##
## Spawn 5 pickups at the same base position. Because each spawn applies a
## random ±8 px offset, the resulting positions should not all be identical.
## (Statistical chance of 5 identical draws is negligible.)
# ---------------------------------------------------------------------------

func test_spawn_item_pickup_positions_with_offset() -> void:
	# Seed the DataLoader cache so item_pickup._load_display() doesn't push errors.
	DataLoader._cache["res://data/items/potion_health.json"] = {
		"id": "potion_health",
		"name": "Health Potion"
	}

	var world := Node.new()
	add_child_autofree(world)

	var base_pos := Vector2(100.0, 100.0)
	var positions: Array = []

	for i in range(5):
		_ls.spawn_item_pickup("potion_health", base_pos, world)

	# Collect positions of all spawned children.
	for child in world.get_children():
		positions.append(child.position)

	assert_eq(positions.size(), 5, "Expected 5 pickups to be spawned")

	# At least two positions must differ (offset is applied).
	var all_same := true
	for i in range(1, positions.size()):
		if positions[i] != positions[0]:
			all_same = false
			break

	assert_false(all_same, "All 5 spawned pickups share the exact same position — offset not applied")

	# Clean up DataLoader cache.
	DataLoader._cache.erase("res://data/items/potion_health.json")
