## GUT unit tests for FactionComponent.
## Covers default state, reputation modification, clamping, hostility rules,
## standing tier labels, and the reputation_changed signal.
extends GutTest

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

var _faction: FactionComponent

func before_each() -> void:
	_faction = FactionComponent.new()
	add_child_autofree(_faction)

# ---------------------------------------------------------------------------
# Default reputation
# ---------------------------------------------------------------------------

func test_default_reputation() -> void:
	assert_eq(_faction.get_reputation("townspeople"),  0,    "Default townspeople rep should be 0")
	assert_eq(_faction.get_reputation("dungeon_guild"), 0,   "Default dungeon_guild rep should be 0")
	assert_eq(_faction.get_reputation("monsters"),     -100, "Default monsters rep should be -100")

# ---------------------------------------------------------------------------
# modify_reputation — basic increase
# ---------------------------------------------------------------------------

func test_modify_reputation_increases_value() -> void:
	_faction.modify_reputation("townspeople", 50)
	assert_eq(_faction.get_reputation("townspeople"), 50,
		"Reputation should increase by the given amount")

# ---------------------------------------------------------------------------
# modify_reputation — upper clamp
# ---------------------------------------------------------------------------

func test_modify_reputation_clamps_at_max() -> void:
	_faction.modify_reputation("townspeople", 999)
	_faction.modify_reputation("townspeople", 999)
	assert_eq(_faction.get_reputation("townspeople"), FactionComponent.REP_MAX,
		"Reputation should not exceed REP_MAX (%d)" % FactionComponent.REP_MAX)

# ---------------------------------------------------------------------------
# modify_reputation — lower clamp
# ---------------------------------------------------------------------------

func test_modify_reputation_clamps_at_min() -> void:
	_faction.modify_reputation("townspeople", -999)
	_faction.modify_reputation("townspeople", -999)
	assert_eq(_faction.get_reputation("townspeople"), FactionComponent.REP_MIN,
		"Reputation should not go below REP_MIN (%d)" % FactionComponent.REP_MIN)

# ---------------------------------------------------------------------------
# is_hostile_to — monsters vs player
# ---------------------------------------------------------------------------

func test_monsters_hostile_to_player() -> void:
	var monster_faction: FactionComponent = FactionComponent.new()
	monster_faction.faction = "monsters"
	add_child_autofree(monster_faction)

	var player_faction: FactionComponent = FactionComponent.new()
	player_faction.faction = "player"
	add_child_autofree(player_faction)

	assert_true(monster_faction.is_hostile_to(player_faction),
		"Monsters should always be hostile toward the player faction")
	assert_true(player_faction.is_hostile_to(monster_faction),
		"Player should always be hostile toward monsters")

# ---------------------------------------------------------------------------
# get_standing — Neutral at rep 0
# ---------------------------------------------------------------------------

func test_neutral_standing_at_zero() -> void:
	assert_eq(_faction.get_standing("townspeople"), "Neutral",
		"Standing should be Neutral when reputation is 0")

# ---------------------------------------------------------------------------
# get_standing — all tier boundaries
# ---------------------------------------------------------------------------

func test_get_standing_returns_correct_tier() -> void:
	# Hated: rep < -500
	_faction._reputation["townspeople"] = -501
	assert_eq(_faction.get_standing("townspeople"), "Hated",
		"Standing should be Hated when rep < -500")

	# Hostile: -500 <= rep < -200
	_faction._reputation["townspeople"] = -500
	assert_eq(_faction.get_standing("townspeople"), "Hostile",
		"Standing should be Hostile when rep == -500")

	_faction._reputation["townspeople"] = -201
	assert_eq(_faction.get_standing("townspeople"), "Hostile",
		"Standing should be Hostile when rep == -201")

	# Neutral: -200 <= rep < 200
	_faction._reputation["townspeople"] = -200
	assert_eq(_faction.get_standing("townspeople"), "Neutral",
		"Standing should be Neutral when rep == -200")

	_faction._reputation["townspeople"] = 0
	assert_eq(_faction.get_standing("townspeople"), "Neutral",
		"Standing should be Neutral when rep == 0")

	_faction._reputation["townspeople"] = 199
	assert_eq(_faction.get_standing("townspeople"), "Neutral",
		"Standing should be Neutral when rep == 199")

	# Friendly: 200 <= rep < 500
	_faction._reputation["townspeople"] = 200
	assert_eq(_faction.get_standing("townspeople"), "Friendly",
		"Standing should be Friendly when rep == 200")

	_faction._reputation["townspeople"] = 499
	assert_eq(_faction.get_standing("townspeople"), "Friendly",
		"Standing should be Friendly when rep == 499")

	# Exalted: rep >= 500
	_faction._reputation["townspeople"] = 500
	assert_eq(_faction.get_standing("townspeople"), "Exalted",
		"Standing should be Exalted when rep == 500")

	_faction._reputation["townspeople"] = 1000
	assert_eq(_faction.get_standing("townspeople"), "Exalted",
		"Standing should be Exalted when rep == 1000")

# ---------------------------------------------------------------------------
# reputation_changed signal
# ---------------------------------------------------------------------------

func test_reputation_changed_signal_emits() -> void:
	watch_signals(_faction)
	_faction.modify_reputation("dungeon_guild", 100)
	assert_signal_emitted(_faction, "reputation_changed",
		"reputation_changed signal should emit when reputation is modified")

	var args: Array = get_signal_parameters(_faction, "reputation_changed")
	assert_eq(args[0], "dungeon_guild", "Signal first arg should be the faction_id")
	assert_eq(args[1], 100, "Signal second arg should be the new reputation value")
	assert_eq(args[2], 0,   "Signal third arg should be the old reputation value")
