extends SceneTree
## 헤드리스 단위 테스트
## 실행: godot --headless --path . -s res://tests/run_tests.gd

var _fails := 0


func _init() -> void:
	_test_note_utils()
	_test_yin()
	_test_text_parser()
	_test_midi_parser()
	_test_builtin_songs()
	print("\n결과: ", "모두 통과" if _fails == 0 else "%d개 실패" % _fails)
	quit(1 if _fails > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fails += 1
		print("  FAIL ", label)


func _test_note_utils() -> void:
	print("[NoteUtils]")
	check(NoteUtils.parse_name("A4") == 69, "A4 = 69")
	check(NoteUtils.parse_name("C4") == 60, "C4 = 60")
	check(NoteUtils.parse_name("F#3") == 54, "F#3 = 54")
	check(NoteUtils.parse_name("Bb4") == 70, "Bb4 = 70")
	check(NoteUtils.parse_name("솔4") == 67, "솔4 = 67")
	check(NoteUtils.parse_name("도#5") == 73, "도#5 = 73")
	check(NoteUtils.parse_name("H4") == -1, "잘못된 이름은 -1")
	check(NoteUtils.midi_name(61) == "C#4", "61 = C#4")
	check(absf(NoteUtils.hz_to_midi(440.0) - 69.0) < 0.001, "440Hz = 69")
	check(NoteUtils.cents_diff(57.0, 69.0, true) < 0.01, "옥타브 무시")
	check(absf(NoteUtils.cents_diff(57.0, 69.0, false) - 1200.0) < 0.01, "옥타브 구분")
	check(absf(NoteUtils.cents_diff(69.4, 69.0, true) - 40.0) < 0.01, "40센트")


func _sine(hz: float, rate: float, n: int, harmonics := true) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := i / rate
		var v := sin(TAU * hz * t)
		if harmonics:
			v += 0.5 * sin(TAU * 2.0 * hz * t) + 0.25 * sin(TAU * 3.0 * hz * t)
		a[i] = v * 0.3
	return a


func _test_yin() -> void:
	print("[YIN 음높이 추정]")
	var rate := 11025.0
	var max_lag := int(rate / 70.0)
	for hz in [82.4, 110.0, 196.0, 261.63, 440.0, 659.25, 880.0]:
		var buf := _sine(hz, rate, 400 + max_lag + 2)
		var f: float = load("res://scripts/audio/pitch_detector.gd").yin(buf, 0, 400, rate, 70.0, 1100.0, 0.15)
		var cents := absf(NoteUtils.hz_to_midi(f) - NoteUtils.hz_to_midi(hz)) * 100.0
		check(cents < 10.0, "%.1fHz → %.1fHz (오차 %.1f센트)" % [hz, f, cents])
	var noise := PackedFloat32Array()
	noise.resize(400 + max_lag + 2)
	for i in noise.size():
		noise[i] = randf_range(-0.3, 0.3)
	var fn: float = load("res://scripts/audio/pitch_detector.gd").yin(noise, 0, 400, rate, 70.0, 1100.0, 0.15)
	check(fn < 0.0, "백색 잡음은 음높이 없음 (%.1f)" % fn)
	# 성능: 30회 분석 시간
	var buf2 := _sine(220.0, rate, 400 + max_lag + 2)
	var t0 := Time.get_ticks_usec()
	for i in 30:
		load("res://scripts/audio/pitch_detector.gd").yin(buf2, 0, 400, rate, 70.0, 1100.0, 0.15)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(ms < 400.0, "1초 분량(30회) 분석 %.0fms" % ms)


func _test_text_parser() -> void:
	print("[텍스트 악보]")
	var s := SongLibrary.parse_text("title=테스트\nbpm=120\nC4 D4/2 R 솔4/0.5/가 // 주석\nbpm=60\nA4", "t", "", "")
	check(s.is_playable(), "파싱 성공 (%s)" % s.error)
	check(s.title == "테스트", "제목")
	check(s.notes.size() == 4, "음표 4개 (%d)" % s.notes.size())
	check(s.click_times.size() == 4, "카운트인 4박")
	if s.notes.size() == 4:
		check(is_equal_approx(s.notes[0].start, 2.0), "첫 음 = 카운트인 뒤 2.0초 (%.2f)" % s.notes[0].start)
		check(is_equal_approx(s.notes[1].end - s.notes[1].start, 1.0), "2박 = 1초")
		check(is_equal_approx(s.notes[2].start, 4.0), "쉼표 반영 (%.2f)" % s.notes[2].start)
		check(s.notes[2].lyric == "가" and s.notes[2].midi == 67, "가사·계이름")
		check(is_equal_approx(s.notes[3].end - s.notes[3].start, 1.0), "중간 bpm 변경 (%.2f)" % (s.notes[3].end - s.notes[3].start))
	var bad := SongLibrary.parse_text("C4 X9", "b", "", "")
	check(not bad.is_playable() and bad.error.contains("X9"), "잘못된 음 이름 오류: " + bad.error)
	var tr := SongLibrary.parse_text("transpose=-12\nC4", "tr", "", "")
	check(tr.notes[0].midi == 48, "조옮김")


func _vlq(v: int) -> PackedByteArray:
	var bytes := [v & 0x7F]
	v >>= 7
	while v > 0:
		bytes.push_front((v & 0x7F) | 0x80)
		v >>= 7
	return PackedByteArray(bytes)


func _u32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255])


func _track(events: PackedByteArray) -> PackedByteArray:
	var t := "MTrk".to_ascii_buffer()
	t.append_array(_u32(events.size()))
	t.append_array(events)
	return t


func _test_midi_parser() -> void:
	print("[MIDI]")
	# 형식 1, 트랙 3개: 템포 / 피아노 화음 반주 / "Melody" 단선율
	var division := 480
	var head := "MThd".to_ascii_buffer()
	head.append_array(_u32(6))
	head.append_array(PackedByteArray([0, 1, 0, 3, (division >> 8) & 255, division & 255]))
	# 트랙 0: 템포 120bpm(500000us) → 2박 뒤 60bpm(1000000us)
	var t0 := PackedByteArray()
	t0.append_array(_vlq(0)); t0.append_array(PackedByteArray([0xFF, 0x51, 3, 0x07, 0xA1, 0x20]))
	t0.append_array(_vlq(960)); t0.append_array(PackedByteArray([0xFF, 0x51, 3, 0x0F, 0x42, 0x40]))
	t0.append_array(_vlq(0)); t0.append_array(PackedByteArray([0xFF, 0x2F, 0]))
	# 트랙 1: 화음 (C3 E3 G3 동시에 4박)
	var t1 := PackedByteArray()
	for k in [48, 52, 55]:
		t1.append_array(_vlq(0)); t1.append_array(PackedByteArray([0x90, k, 80]))
	t1.append_array(_vlq(1920)); t1.append_array(PackedByteArray([0x80, 48, 0]))
	t1.append_array(_vlq(0)); t1.append_array(PackedByteArray([52, 0]))  # running status
	t1.append_array(_vlq(0)); t1.append_array(PackedByteArray([55, 0]))
	t1.append_array(_vlq(0)); t1.append_array(PackedByteArray([0xFF, 0x2F, 0]))
	# 트랙 2: 이름 Melody, 채널 2, C4 D4 E4 (각 1박), note-on vel0로 끔
	var t2 := PackedByteArray()
	t2.append_array(_vlq(0)); t2.append_array(PackedByteArray([0xFF, 0x03, 6])); t2.append_array("Melody".to_ascii_buffer())
	for k in [60, 62, 64]:
		t2.append_array(_vlq(0)); t2.append_array(PackedByteArray([0x91, k, 100]))
		t2.append_array(_vlq(480)); t2.append_array(PackedByteArray([0x91, k, 0]))
	t2.append_array(_vlq(0)); t2.append_array(PackedByteArray([0xFF, 0x2F, 0]))
	var bytes := head
	bytes.append_array(_track(t0))
	bytes.append_array(_track(t1))
	bytes.append_array(_track(t2))
	var res := MidiParser.parse(bytes)
	check(res.ok, "파싱 성공 (%s)" % res.error)
	if res.ok:
		var notes: Array = res.notes
		check(notes.size() == 3, "멜로디 트랙 선택: 음표 3개 (%d)" % notes.size())
		check(notes[0].midi == 60 and notes[2].midi == 64, "음 높이")
		check(is_equal_approx(notes[1].start, 0.5), "120bpm 1박 = 0.5초 (%.3f)" % notes[1].start)
		check(is_equal_approx(notes[2].start, 1.0) and is_equal_approx(notes[2].end, 2.0),
			"템포 변경 후 60bpm (%.3f~%.3f)" % [notes[2].start, notes[2].end])
	check(not MidiParser.parse("hello".to_ascii_buffer()).ok, "잘못된 파일 거부")


func _test_builtin_songs() -> void:
	print("[내장곡]")
	for s in SongLibrary.load_all():
		if s.id.begins_with("builtin"):
			check(s.is_playable(), "%s — %s" % [s.title, s.summary()])
