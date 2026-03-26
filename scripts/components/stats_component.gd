## StatsComponent
## Stores base entity stats and manages temporary/permanent modifiers.
## Attach as a child node to any entity that needs a stat sheet.
class_name StatsComponent
extends Node

# ---------------------------------------------------------------------------
# Exports — base stats
# ---------------------------------------------------------------------------

@export var strength: int = 10
@export var dexterity: int = 10
@export var intelligence: int = 10
@export var vitality: int = 10

# ---------------------------------------------------------------------------
# Modifier storage
# ---------------------------------------------------------------------------
# Structure: { source_id: { stat_name: int_value, ... }, ... }
# A single source can carry modifiers for multiple stats.
var _modifiers: Dictionary = {}

# ---------------------------------------------------------------------------
# Derived stat computation
# ---------------------------------------------------------------------------

## Physical attack power. Base 5 + 2 per point of strength above 10.
func get_attack_power() -> int:
	var total_str: int = get_total("strength")
	return 5 + (total_str * 2)


## Damage reduction. Base 0 + 1 per point of vitality above 10.
func get_defense() -> int:
	var total_vit: int = get_total("vitality")
	return maxi(0, total_vit - 10)


## Spell power. Base 0 + 2 per point of intelligence above 10.
func get_spell_power() -> int:
	var total_int: int = get_total("intelligence")
	return maxi(0, (total_int - 10) * 2)

# ---------------------------------------------------------------------------
# Modifier API
# ---------------------------------------------------------------------------

## Add (or overwrite) a modifier for a specific stat from a named source.
## stat: "strength" | "dexterity" | "intelligence" | "vitality"
## source: arbitrary identifier (e.g. "ring_of_fire", "haste_debuff")
## value: integer bonus (can be negative)
func add_modifier(stat: String, source: String, value: int) -> void:
	if not _modifiers.has(source):
		_modifiers[source] = {}
	_modifiers[source][stat] = value


## Remove ALL modifiers contributed by a given source.
func remove_modifier(source: String) -> void:
	_modifiers.erase(source)


## Return the total value of a stat (base + all active modifiers).
func get_total(stat: String) -> int:
	var base: int = _get_base(stat)
	var bonus: int = 0
	for source in _modifiers:
		var mod_dict: Dictionary = _modifiers[source]
		if mod_dict.has(stat):
			bonus += mod_dict[stat]
	return base + bonus

# ---------------------------------------------------------------------------
# Race data
# ---------------------------------------------------------------------------

## Apply base stats from a race data dictionary (as returned by DataLoader).
## Expected keys: "strength", "dexterity", "intelligence", "vitality".
## Missing keys are silently ignored (base stat remains unchanged).
func apply_race_data(race_data: Dictionary) -> void:
	if race_data.has("strength"):
		strength = int(race_data["strength"])
	if race_data.has("dexterity"):
		dexterity = int(race_data["dexterity"])
	if race_data.has("intelligence"):
		intelligence = int(race_data["intelligence"])
	if race_data.has("vitality"):
		vitality = int(race_data["vitality"])

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _get_base(stat: String) -> int:
	match stat:
		"strength":
			return strength
		"dexterity":
			return dexterity
		"intelligence":
			return intelligence
		"vitality":
			return vitality
		_:
			push_warning("StatsComponent: unknown stat '%s'" % stat)
			return 0
