class_name MelodyExtractor
extends Node
## 음원 파일(mp3/ogg/wav)에서 멜로디를 뽑아 텍스트 악보(.txt) 초안을 만든다.
##
## 1) 캡처: 음소거된 "Analyze" 버스에서 4배속으로 재생하며 AudioEffectCapture로 받는다.
##    4배속 재생본을 믹스 레이트로 받으면 원래 시간 기준으로는 (믹스 레이트 / 4) ≈ 11~12kHz 샘플이 된다.
##    버스의 하이패스/로우패스 필터로 베이스와 고음 잡음을 줄여 보컬 대역을 강조한다.
## 2) 분석: 20ms마다 YIN으로 음높이를 잰다(프레임마다 시간 예산을 나눠 화면이 멈추지 않게).
## 3) 정리: 중간값 필터 → 반음 반올림 → 짧은 흔들림·끊김 메우기 → 음표로 묶기 → 악보 저장.
##
## 보컬이나 멜로디 악기가 또렷한 음원일수록 정확하다. 반주만 있는 음원은 멜로디를 찾기 어렵다.

signal progress(phase: String, ratio: float)
signal finished(chart_path: String, note_count: int)
signal failed(message: String)

const SPEED := 4.0
const HOP := 0.02            ## 분석 간격(초, 원래 시간 기준)
const WINDOW := 400
const MIN_HZ := 70.0
const MAX_HZ := 1100.0
const YIN_THRESHOLD := 0.2
const MIN_NOTE := 0.12       ## 이보다 짧은 음표는 버림
const MAX_LENGTH := 15 * 60.0
const BUS := "Analyze"
const FRAME_BUDGET_MS := 8

enum Phase { IDLE, CAPTURE, ANALYZE }

var phase := Phase.IDLE
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _samples := PackedFloat32Array()
var _rate := 11025.0
var _length := 0.0
var _audio_name := ""
var _title := ""
var _pitches := PackedFloat32Array()
var _rms := PackedFloat32Array()
var _frame := 0
var _frame_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var idx := AudioServer.get_bus_index(BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_mute(idx, true)
		# 4배속 재생이므로 주파수도 4배: 원래 90Hz 하이패스 / 1800Hz 로우패스
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 90.0 * SPEED
		AudioServer.add_bus_effect(idx, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = minf(1800.0 * SPEED, AudioServer.get_mix_rate() * 0.45)
		AudioServer.add_bus_effect(idx, lp)
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 1.0
		AudioServer.add_bus_effect(idx, cap)
	for i in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectCapture:
			_capture = fx
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	_player.pitch_scale = SPEED
	add_child(_player)


## src_path: 사용자가 고른 음원(어디든). 노래 폴더로 복사한 뒤 분석한다.
func extract(src_path: String) -> void:
	var stream := SongLibrary.load_audio_stream(src_path)
	if stream == null:
		failed.emit("이 음원 파일을 열 수 없어요 (mp3·ogg·wav만 돼요)")
		return
	_length = stream.get_length()
	if _length <= 1.0:
		failed.emit("음원 길이를 알 수 없거나 너무 짧아요")
		return
	if _length > MAX_LENGTH:
		failed.emit("15분보다 긴 음원은 분석하지 않아요")
		return
	SongLibrary.ensure_songs_dir()
	var dst := _copy_into_songs(src_path)
	if dst.is_empty():
		failed.emit("음원을 노래 폴더로 복사하지 못했어요")
		return
	_audio_name = dst.get_file()
	_title = src_path.get_file().get_basename()
	_rate = AudioServer.get_mix_rate() / SPEED
	_samples.clear()
	_capture.clear_buffer()
	_player.stream = stream
	_player.play()
	phase = Phase.CAPTURE
	progress.emit("음원 듣는 중", 0.0)


func cancel() -> void:
	_player.stop()
	phase = Phase.IDLE


func _copy_into_songs(src: String) -> String:
	var dst := SongLibrary.SONGS_DIR.path_join(src.get_file())
	if ProjectSettings.globalize_path(dst).simplify_path() == ProjectSettings.globalize_path(src).simplify_path():
		return dst
	if FileAccess.file_exists(dst):
		if FileAccess.get_file_as_bytes(dst).size() == FileAccess.get_file_as_bytes(src).size():
			return dst  # 이미 복사돼 있음
		dst = SongLibrary.SONGS_DIR.path_join("%s (%d).%s" % [src.get_file().get_basename(), Time.get_unix_time_from_system() as int % 10000, src.get_extension()])
	return dst if DirAccess.copy_absolute(src, dst) == OK else ""


func _process(_delta: float) -> void:
	match phase:
		Phase.CAPTURE:
			_pull_capture()
			var pos := _player.get_playback_position() if _player.playing else _length
			progress.emit("음원 듣는 중", clampf(pos / _length, 0.0, 1.0) * 0.5)
			if not _player.playing:
				_pull_capture()
				_begin_analysis()
		Phase.ANALYZE:
			_analyze_some()


func _pull_capture() -> void:
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var frames := _capture.get_buffer(n)
	var start := _samples.size()
	_samples.resize(start + frames.size())
	for i in frames.size():
		_samples[start + i] = (frames[i].x + frames[i].y) * 0.5


func _begin_analysis() -> void:
	var hop_samples := _rate * HOP
	var max_lag := int(_rate / MIN_HZ)
	_frame_count = maxi(0, int((_samples.size() - WINDOW - max_lag - 2) / hop_samples))
	if _frame_count < 10:
		phase = Phase.IDLE
		failed.emit("소리를 거의 받지 못했어요")
		return
	_pitches.resize(_frame_count)
	_rms.resize(_frame_count)
	_frame = 0
	phase = Phase.ANALYZE


func _analyze_some() -> void:
	var t0 := Time.get_ticks_msec()
	var hop_samples := _rate * HOP
	var max_lag := int(_rate / MIN_HZ)
	while _frame < _frame_count and Time.get_ticks_msec() - t0 < FRAME_BUDGET_MS:
		var start := int(_frame * hop_samples)
		var sum := 0.0
		for i in range(0, WINDOW, 2):
			var v := _samples[start + i]
			sum += v * v
		var rms := sqrt(sum / (WINDOW / 2.0))
		_rms[_frame] = rms
		var midi := -1.0
		if rms > 0.003:
			var hz: float = load("res://scripts/audio/pitch_detector.gd").yin(_samples, start, WINDOW, _rate, MIN_HZ, MAX_HZ, YIN_THRESHOLD)
			if hz > 0.0:
				midi = NoteUtils.hz_to_midi(hz)
		_pitches[_frame] = midi
		_frame += 1
	progress.emit("멜로디 찾는 중", 0.5 + 0.5 * float(_frame) / _frame_count)
	if _frame >= _frame_count:
		phase = Phase.IDLE
		_finish()


func _finish() -> void:
	# 조용한 구간(곡 전체 음량의 상위 10% 기준 12% 미만)은 무성으로 본다
	var sorted := _rms.duplicate()
	sorted.sort()
	var loud := sorted[int(sorted.size() * 0.9)] if sorted.size() > 0 else 0.0
	var gate := maxf(0.004, loud * 0.12)
	for i in _pitches.size():
		if _rms[i] < gate:
			_pitches[i] = -1.0
	var notes := segment(_pitches, HOP)
	if notes.is_empty():
		failed.emit("멜로디를 찾지 못했어요. 보컬이나 멜로디가 또렷한 음원으로 해 보세요")
		return
	var path := SongLibrary.SONGS_DIR.path_join(_title + ".txt")
	var n := 2
	while FileAccess.file_exists(path):
		path = SongLibrary.SONGS_DIR.path_join("%s (자동 %d).txt" % [_title, n])
		n += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		failed.emit("악보 파일을 저장하지 못했어요")
		return
	f.store_string(to_chart(notes, _title, _audio_name))
	f.close()
	finished.emit(path, notes.size())


## 프레임별 음높이(실수 MIDI, 무성은 -1) → 음표 [{start, end, midi}]
static func segment(pitches: PackedFloat32Array, hop: float) -> Array[Dictionary]:
	var n := pitches.size()
	# 1) 중간값 필터(5프레임). 창 안에서 유성이 과반일 때만 값을 낸다.
	var smooth := PackedFloat32Array()
	smooth.resize(n)
	for i in n:
		var vals: Array[float] = []
		for k in range(maxi(0, i - 2), mini(n, i + 3)):
			if pitches[k] >= 0.0:
				vals.append(pitches[k])
		if pitches[i] < 0.0 and vals.size() < 3:
			smooth[i] = -1.0
		elif vals.is_empty():
			smooth[i] = -1.0
		else:
			vals.sort()
			smooth[i] = vals[vals.size() / 2]
	# 2) 반음 반올림
	var q := PackedInt32Array()
	q.resize(n)
	for i in n:
		q[i] = roundi(smooth[i]) if smooth[i] >= 0.0 else -1
	# 3) 짧은 흔들림(3프레임 미만) → 앞 음으로, 짧은 끊김(4프레임 이하) → 앞 음 유지
	var runs := _runs(q)
	for r in runs.size():
		var run: Array = runs[r]
		var length: int = run[2] - run[1]
		var prev_val: int = runs[r - 1][0] if r > 0 else -1
		var next_val: int = runs[r + 1][0] if r + 1 < runs.size() else -1
		var fill := -2
		if run[0] >= 0 and length < 3 and prev_val >= 0:
			fill = prev_val
		elif run[0] < 0 and length <= 4 and prev_val >= 0 and next_val >= 0:
			fill = prev_val
		if fill != -2:
			for i in range(run[1], run[2]):
				q[i] = fill
	# 4) 짧은 옥타브 튐 보정 (앞뒤가 같은 음인데 혼자 ±12)
	runs = _runs(q)
	for r in range(1, runs.size() - 1):
		var run: Array = runs[r]
		if run[0] < 0 or (run[2] - run[1]) * hop > 0.3:
			continue
		var p: int = runs[r - 1][0]
		var nx: int = runs[r + 1][0]
		if p >= 0 and p == nx and absi(absi(run[0] - p) - 12) <= 1:
			for i in range(run[1], run[2]):
				q[i] = p
	# 5) 음표로 묶기
	var out: Array[Dictionary] = []
	for run in _runs(q):
		if run[0] < 0:
			continue
		var s: float = run[1] * hop
		var e: float = run[2] * hop
		if e - s < MIN_NOTE:
			continue
		if not out.is_empty() and out[-1].midi == run[0] and s - out[-1].end < 0.1:
			out[-1].end = e
			continue
		out.append({"start": s, "end": e, "midi": clampi(run[0], 36, 96)})
	return out


static func _runs(q: PackedInt32Array) -> Array:
	var runs: Array = []  # [값, 시작, 끝(미포함)]
	var i := 0
	while i < q.size():
		var j := i
		while j < q.size() and q[j] == q[i]:
			j += 1
		runs.append([q[i], i, j])
		i = j
	return runs


## 음표 목록 → 텍스트 악보. bpm=60으로 써서 '박 = 초'가 되게 한다.
## 1초 넘게 쉬는 곳에서 줄을 바꿔 가사 줄을 붙이기 쉽게 한다.
static func to_chart(notes: Array, title: String, audio_name: String) -> String:
	var lines: PackedStringArray = [
		"// 음원에서 자동으로 뽑은 악보 초안이에요. 틀린 음은 메모장으로 고쳐 주세요.",
		"// 음표 = 음이름/길이(초).  가사를 넣으려면 음이름/길이/가사 로 쓰거나 '가사 붙이기' 도구를 쓰세요.",
		"title=%s" % title,
		"bpm=60",
		"audio=%s" % audio_name,
		"offset=0",
		"countin=0",
	]
	var row: PackedStringArray = []
	var cursor := 0.0
	for nd in notes:
		var s := snappedf(nd.start, 0.01)
		var e := snappedf(nd.end, 0.01)
		var gap := s - cursor
		if gap > 1.0 and not row.is_empty():
			lines.append(" ".join(row))
			row.clear()
		if gap >= 0.01:
			row.append("R/%s" % _num(gap))
		row.append("%s/%s" % [NoteUtils.midi_name(nd.midi), _num(maxf(e - s, 0.01))])
		cursor = e
	if not row.is_empty():
		lines.append(" ".join(row))
	return "\n".join(lines) + "\n"


static func _num(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	return s.trim_suffix(".")
