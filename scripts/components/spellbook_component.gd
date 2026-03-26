## SpellbookComponent
## Manages a character's known spells, mana pool with regeneration, and spell cooldowns.
class_name SpellbookComponent
extends Node

signal mana_changed(current: int, maximum: int)
signal spell_learned(spell_id: String)
signal cooldown_expired(spell_id: String)

@export var max_mana: int = 100
@export var mana_regen_per_second: float = 2.0

var current_mana: int = 100

var _known_spells: Array[String] = []
## Maps spell_id -> remaining seconds on cooldown
var _cooldowns: Dictionary = {}

## Accumulated fractional mana from regen
var _mana_regen_accumulator: float = 0.0


func _ready() -> void:
	current_mana = max_mana


func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_mana_regen(delta)


## Adds spell_id to the known spells list if not already known.
func learn_spell(spell_id: String) -> void:
	if not _known_spells.has(spell_id):
		_known_spells.append(spell_id)
		spell_learned.emit(spell_id)


## Returns true if the spell_id is in the known spells list.
func knows_spell(spell_id: String) -> bool:
	return _known_spells.has(spell_id)


## Returns the remaining cooldown time in seconds for spell_id (0.0 if not on cooldown).
func get_cooldown(spell_id: String) -> float:
	return _cooldowns.get(spell_id, 0.0)


## Returns true if spell_id currently has remaining cooldown time.
func is_on_cooldown(spell_id: String) -> bool:
	return _cooldowns.get(spell_id, 0.0) > 0.0


## Starts a cooldown of duration seconds for spell_id.
func start_cooldown(spell_id: String, duration: float) -> void:
	if duration > 0.0:
		_cooldowns[spell_id] = duration


## Returns true if current_mana >= amount.
func has_mana(amount: int) -> bool:
	return current_mana >= amount


## Reduces current_mana by amount, clamped to 0.
func spend_mana(amount: int) -> void:
	var prev: int = current_mana
	current_mana = max(0, current_mana - amount)
	if current_mana != prev:
		mana_changed.emit(current_mana, max_mana)


## Increases current_mana by amount, clamped to max_mana.
func restore_mana(amount: int) -> void:
	var prev: int = current_mana
	current_mana = min(max_mana, current_mana + amount)
	if current_mana != prev:
		mana_changed.emit(current_mana, max_mana)


# --- Private helpers ---

func _tick_cooldowns(delta: float) -> void:
	var expired: Array[String] = []
	for spell_id: String in _cooldowns.keys():
		_cooldowns[spell_id] -= delta
		if _cooldowns[spell_id] <= 0.0:
			_cooldowns.erase(spell_id)
			expired.append(spell_id)
	for spell_id: String in expired:
		cooldown_expired.emit(spell_id)


func _tick_mana_regen(delta: float) -> void:
	if current_mana >= max_mana:
		return
	_mana_regen_accumulator += mana_regen_per_second * delta
	var regen_int: int = int(_mana_regen_accumulator)
	if regen_int >= 1:
		_mana_regen_accumulator -= float(regen_int)
		restore_mana(regen_int)
