## GUT unit tests for SpellbookComponent.
## Covers spell learning, cooldown tracking, mana management, and signals.
extends GutTest


var _spellbook: SpellbookComponent


func before_each() -> void:
	_spellbook = SpellbookComponent.new()
	_spellbook.max_mana = 100
	add_child_autofree(_spellbook)
	# Ensure current_mana is at max after _ready
	_spellbook.current_mana = _spellbook.max_mana


# ---------------------------------------------------------------------------
# learn_spell / knows_spell
# ---------------------------------------------------------------------------

func test_learn_spell_adds_to_known_list() -> void:
	_spellbook.learn_spell("fireball")
	assert_true(_spellbook.knows_spell("fireball"), "knows_spell should return true after learn_spell")


func test_knows_spell_returns_false_for_unknown() -> void:
	assert_false(_spellbook.knows_spell("heal"), "knows_spell should return false for a spell that was never learned")


func test_learn_spell_does_not_duplicate() -> void:
	_spellbook.learn_spell("fireball")
	_spellbook.learn_spell("fireball")
	# No public count API — verify via signal count
	watch_signals(_spellbook)
	_spellbook.learn_spell("fireball")
	# Signal should NOT fire again for a duplicate
	assert_signal_emit_count(_spellbook, "spell_learned", 0,
		"spell_learned should not emit when spell is already known")


func test_learn_spell_emits_signal() -> void:
	watch_signals(_spellbook)
	_spellbook.learn_spell("slow")
	assert_signal_emitted(_spellbook, "spell_learned", "spell_learned signal should fire on new spell")


func test_learn_multiple_spells() -> void:
	_spellbook.learn_spell("fireball")
	_spellbook.learn_spell("heal")
	_spellbook.learn_spell("blink")
	assert_true(_spellbook.knows_spell("fireball"))
	assert_true(_spellbook.knows_spell("heal"))
	assert_true(_spellbook.knows_spell("blink"))


# ---------------------------------------------------------------------------
# start_cooldown / is_on_cooldown / get_cooldown
# ---------------------------------------------------------------------------

func test_start_cooldown_puts_spell_on_cooldown() -> void:
	_spellbook.start_cooldown("fireball", 3.0)
	assert_true(_spellbook.is_on_cooldown("fireball"), "is_on_cooldown should be true after start_cooldown")


func test_get_cooldown_returns_remaining_time() -> void:
	_spellbook.start_cooldown("heal", 5.0)
	assert_almost_eq(_spellbook.get_cooldown("heal"), 5.0, 0.01,
		"get_cooldown should return the full duration immediately after start_cooldown")


func test_is_on_cooldown_false_before_start() -> void:
	assert_false(_spellbook.is_on_cooldown("blink"), "is_on_cooldown should be false before any cooldown is set")


# ---------------------------------------------------------------------------
# Cooldown ticks down via _process
# ---------------------------------------------------------------------------

func test_cooldown_ticks_down_via_process() -> void:
	_spellbook.start_cooldown("fireball", 2.0)
	_spellbook._process(1.0)  # simulate 1 second passing
	var remaining: float = _spellbook.get_cooldown("fireball")
	assert_almost_eq(remaining, 1.0, 0.01, "Cooldown should decrease by delta after _process")


func test_cooldown_expires_after_full_duration() -> void:
	_spellbook.start_cooldown("fireball", 1.5)
	_spellbook._process(1.5)  # exactly at expiry
	assert_false(_spellbook.is_on_cooldown("fireball"),
		"Spell should no longer be on cooldown after full duration elapses")


func test_cooldown_expired_signal_emits() -> void:
	_spellbook.start_cooldown("slow", 0.5)
	watch_signals(_spellbook)
	_spellbook._process(0.5)
	assert_signal_emitted(_spellbook, "cooldown_expired",
		"cooldown_expired signal should fire when cooldown finishes")


func test_cooldown_does_not_go_negative() -> void:
	_spellbook.start_cooldown("blink", 1.0)
	_spellbook._process(5.0)  # way more than needed
	assert_false(_spellbook.is_on_cooldown("blink"),
		"is_on_cooldown should be false when processing beyond cooldown duration")
	assert_almost_eq(_spellbook.get_cooldown("blink"), 0.0, 0.01,
		"get_cooldown should return 0 after expiry")


# ---------------------------------------------------------------------------
# spend_mana / has_mana / restore_mana
# ---------------------------------------------------------------------------

func test_spend_mana_reduces_current_mana() -> void:
	_spellbook.spend_mana(20)
	assert_eq(_spellbook.current_mana, 80, "spend_mana should reduce current_mana by the given amount")


func test_has_mana_true_when_sufficient() -> void:
	assert_true(_spellbook.has_mana(50), "has_mana should return true when current_mana >= amount")


func test_has_mana_false_when_insufficient() -> void:
	_spellbook.spend_mana(90)  # now at 10
	assert_false(_spellbook.has_mana(20), "has_mana should return false when current_mana < amount")


func test_mana_clamps_at_zero() -> void:
	_spellbook.spend_mana(200)  # more than max
	assert_eq(_spellbook.current_mana, 0, "current_mana should clamp to 0 when over-spending")


func test_mana_clamps_at_max() -> void:
	_spellbook.current_mana = 90
	_spellbook.restore_mana(50)  # would exceed 100
	assert_eq(_spellbook.current_mana, 100, "current_mana should clamp to max_mana when over-restoring")


func test_restore_mana_increases_current_mana() -> void:
	_spellbook.current_mana = 50
	_spellbook.restore_mana(30)
	assert_eq(_spellbook.current_mana, 80, "restore_mana should increase current_mana by the given amount")


# ---------------------------------------------------------------------------
# mana_changed signal
# ---------------------------------------------------------------------------

func test_mana_changed_emits_on_spend() -> void:
	watch_signals(_spellbook)
	_spellbook.spend_mana(10)
	assert_signal_emitted(_spellbook, "mana_changed",
		"mana_changed should emit when mana is spent")


func test_mana_changed_emits_on_restore() -> void:
	_spellbook.current_mana = 50
	watch_signals(_spellbook)
	_spellbook.restore_mana(20)
	assert_signal_emitted(_spellbook, "mana_changed",
		"mana_changed should emit when mana is restored")


func test_mana_changed_not_emitted_when_already_full() -> void:
	# current_mana is already at max_mana
	watch_signals(_spellbook)
	_spellbook.restore_mana(10)
	assert_signal_emit_count(_spellbook, "mana_changed", 0,
		"mana_changed should not emit when mana is already at max")


func test_mana_changed_signal_carries_correct_values() -> void:
	watch_signals(_spellbook)
	_spellbook.spend_mana(30)
	var args: Array = get_signal_parameters(_spellbook, "mana_changed")
	assert_eq(args[0], 70, "mana_changed first arg should be current mana after spend")
	assert_eq(args[1], 100, "mana_changed second arg should be max_mana")


# ---------------------------------------------------------------------------
# Mana regen via _process
# ---------------------------------------------------------------------------

func test_mana_regen_increases_mana_over_time() -> void:
	_spellbook.current_mana = 0
	_spellbook.mana_regen_per_second = 10.0
	_spellbook._process(1.0)  # should regen 10 mana
	assert_eq(_spellbook.current_mana, 10, "Mana should regenerate at mana_regen_per_second per second")


func test_mana_regen_does_not_exceed_max() -> void:
	_spellbook.current_mana = 98
	_spellbook.mana_regen_per_second = 10.0
	_spellbook._process(1.0)
	assert_eq(_spellbook.current_mana, 100, "Mana regen should not push current_mana above max_mana")


func test_mana_regen_does_not_occur_when_full() -> void:
	_spellbook.mana_regen_per_second = 10.0
	watch_signals(_spellbook)
	_spellbook._process(1.0)
	assert_signal_emit_count(_spellbook, "mana_changed", 0,
		"mana_changed should not emit during regen when mana is already full")
