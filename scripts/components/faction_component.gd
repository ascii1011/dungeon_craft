## FactionComponent
## Tracks an entity's allegiance (which faction it belongs to) and its
## reputation with every known faction. Attach as a child node to any entity
## that participates in the faction system.
class_name FactionComponent
extends Node

# ---------------------------------------------------------------------------
# Constants — supported factions for v1
# ---------------------------------------------------------------------------

const FACTIONS: Array[String] = ["townspeople", "dungeon_guild", "monsters"]

const REP_MIN: int = -1000
const REP_MAX: int = 1000

# Reputation thresholds that affect hostility / standing.
const HOSTILE_THRESHOLD: int = -200   # player vs townspeople

# Standing tier boundaries (inclusive lower bound).
const TIER_HATED: int    = -500
const TIER_HOSTILE: int  = -200
const TIER_NEUTRAL: int  = 200
const TIER_FRIENDLY: int = 500

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## The faction this entity belongs to (e.g. "player", "monsters", "townspeople").
@export var faction: String = "player"

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## Reputation values keyed by faction ID.
var _reputation: Dictionary = {
	"townspeople": 0,
	"dungeon_guild": 0,
	"monsters": -100,
}

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal reputation_changed(faction_id: String, new_value: int, old_value: int)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Return the current reputation value for faction_id.
## Returns 0 for unknown faction IDs.
func get_reputation(faction_id: String) -> int:
	return _reputation.get(faction_id, 0)


## Modify the reputation for faction_id by amount (positive or negative).
## The resulting value is clamped to [REP_MIN, REP_MAX].
## Emits reputation_changed if the value actually changes.
func modify_reputation(faction_id: String, amount: int) -> void:
	if not _reputation.has(faction_id):
		_reputation[faction_id] = 0

	var old_value: int = _reputation[faction_id]
	var new_value: int = clampi(old_value + amount, REP_MIN, REP_MAX)

	if new_value == old_value:
		return

	_reputation[faction_id] = new_value
	reputation_changed.emit(faction_id, new_value, old_value)


## Returns true when this component's entity is hostile toward other's entity.
## Hostility rules for v1:
##   - monsters are always hostile toward the player faction.
##   - player becomes hostile to townspeople if rep < HOSTILE_THRESHOLD.
func is_hostile_to(other: FactionComponent) -> bool:
	# Monsters are always hostile to the player.
	if faction == "monsters" and other.faction == "player":
		return true
	if faction == "player" and other.faction == "monsters":
		return true

	# Player is hostile to townspeople when reputation is below threshold.
	if faction == "player" and other.faction == "townspeople":
		return _reputation.get("townspeople", 0) < HOSTILE_THRESHOLD
	if faction == "townspeople" and other.faction == "player":
		# Symmetric: townspeople treat the player as hostile when player rep is low.
		return other._reputation.get("townspeople", 0) < HOSTILE_THRESHOLD

	return false


## Return a human-readable standing label for faction_id based on current rep.
## Tiers: Hated (< -500), Hostile (< -200), Neutral (< 200),
##        Friendly (< 500), Exalted (>= 500).
func get_standing(faction_id: String) -> String:
	var rep: int = get_reputation(faction_id)
	if rep < TIER_HATED:
		return "Hated"
	elif rep < TIER_HOSTILE:
		return "Hostile"
	elif rep < TIER_NEUTRAL:
		return "Neutral"
	elif rep < TIER_FRIENDLY:
		return "Friendly"
	else:
		return "Exalted"
