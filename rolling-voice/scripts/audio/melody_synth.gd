class_name MelodySynth
extends Node
## 곡의 멜로디(가이드)와 카운트인 메트로놈을 AudioStreamGenerator로 실시간 합성한다.
## 별도 음원 파일 없이도 어떤 곡이든 따라 부를 수 있게 해 준다.

const BUFFER_SEC := 0.1

var playing := false

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rate := 44100.0
var _frame := 0
var _starts := PackedFloat32Array()
var _ends := PackedFloat32Array()
var _hz := PackedFloat32Array()
var _clicks := PackedFloat32Array()
var _idx := 0
var _click_idx := 0
var _phase := 0.0


func _ready() -> void:
	_rate = AudioServer.get_mix_rate()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _rate
	gen.buffer_length = BUFFER_SEC
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = "Guide"
	add_child(_player)


func setup(song: SongData) -> void:
	_starts.clear()
	_ends.clear()
	_hz.clear()
	for n in song.notes:
		_starts.append(n.start)
		_ends.append(n.end)
		_hz.append(NoteUtils.midi_to_hz(n.midi))
	_clicks = song.click_times.duplicate()


func start() -> void:
	_frame = 0
	_idx = 0
	_click_idx = 0
	_phase = 0.0
	_player.play()
	_playback = _player.get_stream_playback()
	playing = true
	_fill()


func stop() -> void:
	playing = false
	_player.stop()


## 소리를 서서히 줄이며 멈춘다.
func fade_out(sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", -60.0, sec)
	tw.tween_callback(stop)


func _process(_delta: float) -> void:
	if playing:
		_fill()


func _fill() -> void:
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var count := _starts.size()
	var inv_rate := 1.0 / _rate
	for i in n:
		var t := (_frame + i) * inv_rate
		var s := 0.0
		while _idx < count and _ends[_idx] <= t:
			_idx += 1
		if _idx < count and t >= _starts[_idx]:
			var local := t - _starts[_idx]
			var remain := _ends[_idx] - t
			var env := minf(1.0, local / 0.012) * minf(1.0, remain / 0.05)
			env *= 0.7 + 0.3 * exp(-local * 4.0)
			_phase = fmod(_phase + _hz[_idx] * inv_rate, 1.0)
			var ph := _phase * TAU
			s = (sin(ph) + 0.32 * sin(2.0 * ph) + 0.12 * sin(3.0 * ph) + 0.05 * sin(4.0 * ph)) * 0.2 * env
		# 카운트인 클릭
		while _click_idx < _clicks.size() and t - _clicks[_click_idx] > 0.06:
			_click_idx += 1
		if _click_idx < _clicks.size():
			var ct := t - _clicks[_click_idx]
			if ct >= 0.0:
				var pitch := 1760.0 if _click_idx == 0 else 1320.0
				s += sin(TAU * pitch * ct) * exp(-ct * 70.0) * 0.35
		buf[i] = Vector2(s, s)
	_playback.push_buffer(buf)
	_frame += n
