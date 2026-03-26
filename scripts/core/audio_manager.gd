## AudioManager
## Autoload-style Node managing all game audio: music with fade in/out,
## SFX round-robin pool, EventBus wiring, and settings persistence.
##
## Prerequisites (must be configured manually in the Godot editor):
##   - AudioServer buses: "Master", "Music", "SFX"
##     Go to Project > Audio > Add buses named "Music" and "SFX".
##   - Add this node (or scenes/main/audio_manager.tscn) as an autoload in
##     Project > Project Settings > Autoloads.

extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var music_volume_db: float = -10.0
@export var sfx_volume_db: float = 0.0

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SOUND_MAP = {
	"player_attack":    "res://assets/audio/sfx/player_attack.ogg",
	"player_hurt":      "res://assets/audio/sfx/player_hurt.ogg",
	"player_died":      "res://assets/audio/sfx/player_died.ogg",
	"enemy_died":       "res://assets/audio/sfx/enemy_died.ogg",
	"item_pickup":      "res://assets/audio/sfx/item_pickup.ogg",
	"spell_cast":       "res://assets/audio/sfx/spell_cast.ogg",
	"gold_pickup":      "res://assets/audio/sfx/gold_pickup.ogg",
	"chest_open":       "res://assets/audio/sfx/chest_open.ogg",
	"shop_open":        "res://assets/audio/sfx/shop_open.ogg",
	"ui_click":         "res://assets/audio/sfx/ui_click.ogg",
	"music_dungeon_01": "res://assets/audio/music/dungeon_ambient_01.ogg",
	"music_menu":       "res://assets/audio/music/main_menu.ogg",
}

const _SFX_POOL_SIZE := 8
const _SETTINGS_PATH := "user://audio_settings.cfg"
const _FADE_DURATION := 1.5

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _current_music_path: String = ""
var _music_tween: Tween

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_music_player()
	_build_sfx_pool()
	load_audio_settings()
	_connect_event_bus()


func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = music_volume_db
	add_child(_music_player)


func _build_sfx_pool() -> void:
	for i in _SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = sfx_volume_db
		add_child(player)
		_sfx_pool.append(player)


func _connect_event_bus() -> void:
	if not Engine.has_singleton("EventBus"):
		push_warning("AudioManager: EventBus singleton not found — skipping signal wiring.")
		return

	var eb = Engine.get_singleton("EventBus")

	_safe_connect(eb, "player_died",   _on_player_died)
	_safe_connect(eb, "enemy_died",    _on_enemy_died)
	_safe_connect(eb, "item_picked_up", _on_item_picked_up)
	_safe_connect(eb, "spell_cast",    _on_spell_cast)
	_safe_connect(eb, "gold_changed",  _on_gold_changed)
	_safe_connect(eb, "game_paused",   _on_game_paused)
	_safe_connect(eb, "game_resumed",  _on_game_resumed)


func _safe_connect(target: Object, signal_name: String, callable: Callable) -> void:
	if target.has_signal(signal_name):
		target.connect(signal_name, callable)
	else:
		push_warning("AudioManager: EventBus has no signal '%s' — skipping." % signal_name)

# ---------------------------------------------------------------------------
# EventBus handlers
# ---------------------------------------------------------------------------

func _on_player_died() -> void:
	play_sfx(SOUND_MAP["player_died"])

func _on_enemy_died() -> void:
	play_sfx(SOUND_MAP["enemy_died"])

func _on_item_picked_up() -> void:
	play_sfx(SOUND_MAP["item_pickup"])

func _on_spell_cast() -> void:
	play_sfx(SOUND_MAP["spell_cast"])

func _on_gold_changed() -> void:
	play_sfx(SOUND_MAP["gold_pickup"])

func _on_game_paused() -> void:
	stop_music(false)

func _on_game_resumed() -> void:
	play_music(SOUND_MAP["music_dungeon_01"])

# ---------------------------------------------------------------------------
# Music API
# ---------------------------------------------------------------------------

## Play a music track from the given resource path.
## If the same track is already playing the call is ignored.
## When [param fade_in] is true the volume tweens from -80 dB to
## [member music_volume_db] over 1.5 seconds.
func play_music(stream_path: String, fade_in: bool = true) -> void:
	if stream_path == _current_music_path and _music_player.playing:
		return

	if not ResourceLoader.exists(stream_path):
		push_warning("AudioManager: music file not found: %s" % stream_path)
		return

	var stream: AudioStream = load(stream_path)
	if stream == null:
		push_warning("AudioManager: failed to load music: %s" % stream_path)
		return

	_current_music_path = stream_path
	_music_player.stream = stream

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	if fade_in:
		_music_player.volume_db = -80.0
		_music_player.play()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", music_volume_db, _FADE_DURATION)
	else:
		_music_player.volume_db = music_volume_db
		_music_player.play()


## Stop the currently playing music track.
## When [param fade_out] is true the volume tweens to -80 dB before stopping.
func stop_music(fade_out: bool = true) -> void:
	if not _music_player.playing:
		return

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	if fade_out:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -80.0, _FADE_DURATION)
		_music_tween.tween_callback(_music_player.stop)
		_music_tween.tween_callback(func() -> void: _current_music_path = "")
	else:
		_music_player.stop()
		_current_music_path = ""


## Set the master music volume in dB and apply it immediately.
func set_music_volume(volume_db: float) -> void:
	music_volume_db = volume_db
	# Only update live volume when not in a fade tween.
	if not (_music_tween and _music_tween.is_valid() and _music_tween.is_running()):
		_music_player.volume_db = music_volume_db

# ---------------------------------------------------------------------------
# SFX API
# ---------------------------------------------------------------------------

## Play a one-shot sound effect using the round-robin pool.
## Missing files are handled gracefully with a push_warning.
func play_sfx(stream_path: String) -> void:
	if not ResourceLoader.exists(stream_path):
		push_warning("AudioManager: SFX file not found: %s" % stream_path)
		return

	var stream: AudioStream = load(stream_path)
	if stream == null:
		push_warning("AudioManager: failed to load SFX: %s" % stream_path)
		return

	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _SFX_POOL_SIZE

	player.stream = stream
	player.volume_db = sfx_volume_db
	player.play()


## Set the SFX bus volume in dB and update all pool players.
func set_sfx_volume(volume_db: float) -> void:
	sfx_volume_db = volume_db
	for player in _sfx_pool:
		player.volume_db = sfx_volume_db

# ---------------------------------------------------------------------------
# Settings persistence
# ---------------------------------------------------------------------------

## Persist current volume settings to [code]user://audio_settings.cfg[/code].
func save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume_db", music_volume_db)
	config.set_value("audio", "sfx_volume_db", sfx_volume_db)
	var err := config.save(_SETTINGS_PATH)
	if err != OK:
		push_warning("AudioManager: could not save audio settings (error %d)" % err)


## Load volume settings from [code]user://audio_settings.cfg[/code] and apply them.
## Silently skips if the file does not yet exist.
func load_audio_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(_SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning("AudioManager: could not load audio settings (error %d)" % err)
		return

	set_music_volume(config.get_value("audio", "music_volume_db", music_volume_db))
	set_sfx_volume(config.get_value("audio", "sfx_volume_db", sfx_volume_db))
