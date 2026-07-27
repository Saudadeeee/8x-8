# res://scripts/managers/AudioManager.gd
# Autoload: AudioManagerSingleton — SFX pool + music loop.
# API: play_sfx(name, volume_db, pitch_scale) · play_music() · stop_music()
extends Node

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const POOL_SIZE: int = 12
const MUSIC_VOLUME_DB: float = -16.0
const PITCH_VARIANCE: float = 0.07   # ±7% để SFX lặp không bị đơn điệu

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var sfx_enabled: bool = true
var music_enabled: bool = true

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)

## Phát SFX theo tên file (assets/audio/sfx/<name>.wav). Pitch jitter nhẹ mặc định.
func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sfx_enabled:
		return
	var stream := _get_stream(sfx_name)
	if stream == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale * randf_range(1.0 - PITCH_VARIANCE, 1.0 + PITCH_VARIANCE)
	p.play()

func play_music() -> void:
	if not music_enabled or _music_player.playing:
		return
	var stream := _get_stream("music_loop")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2   # 16-bit mono: 2 byte / sample
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func _get_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var path := SFX_DIR % sfx_name
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: thiếu SFX '%s'" % sfx_name)
		_streams[sfx_name] = null
		return null
	var stream := load(path) as AudioStream
	_streams[sfx_name] = stream
	return stream
