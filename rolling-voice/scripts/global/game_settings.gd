extends Node
## (오토로드: GameSettings)
## 사용자 설정 저장/불러오기, 오디오 버스 구성, 공용 테마 보관.

signal changed

const SAVE_PATH := "user://settings.cfg"

const DIFFICULTIES: Array[Dictionary] = [
	{"name": "쉬움", "cents": 100.0, "pass": 0.30, "desc": "반음쯤 어긋나도 봐줘요"},
	{"name": "보통", "cents": 60.0, "pass": 0.45, "desc": "반음의 절반 안쪽으로 맞춰요"},
	{"name": "어려움", "cents": 35.0, "pass": 0.60, "desc": "거의 정확한 음정이 필요해요"},
]
const MAX_MISSES_LIMIT := 30

var max_misses := 5
var difficulty := 1
var ignore_octave := true
var guide_volume := 0.7
var backing_volume := 0.85
var sfx_volume := 0.8
var mic_threshold := 0.02
var input_device := "Default"
var last_song_id := ""

## 메뉴 → 게임으로 넘길 곡
var selected_song: SongData
var theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.build()
	_setup_buses()
	load_settings()
	SongLibrary.ensure_songs_dir()
	apply()


func tolerance_cents() -> float:
	return DIFFICULTIES[difficulty].cents


func pass_ratio() -> float:
	return DIFFICULTIES[difficulty].pass


func _setup_buses() -> void:
	for bus_name in ["Music", "Guide", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# 가이드 멜로디에 살짝 공간감
	var guide := AudioServer.get_bus_index("Guide")
	if AudioServer.get_bus_effect_count(guide) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.45
		reverb.damping = 0.6
		reverb.wet = 0.18
		reverb.dry = 0.9
		AudioServer.add_bus_effect(guide, reverb)
	# 마스터에 리미터: 소리가 갑자기 커지는 것 방지
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())


func apply() -> void:
	_set_bus_volume("Music", backing_volume)
	_set_bus_volume("Guide", guide_volume)
	_set_bus_volume("SFX", sfx_volume)
	PitchDetector.threshold = mic_threshold
	var devices := AudioServer.get_input_device_list()
	var wanted := input_device if devices.has(input_device) else "Default"
	if AudioServer.input_device != wanted:
		AudioServer.input_device = wanted
		PitchDetector.restart()
	changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "max_misses", max_misses)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "ignore_octave", ignore_octave)
	cfg.set_value("game", "last_song_id", last_song_id)
	cfg.set_value("audio", "guide_volume", guide_volume)
	cfg.set_value("audio", "backing_volume", backing_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "mic_threshold", mic_threshold)
	cfg.set_value("audio", "input_device", input_device)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	max_misses = clampi(cfg.get_value("game", "max_misses", max_misses), 1, MAX_MISSES_LIMIT)
	difficulty = clampi(cfg.get_value("game", "difficulty", difficulty), 0, DIFFICULTIES.size() - 1)
	ignore_octave = cfg.get_value("game", "ignore_octave", ignore_octave)
	last_song_id = cfg.get_value("game", "last_song_id", last_song_id)
	guide_volume = cfg.get_value("audio", "guide_volume", guide_volume)
	backing_volume = cfg.get_value("audio", "backing_volume", backing_volume)
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume)
	mic_threshold = cfg.get_value("audio", "mic_threshold", mic_threshold)
	input_device = cfg.get_value("audio", "input_device", input_device)
