## test_event_bus.gd
## GUT unit tests for the EventBus autoload singleton.
##
## These tests verify that every required signal is declared on the EventBus
## script and that signals can be connected and emitted without error.
## Signal emission is verified via a lightweight spy helper that records calls.
extends GutTest

# ---------------------------------------------------------------------------
# Helpers / setup
# ---------------------------------------------------------------------------

var _eb  # Local EventBus instance

## Simple spy node — records each signal emission as a call count + last args.
class SignalSpy:
	var call_count: int = 0
	var last_args: Array = []

	func record(args: Array = []) -> void:
		call_count += 1
		last_args = args

func before_each() -> void:
	_eb = load("res://scripts/core/event_bus.gd").new()
	add_child_autofree(_eb)

func after_each() -> void:
	pass  # add_child_autofree handles teardown

# ---------------------------------------------------------------------------
# Signal existence — has_signal()
# ---------------------------------------------------------------------------

func test_has_signal_player_health_changed() -> void:
	assert_true(_eb.has_signal("player_health_changed"))

func test_has_signal_player_died() -> void:
	assert_true(_eb.has_signal("player_died"))

func test_has_signal_player_zone_changed() -> void:
	assert_true(_eb.has_signal("player_zone_changed"))

func test_has_signal_enemy_died() -> void:
	assert_true(_eb.has_signal("enemy_died"))

func test_has_signal_item_picked_up() -> void:
	assert_true(_eb.has_signal("item_picked_up"))

func test_has_signal_item_equipped() -> void:
	assert_true(_eb.has_signal("item_equipped"))

func test_has_signal_spell_cast() -> void:
	assert_true(_eb.has_signal("spell_cast"))

func test_has_signal_game_paused() -> void:
	assert_true(_eb.has_signal("game_paused"))

func test_has_signal_game_resumed() -> void:
	assert_true(_eb.has_signal("game_resumed"))

func test_has_signal_gold_changed() -> void:
	assert_true(_eb.has_signal("gold_changed"))

func test_has_signal_xp_gained() -> void:
	assert_true(_eb.has_signal("xp_gained"))

func test_has_signal_shop_opened() -> void:
	assert_true(_eb.has_signal("shop_opened"))

func test_has_signal_shop_closed() -> void:
	assert_true(_eb.has_signal("shop_closed"))

# ---------------------------------------------------------------------------
# Signal emission — connect, emit, verify
# ---------------------------------------------------------------------------

func test_player_health_changed_emits() -> void:
	var spy := SignalSpy.new()
	_eb.player_health_changed.connect(func(hp, max_hp): spy.record([hp, max_hp]))
	_eb.player_health_changed.emit(80, 100)
	assert_eq(spy.call_count, 1, "player_health_changed should fire once")
	assert_eq(spy.last_args, [80, 100], "player_health_changed args should match")

func test_player_died_emits() -> void:
	var spy := SignalSpy.new()
	_eb.player_died.connect(func(): spy.record())
	_eb.player_died.emit()
	assert_eq(spy.call_count, 1, "player_died should fire once")

func test_player_zone_changed_emits() -> void:
	var spy := SignalSpy.new()
	_eb.player_zone_changed.connect(func(z): spy.record([z]))
	_eb.player_zone_changed.emit("floor_2")
	assert_eq(spy.last_args, ["floor_2"], "player_zone_changed should carry zone_id")

func test_enemy_died_emits() -> void:
	var spy := SignalSpy.new()
	_eb.enemy_died.connect(func(id, pos): spy.record([id, pos]))
	_eb.enemy_died.emit("goblin_01", Vector2(10, 20))
	assert_eq(spy.call_count, 1, "enemy_died should fire once")
	assert_eq(spy.last_args[0], "goblin_01", "enemy_died should carry enemy_id")

func test_item_picked_up_emits() -> void:
	var spy := SignalSpy.new()
	_eb.item_picked_up.connect(func(id): spy.record([id]))
	_eb.item_picked_up.emit("iron_sword")
	assert_eq(spy.last_args, ["iron_sword"], "item_picked_up should carry item_id")

func test_item_equipped_emits() -> void:
	var spy := SignalSpy.new()
	_eb.item_equipped.connect(func(id, slot): spy.record([id, slot]))
	_eb.item_equipped.emit("leather_helm", "head")
	assert_eq(spy.last_args, ["leather_helm", "head"], "item_equipped should carry item_id and slot")

func test_game_paused_emits() -> void:
	var spy := SignalSpy.new()
	_eb.game_paused.connect(func(): spy.record())
	_eb.game_paused.emit()
	assert_eq(spy.call_count, 1, "game_paused should fire once")

func test_game_resumed_emits() -> void:
	var spy := SignalSpy.new()
	_eb.game_resumed.connect(func(): spy.record())
	_eb.game_resumed.emit()
	assert_eq(spy.call_count, 1, "game_resumed should fire once")

func test_gold_changed_emits() -> void:
	var spy := SignalSpy.new()
	_eb.gold_changed.connect(func(amount): spy.record([amount]))
	_eb.gold_changed.emit(250)
	assert_eq(spy.last_args, [250], "gold_changed should carry new_amount")

func test_xp_gained_emits() -> void:
	var spy := SignalSpy.new()
	_eb.xp_gained.connect(func(amount): spy.record([amount]))
	_eb.xp_gained.emit(500)
	assert_eq(spy.last_args, [500], "xp_gained should carry amount")

func test_shop_opened_emits() -> void:
	var spy := SignalSpy.new()
	_eb.shop_opened.connect(func(id): spy.record([id]))
	_eb.shop_opened.emit("blacksmith_1")
	assert_eq(spy.last_args, ["blacksmith_1"], "shop_opened should carry shop_id")

func test_shop_closed_emits() -> void:
	var spy := SignalSpy.new()
	_eb.shop_closed.connect(func(): spy.record())
	_eb.shop_closed.emit()
	assert_eq(spy.call_count, 1, "shop_closed should fire once")
