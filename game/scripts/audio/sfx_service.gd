extends Node
## One-shot sound effects (Specification 22.8 and 23.5).
##
## Autoloaded as [code]SfxService[/code]. Callers ask for a sound by id
## ([method play]); an id with several files plays one at random so repeated
## hits do not sound stamped. A missing id or file stays silent and is
## reported once through [DevLog], so sound is never required for play.
##
## The effects volume is a user setting kept in the same file as the music
## and display settings.

## Emitted after the effects volume changes, so an open settings screen can
## show the new value.
signal sfx_volume_changed(volume: float)

## Sound id to its files and a per-sound trim in decibels, so quiet sources
## can be brought up to the rest without editing the file.
const SOUNDS: Dictionary = {
	&"hit": {"files": ["res://assets/sfx/hit_01.ogg", "res://assets/sfx/hit_02.ogg", "res://assets/sfx/hit_03.ogg"], "db": 0.0},
	&"hit_strong": {"files": ["res://assets/sfx/hit_strong_01.ogg", "res://assets/sfx/hit_strong_02.ogg"], "db": 1.0},
	&"hit_weak": {"files": ["res://assets/sfx/hit_weak_01.ogg"], "db": -4.0},
	&"bind_attempt": {"files": ["res://assets/sfx/bind_attempt.ogg"], "db": 5.0},
	&"bind_success": {"files": ["res://assets/sfx/bind_success.ogg"], "db": 0.0},
	&"bind_fail": {"files": ["res://assets/sfx/bind_fail.ogg"], "db": 6.0},
	&"faint": {"files": ["res://assets/sfx/faint.ogg"], "db": -3.0},
}

## Sounds that can overlap before the oldest is cut off.
const VOICES: int = 8
const SILENT_LEVEL: float = 0.001

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const SFX_VOLUME_SETTING: String = "sfx_volume"
const DEFAULT_SFX_VOLUME: float = 0.8

var _players: Array[AudioStreamPlayer] = []
## Round-robin cursor into [member _players].
var _next_voice: int = 0
var _sfx_volume: float = DEFAULT_SFX_VOLUME
var _settings_loaded: bool = false
## Loaded streams by path, so a repeated hit does not hit the disk.
var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_players.append(player)
	_load_settings()
	_settings_loaded = true


## Plays the sound registered under [param id] once.
func play(id: StringName) -> void:
	var stream: AudioStream = _load_sound(id)
	if stream == null:
		return
	var trim: float = float((SOUNDS[id] as Dictionary).get("db", 0.0))
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(_sfx_volume, SILENT_LEVEL)) + trim
	player.play()


## Linear effects volume, 0 to 1.
func sfx_volume() -> float:
	return _sfx_volume


func set_sfx_volume(volume: float) -> void:
	volume = clampf(volume, 0.0, 1.0)
	if is_equal_approx(volume, _sfx_volume):
		return
	_sfx_volume = volume
	_save_settings()
	sfx_volume_changed.emit(_sfx_volume)


## One of the files registered for [param id], or null when the id is unknown
## or the chosen file is absent. Either case is reported once.
func _load_sound(id: StringName) -> AudioStream:
	if not SOUNDS.has(id):
		DevLog.missing_asset("sfx", id)
		return null
	var files: Array = (SOUNDS[id] as Dictionary).get("files", [])
	if files.is_empty():
		DevLog.missing_asset("sfx", id)
		return null
	var path: String = files[_rng.randi_range(0, files.size() - 1)]
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		DevLog.missing_asset("sfx", id)
		return null
	_cache[path] = stream
	return stream


func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_FILE_PATH) != OK:
		return
	_sfx_volume = clampf(
		float(settings.get_value(SETTINGS_SECTION, SFX_VOLUME_SETTING, DEFAULT_SFX_VOLUME)), 0.0, 1.0
	)


## Rewrites only its own key, so the display and music settings in the same
## file survive.
func _save_settings() -> void:
	if not _settings_loaded:
		return
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_FILE_PATH)
	settings.set_value(SETTINGS_SECTION, SFX_VOLUME_SETTING, _sfx_volume)
	var error: Error = settings.save(SETTINGS_FILE_PATH)
	if error != OK:
		push_warning("Could not save audio settings: %s" % error_string(error))
