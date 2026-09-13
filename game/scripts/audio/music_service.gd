extends Node
## Background music (Specification 22.8 and 23.5).
##
## Autoloaded as [code]MusicService[/code]. Screens ask for a track by id
## ([method play]) and the service crossfades from whatever is playing; the
## same id asked for twice changes nothing, so a screen can call it freely on
## every entry. Tracks live in [constant TRACKS]; a missing file leaves the
## game silent and reports once through [DevLog], so music is never required
## for play (Specification 23.5).
##
## The music volume is a user setting shared with [DisplayService]'s file.

## Emitted after the music volume changes, so an open settings screen can
## show the new value.
signal music_volume_changed(volume: float)

## Music id to file. Areas name their id in [member WorldArea.music_id].
const TRACKS: Dictionary = {
	&"title": "res://assets/music/title_theme.mp3",
	&"town": "res://assets/music/town_theme.mp3",
	&"field": "res://assets/music/field_theme.mp3",
	&"battle": "res://assets/music/battle_theme.mp3",
}

const CROSSFADE_SECONDS: float = 0.8
## Linear volume under which a player is treated as silent and stopped.
const SILENT_LEVEL: float = 0.001

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const MUSIC_VOLUME_SETTING: String = "music_volume"
const DEFAULT_MUSIC_VOLUME: float = 0.7

## Two players so one track can fade out while the next fades in.
var _players: Array[AudioStreamPlayer] = []
## Per-player crossfade level, 0 (silent) to 1 (full), separate from the user
## volume so the two never fight over [member AudioStreamPlayer.volume_db].
var _fade_levels: Array[float] = [0.0, 0.0]
## Index into [member _players] of the one carrying the current track.
var _active: int = 0
var _current_id: StringName = &""
var _music_volume: float = DEFAULT_MUSIC_VOLUME
var _fade: Tween
var _settings_loaded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Player%d" % i
		add_child(player)
		_players.append(player)
	_load_settings()
	_settings_loaded = true
	_apply_volumes()


## Crossfades to the track registered under [param id]. Nothing happens when
## it is already playing. An empty id is the same as [method stop].
func play(id: StringName) -> void:
	if id == _current_id:
		return
	if id == &"":
		stop()
		return
	_current_id = id
	var stream: AudioStream = _load_track(id)
	var outgoing: int = _active
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _players[_active]
	incoming.stop()
	if stream != null:
		DevLog.info("Music start: %s" % id)
		incoming.stream = stream
		_fade_levels[_active] = 0.0
		_apply_volume(_active)
		incoming.play()
	_crossfade(outgoing, _active if stream != null else -1)


## Fades the current track out.
func stop() -> void:
	if _current_id == &"":
		return
	DevLog.info("Music stop: %s" % _current_id)
	_current_id = &""
	_crossfade(_active, -1)


func current_id() -> StringName:
	return _current_id


## Linear music volume, 0 to 1.
func music_volume() -> float:
	return _music_volume


func set_music_volume(volume: float) -> void:
	volume = clampf(volume, 0.0, 1.0)
	if is_equal_approx(volume, _music_volume):
		return
	_music_volume = volume
	_apply_volumes()
	_save_settings()
	music_volume_changed.emit(_music_volume)


## Runs one tween that takes [param outgoing] to silence and, when it is not
## -1, [param incoming] to full. Players left silent are stopped at the end.
func _crossfade(outgoing: int, incoming: int) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_method(_set_fade_level.bind(outgoing), _fade_levels[outgoing], 0.0, CROSSFADE_SECONDS)
	if incoming >= 0:
		_fade.tween_method(_set_fade_level.bind(incoming), _fade_levels[incoming], 1.0, CROSSFADE_SECONDS)
	_fade.finished.connect(_stop_silent_players)


func _set_fade_level(level: float, index: int) -> void:
	_fade_levels[index] = level
	_apply_volume(index)


func _stop_silent_players() -> void:
	for i: int in _players.size():
		if _fade_levels[i] <= SILENT_LEVEL:
			_players[i].stop()


func _apply_volumes() -> void:
	for i: int in _players.size():
		_apply_volume(i)


func _apply_volume(index: int) -> void:
	var level: float = _music_volume * _fade_levels[index]
	_players[index].volume_db = linear_to_db(maxf(level, SILENT_LEVEL))


## The stream for [param id], set to loop, or null when the id is unknown or
## its file is absent. Either case is reported once.
func _load_track(id: StringName) -> AudioStream:
	var path: String = TRACKS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		DevLog.missing_asset("music", id)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		DevLog.missing_asset("music", id)
		return null
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_FILE_PATH) != OK:
		return
	_music_volume = clampf(
		float(settings.get_value(SETTINGS_SECTION, MUSIC_VOLUME_SETTING, DEFAULT_MUSIC_VOLUME)), 0.0, 1.0
	)


## Rewrites only the audio section, so display settings in the same file
## survive.
func _save_settings() -> void:
	if not _settings_loaded:
		return
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_FILE_PATH)
	settings.set_value(SETTINGS_SECTION, MUSIC_VOLUME_SETTING, _music_volume)
	var error: Error = settings.save(SETTINGS_FILE_PATH)
	if error != OK:
		push_warning("Could not save audio settings: %s" % error_string(error))
