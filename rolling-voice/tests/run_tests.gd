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
	_test_lyrics_and_key()
	_test_segmenter()
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

	# 사용자 폴더에 넣은 MIDI가 목록에 나타나는지
	SongLibrary.ensure_songs_dir()
	var path := SongLibrary.SONGS_DIR.path_join("zz_테스트곡.mid")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var found: SongData = null
	for song in SongLibrary.load_all():
		if song.id == "user:zz_테스트곡.mid":
			found = song
	check(found != null and found.is_playable(), "사용자 폴더 MIDI 불러오기")
	if found:
		check(found.click_times.size() == 4 and is_equal_approx(found.notes[0].start, 2.4), "반주 없으면 카운트인 추가 (첫 음 %.2f초)" % found.notes[0].start)
	DirAccess.remove_absolute(path)


func _test_builtin_songs() -> void:
	print("[내장곡]")
	for s in SongLibrary.load_all():
		if s.id.begins_with("builtin"):
			check(s.is_playable(), "%s — %s" % [s.title, s.summary()])


func _test_lyrics_and_key() -> void:
	print("[가사 · 키]")
	# 악보 한 줄 = 가사 한 줄, "_" = 띄어쓰기 (내용은 테스트용 임의 문자열)
	var s := SongLibrary.parse_text("bpm=60\nC4/1/가 D4/1/나_ E4/1/다\nF4/2/라", "l", "", "")
	check(s.lyric_lines.size() == 2, "악보 가사 2줄 (%d)" % s.lyric_lines.size())
	if s.lyric_lines.size() == 2:
		var first: Dictionary = s.lyric_lines[0]
		check(first.segs.size() == 3 and first.segs[1].text == "나 ", "음표별 조각·띄어쓰기")
		check(is_equal_approx(first.start, 4.0) and is_equal_approx(first.end, 7.0), "줄 시작·끝 (%.1f~%.1f)" % [first.start, first.end])
		check(s.lyric_line_at(3.0) == -1 and s.lyric_line_at(3.5) == 0 and s.lyric_line_at(7.5) == 1, "시각별 현재 줄")

	var lrc := "[ti:test]\n[offset:+500]\n[00:10.00]첫째 줄\n[00:12.50]<00:12.50>둘<00:13.00>째 <00:13.40>줄\n[00:15.00]\n[00:20.00][00:30.00]반복 줄"
	var lines := SongLibrary.parse_lrc(lrc, 1.0)
	check(lines.size() == 4, "LRC 줄 수 (빈 줄 제외, 반복 시각 펼침) %d" % lines.size())
	if lines.size() == 4:
		check(is_equal_approx(lines[0].start, 10.5), "offset(+500ms → 0.5초 빠르게)·shift 적용 (%.2f)" % lines[0].start)
		check(lines[1].segs.size() == 3 and lines[1].segs[1].text == "째 ", "글자 단위 타이밍")
		check(is_equal_approx(lines[1].segs[0].end, 13.0 - 0.5 + 1.0), "조각 끝 = 다음 조각 시작")
		check(lines[3].segs[0].text == "반복 줄" and is_equal_approx(lines[3].start, 30.5), "한 줄에 여러 시각")

	var path := "user://_lrc_test.lrc"
	SongLibrary.write_lrc(path, "제목", [{"time": 3.25, "text": "하나"}, {"time": 65.5, "text": "둘"}])
	var back := SongLibrary.parse_lrc(FileAccess.get_file_as_string(path))
	check(back.size() == 2 and is_equal_approx(back[1].start, 65.5) and back[0].segs[0].text == "하나", "LRC 저장 후 다시 읽기")
	DirAccess.remove_absolute(path)

	var t := s.transposed(-3)
	check(t.notes[0].midi == 57 and s.notes[0].midi == 60, "조옮김 복사본 (원본 유지)")
	check(t.lyric_lines.size() == s.lyric_lines.size(), "조옮김해도 가사 유지")


func _test_segmenter() -> void:
	print("[멜로디 추출 · 음표 분할]")
	# 20ms 프레임: C4 0.4초 / 잡음 1프레임 / C4 이어짐 / 무성 2프레임(자음) / E4 0.3초 / 옥타브 튐 / E4 / 긴 쉼 / G4
	var p := PackedFloat32Array()
	for i in 20: p.append(60.1)
	p.append(66.0)
	for i in 10: p.append(59.9)
	p.append(-1.0); p.append(-1.0)
	for i in 15: p.append(64.0)
	for i in 4: p.append(76.0)
	for i in 6: p.append(64.2)
	for i in 60: p.append(-1.0)
	for i in 3: p.append(67.0)   # 60ms → 너무 짧아 버림
	for i in 20: p.append(67.0)
	var notes := MelodyExtractor.segment(p, 0.02)
	var desc := ", ".join(notes.map(func(n): return "%s %.2f-%.2f" % [NoteUtils.midi_name(n.midi), n.start, n.end]))
	check(notes.size() == 3, "음표 3개로 정리: " + desc)
	if notes.size() == 3:
		check(notes[0].midi == 60 and is_equal_approx(notes[0].end, 0.64), "흔들림 제거·짧은 끊김(자음) 메우기")
		check(notes[1].midi == 64 and notes[1].end - notes[1].start > 0.45, "옥타브 튐 보정")
		check(notes[2].midi == 67, "쉼 뒤 새 음")
	var chart := MelodyExtractor.to_chart(notes, "제목", "a.ogg")
	var song := SongLibrary.parse_text(chart, "x", "", "")
	check(song.notes.size() == 3 and absf(song.notes[2].start - notes[2].start) < 0.02, "악보로 저장 후 다시 읽어도 시각 유지")
	check(chart.split("\n").size() >= 9, "1초 넘게 쉬면 줄 바꿈")
