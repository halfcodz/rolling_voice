extends Node
## (오토로드: PitchDetector)
## 마이크 입력에서 실시간으로 음높이를 추정한다.
## AudioStreamMicrophone → 음소거된 "MicInput" 버스의 AudioEffectCapture → 다운샘플 → YIN 알고리즘.

const BUS_NAME := "MicInput"
const TARGET_RATE := 11025.0     ## 분석용 샘플레이트(대략)
const WINDOW := 400              ## 분석 창 길이(다운샘플 기준, 약 36ms)
const MIN_HZ := 70.0
const MAX_HZ := 1100.0
const YIN_THRESHOLD := 0.15
const ANALYSIS_INTERVAL := 1.0 / 30.0

## 현재 추정값 (읽기 전용으로 쓰기)
var hz := 0.0
var midi := 0.0          ## 실수 MIDI 번호 (69.0 = A4 = 440Hz)
var voiced := false      ## 소리를 내는 중이고 음높이가 잡혔는가
var level := 0.0         ## 입력 크기(RMS, 0~1)
var threshold := 0.02    ## 이보다 작은 소리는 무시 (설정에서 바꿈)

var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _decim := 4
var _rate := 11025.0
var _buf := PackedFloat32Array()
var _acc := 0.0
var _acc_n := 0
var _timer := 0.0
var _recent: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mix := AudioServer.get_mix_rate()
	_decim = maxi(1, roundi(mix / TARGET_RATE))
	_rate = mix / _decim
	_setup_bus()
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS_NAME
	add_child(_player)
	_player.play()


func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
	# 내 목소리가 스피커로 다시 나오지 않도록 음소거 (이펙트 처리는 계속됨)
	AudioServer.set_bus_mute(idx, true)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, _capture, 0)


func restart() -> void:
	if _player == null:
		return
	_player.stop()
	_capture.clear_buffer()
	_buf.clear()
	_player.play()


func _process(delta: float) -> void:
	var n := _capture.get_frames_available()
	if n > 0:
		var frames := _capture.get_buffer(n)
		var decim := _decim
		for f in frames:
			_acc += (f.x + f.y) * 0.5
			_acc_n += 1
			if _acc_n >= decim:
				_buf.append(_acc / _acc_n)
				_acc = 0.0
				_acc_n = 0
		var keep := WINDOW + int(_rate / MIN_HZ) + 4
		if _buf.size() > keep * 2:
			_buf = _buf.slice(_buf.size() - keep)
	_timer += delta
	if _timer >= ANALYSIS_INTERVAL:
		_timer = 0.0
		_analyze()


func _analyze() -> void:
	var max_lag := int(_rate / MIN_HZ)
	if _buf.size() < WINDOW + max_lag + 2:
		_set_unvoiced(0.0)
		return
	var start := _buf.size() - WINDOW - max_lag - 2
	var sum := 0.0
	for i in WINDOW:
		var v := _buf[_buf.size() - WINDOW + i]
		sum += v * v
	var rms := sqrt(sum / WINDOW)
	level = lerpf(level, rms, 0.5)
	if rms < threshold:
		_set_unvoiced(rms)
		return
	var f := yin(_buf, start, WINDOW, _rate, MIN_HZ, MAX_HZ, YIN_THRESHOLD)
	if f <= 0.0:
		_set_unvoiced(rms)
		return
	var m := NoteUtils.hz_to_midi(f)
	_recent.append(m)
	if _recent.size() > 3:
		_recent.pop_front()
	var sorted := _recent.duplicate()
	sorted.sort()
	midi = sorted[sorted.size() / 2]
	hz = NoteUtils.midi_to_hz(midi)
	voiced = true


func _set_unvoiced(rms: float) -> void:
	level = lerpf(level, rms, 0.5)
	voiced = false
	_recent.clear()


## YIN 음높이 추정. 성공하면 Hz, 실패하면 -1.
## buf[start ... start + window + max_lag) 구간을 사용한다.
static func yin(buf: PackedFloat32Array, start: int, window: int, rate: float,
		min_hz: float, max_hz: float, thresh: float) -> float:
	var max_lag := int(rate / min_hz)
	var min_lag := maxi(2, int(rate / max_hz))
	var d := PackedFloat32Array()
	d.resize(max_lag + 2)
	d[0] = 1.0
	var running := 0.0
	for tau in range(1, max_lag + 2):
		var acc := 0.0
		var j := start + tau
		for i in window:
			var diff := buf[start + i] - buf[j + i]
			acc += diff * diff
		running += acc
		d[tau] = acc * tau / running if running > 0.0 else 1.0
	var best := -1
	var tau2 := min_lag
	while tau2 <= max_lag:
		if d[tau2] < thresh:
			while tau2 + 1 <= max_lag and d[tau2 + 1] < d[tau2]:
				tau2 += 1
			best = tau2
			break
		tau2 += 1
	if best < 0:
		# 임계값 아래가 없으면 전역 최솟값이 충분히 낮을 때만 인정
		var mn := 1e9
		for t in range(min_lag, max_lag + 1):
			if d[t] < mn:
				mn = d[t]
				best = t
		if mn > 0.35:
			return -1.0
	var better := float(best)
	if best > 1 and best < max_lag + 1:
		var a := d[best - 1]
		var b := d[best]
		var c := d[best + 1]
		var denom := 2.0 * (a - 2.0 * b + c)
		if absf(denom) > 1e-9:
			better += (a - c) / denom
	return rate / better
