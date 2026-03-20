## GameState
## Autoload singleton that holds the single authoritative source of truth for
## all mutable game state. Every system that needs to read or mutate runtime
## state goes through this node so multiplayer-readiness is preserved: a future
## network layer only has to intercept changes here rather than hunt through
## every subsystem.
extends Node

# ---------------------------------------------------------------------------
# State properties
# ---------------------------------------------------------------------------

## Current player statistics, world position, and inventory reference.
## Mutate via helper functions when possible so signals are emitted correctly.
var player_data: Dictionary = {}

## Identifier of the zone/floor the player is currently in.
var current_zone: String = ""

## Total elapsed in-game time, in seconds. Incremented by the game loop.
var game_time: float = 0.0

## Whether the game is currently paused.
var is_paused: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	reset()

# ---------------------------------------------------------------------------
# Pause / Resume
# ---------------------------------------------------------------------------

## Pause the game. Emits EventBus.game_paused.
func pause() -> void:
	if is_paused:
		return
	is_paused = true
	EventBus.game_paused.emit()

## Resume the game. Emits EventBus.game_resumed.
func resume() -> void:
	if not is_paused:
		return
	is_paused = false
	EventBus.game_resumed.emit()

# ---------------------------------------------------------------------------
# Zone management
# ---------------------------------------------------------------------------

## Change the active zone. Emits EventBus.player_zone_changed.
func change_zone(zone_id: String) -> void:
	current_zone = zone_id
	EventBus.player_zone_changed.emit(zone_id)

# ---------------------------------------------------------------------------
# State reset
# ---------------------------------------------------------------------------

## Reset all state to clean defaults. Call this before starting a new game or
## tearing down a test so state does not bleed between runs.
func reset() -> void:
	player_data = {
		"name": "",
		"race": "",
		"level": 1,
		"hp": 100,
		"max_hp": 100,
		"mp": 50,
		"max_mp": 50,
		"gold": 0,
		"xp": 0,
		"position": Vector2.ZERO,
		"inventory": [],
		"equipment": {},
	}
	current_zone = ""
	game_time = 0.0
	is_paused = false

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

## Return a fully serializable snapshot of the current game state suitable
## for writing to disk (e.g. as JSON via DataLoader or FileAccess).
func save_state() -> Dictionary:
	# Vector2 is not natively JSON-serialisable, so flatten to a plain dict.
	var pos: Vector2 = player_data.get("position", Vector2.ZERO)
	var snapshot := player_data.duplicate(true)
	snapshot["position"] = {"x": pos.x, "y": pos.y}

	return {
		"player_data": snapshot,
		"current_zone": current_zone,
		"game_time": game_time,
		"is_paused": is_paused,
	}

## Restore game state from a previously created snapshot dictionary.
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		push_error("GameState.load_state: received empty data dictionary.")
		return

	if data.has("player_data"):
		player_data = data["player_data"].duplicate(true)
		# Re-hydrate the position back to Vector2 if it was flattened.
		var pos = player_data.get("position", null)
		if pos is Dictionary:
			player_data["position"] = Vector2(
				pos.get("x", 0.0),
				pos.get("y", 0.0)
			)

	if data.has("current_zone"):
		current_zone = data["current_zone"]

	if data.has("game_time"):
		game_time = float(data["game_time"])

	if data.has("is_paused"):
		is_paused = bool(data["is_paused"])
