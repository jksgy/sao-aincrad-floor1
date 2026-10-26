extends Node
## AudioManager: music with crossfade, SFX pool with anti-spam limits.

const MUSIC := {
	"town": "res://assets/audio/music_town.wav",
	"field": "res://assets/audio/music_field.wav",
	"dungeon": "res://assets/audio/music_dungeon.wav",
	"boss": "res://assets/audio/music_boss.wav",
	"title": "res://assets/audio/music_town.wav",
}

var _music: AudioStreamPlayer
var _music_prev: AudioStreamPlayer
var _sfx_pool: Array = []
var _sfx_idx := 0
var _last_played: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music_prev = AudioStreamPlayer.new()
	_music_prev.bus = "Music"
	add_child(_music_prev)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	apply_volumes()

func apply_volumes() -> void:
	var s: Dictionary = GameState.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(s.get("master", 0.8)), 0.0, 1.0)))
	AudioServer.set_bus_volume_db(1, linear_to_db(clampf(float(s.get("music", 0.65)), 0.0, 1.0)))
	AudioServer.set_bus_volume_db(2, linear_to_db(clampf(float(s.get("sfx", 0.8)), 0.0, 1.0)))

func _stream(path: String) -> AudioStream:
	if not _music_cache.has(path):
		var st: AudioStream = load(path)
		if st is AudioStreamWAV:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			# 16-bit mono: loop_end is in frames = bytes / 2
			st.loop_end = int(st.data.size() / 2)
		_music_cache[path] = st
	return _music_cache[path]

func play_music(track_id: String, fade := 0.8) -> void:
	var path: String = MUSIC.get(track_id, MUSIC["title"])
	if _music.stream != null and _music.stream.resource_path == path:
		return
	_music_prev.stream = _music.stream
	_music_prev.volume_db = _music.volume_db
	_music_prev.play()
	_music.stream = _stream(path)
	_music.volume_db = -60.0
	_music.play()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_music, "volume_db", 0.0, fade)
	if _music_prev.stream != null:
		tw.parallel().tween_property(_music_prev, "volume_db", -60.0, fade)

func play_sfx(name: String, volume_scale := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _last_played.get(name, 0.0) + 0.05 > now:
		return
	_last_played[name] = now
	var limit := int(Config.b("audio_limits.max_same_sfx_in_0.3s", 3))
	var recent := 0
	for k in _last_played.keys():
		if k == name and _last_played[k] > now - 0.3:
			recent += 1
	if recent > limit:
		return
	var path := "res://assets/audio/%s.wav" % name
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	var p: AudioStreamPlayer = _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[path]
	p.volume_db = linear_to_db(clampf(volume_scale, 0.0, 1.5))
	p.pitch_scale = 1.0
	p.play()
