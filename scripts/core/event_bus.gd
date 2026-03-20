## EventBus
## Autoload singleton that acts as a centralised signal hub. Systems emit and
## connect here instead of holding direct references to each other, keeping
## coupling low. A listener never needs to know which object fired an event.
##
## Usage:
##   Emit:   EventBus.player_health_changed.emit(hp, max_hp)
##   Listen: EventBus.player_health_changed.connect(_on_health_changed)
extends Node

# ---------------------------------------------------------------------------
# Player signals
# ---------------------------------------------------------------------------

## Emitted when the player's current or maximum HP changes.
signal player_health_changed(new_hp: int, max_hp: int)

## Emitted when the player's HP reaches zero (before any respawn logic).
signal player_died()

## Emitted after the player successfully transitions to a new zone.
signal player_zone_changed(zone_id: String)

# ---------------------------------------------------------------------------
# Enemy signals
# ---------------------------------------------------------------------------

## Emitted when an enemy's HP reaches zero.
## @param enemy_id  The string identifier of the enemy type.
## @param position  World position where the enemy died (for loot/VFX spawning).
signal enemy_died(enemy_id: String, position: Vector2)

# ---------------------------------------------------------------------------
# Inventory / Equipment signals
# ---------------------------------------------------------------------------

## Emitted when the player picks up an item from the world.
signal item_picked_up(item_id: String)

## Emitted when an item is moved into an equipment slot.
signal item_equipped(item_id: String, slot: String)

# ---------------------------------------------------------------------------
# Spell signals
# ---------------------------------------------------------------------------

## Emitted at the moment a spell is cast.
## @param caster  The Node that initiated the cast (player, enemy, etc.).
signal spell_cast(spell_id: String, caster: Node)

# ---------------------------------------------------------------------------
# Game flow signals
# ---------------------------------------------------------------------------

## Emitted by GameState.pause() when the game enters a paused state.
signal game_paused()

## Emitted by GameState.resume() when the game leaves a paused state.
signal game_resumed()

# ---------------------------------------------------------------------------
# Economy / Progression signals
# ---------------------------------------------------------------------------

## Emitted whenever the player's gold total changes.
signal gold_changed(new_amount: int)

## Emitted when the player gains experience points.
signal xp_gained(amount: int)

# ---------------------------------------------------------------------------
# Shop signals
# ---------------------------------------------------------------------------

## Emitted when a shop UI is opened.
signal shop_opened(shop_id: String)

## Emitted when the shop UI is dismissed.
signal shop_closed()
