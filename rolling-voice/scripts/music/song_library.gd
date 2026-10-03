class_name SongLibrary
extends RefCounted
## 노래 목록을 만든다: 내장곡 + 사용자 폴더(user://songs)의 .txt 악보와 .mid 파일.
##
## 텍스트 악보 형식 (한 줄 주석은 //)
##   title=노래 제목
##   bpm=100            // 중간에 다시 쓰면 그 지점부터 빠르기가 바뀜
##   audio=반주.ogg     // 생략하면 같은 이름의 ogg/mp3/wav를 자동으로 찾음
##   offset=1.5         // 반주에서 첫 음이 나오기까지의 시간(초)
##   transpose=-2       // 반음 단위 조옮김
##   C4 D4 E4/2 R 솔4/0.5/가사
## 음표 = 음이름[/박자[/가사]]  (박자 생략 시 1박, R은 쉼표, 계이름 도레미파솔라시도 가능)

const SONGS_DIR := "user://songs"
const AUDIO_EXTS: PackedStringArray = ["ogg", "mp3", "wav"]
const DEFAULT_COUNT_IN := 4

const BUILTIN: Array[Dictionary] = [
	{"id": "builtin_twinkle", "text": """
title=작은 별
bpm=96
C4 C4 G4 G4 A4 A4 G4/2
F4 F4 E4 E4 D4 D4 C4/2
G4 G4 F4 F4 E4 E4 D4/2
G4 G4 F4 F4 E4 E4 D4/2
C4 C4 G4 G4 A4 A4 G4/2
F4 F4 E4 E4 D4 D4 C4/2
"""},
	{"id": "builtin_mary", "text": """
title=메리의 어린 양
bpm=104
E4 D4 C4 D4 E4 E4 E4/2
D4 D4 D4/2 E4 G4 G4/2
E4 D4 C4 D4 E4 E4 E4 E4
D4 D4 E4 D4 C4/4
"""},
	{"id": "builtin_ode", "text": """
title=환희의 송가 (베토벤)
bpm=112
E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4/1.5 D4/0.5 D4/2
E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4/1.5 C4/0.5 C4/2
D4 D4 E4 C4 D4 E4/0.5 F4/0.5 E4 C4 D4 E4/0.5 F4/0.5 E4 D4 C4 D4 G3/2
E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4/1.5 C4/0.5 C4/2
"""},
	{"id": "builtin_birthday", "text": """
title=생일 축하
bpm=100
C4/0.75 C4/0.25 D4 C4 F4 E4/2
C4/0.75 C4/0.25 D4 C4 G4 F4/2
C4/0.75 C4/0.25 C5 A4 F4 E4 D4/2
Bb4/0.75 Bb4/0.25 A4 F4 G4 F4/3
"""},
]

const GUIDE_TEXT := """Rolling Voice — 내 노래 추가하는 법
=====================================

이 폴더에 파일을 넣고 게임의 노래 목록에서 '새로고침'을 누르면 됩니다.

1) MIDI 파일 (.mid)
   - 멜로디가 들어 있는 MIDI 파일을 넣으세요. 여러 악기가 섞여 있으면
     '노래 멜로디처럼 보이는' 트랙을 자동으로 고릅니다.
     (트랙 이름에 melody / vocal / 멜로디 / 보컬이 들어 있으면 그 트랙을 우선 사용)
   - 같은 이름의 반주 파일(.ogg .mp3 .wav)이 있으면 함께 재생합니다.
     예) 내노래.mid + 내노래.mp3
     이때 MIDI의 0초와 반주의 0초가 같아야 박자가 맞습니다.

2) 텍스트 악보 (.txt)
   - 메모장으로 직접 쓸 수 있습니다. '예시_도레미(가사).txt'를 열어 보세요.
   - 음표는 '음이름/박자/가사' 형식입니다. 박자와 가사는 생략할 수 있어요.
       C4  D4/2  E4/0.5/라  R(쉼표)  솔4  파#4  Bb3
   - 머리말 설정
       title=제목      bpm=빠르기      transpose=조옮김(반음)
       audio=반주파일   offset=반주에서 첫 음까지의 초

3) 음원만 있을 때 (.mp3 .ogg .wav)
   - 메뉴의 '노래 추가 · 가사' → '음원으로 악보 만들기'를 누르면
     음원에서 멜로디를 자동으로 뽑아 텍스트 악보 초안을 만들어 줍니다.
   - 보컬이나 멜로디가 또렷한 음원일수록 정확하고, 틀린 음은 메모장으로 고치면 됩니다.

4) 가사 (노래방처럼 표시)
   - 텍스트 악보: '음이름/박자/가사'. 악보 한 줄이 가사 한 줄, '_'는 띄어쓰기.
   - .lrc 파일: 노래 파일과 같은 이름으로 두면 그 가사를 씁니다. 예) 내노래.mid + 내노래.lrc
       [00:12.30]첫 번째 소절
       [00:15.80]두 번째 소절
   - '선택한 노래에 가사 붙이기'를 쓰면 노래를 들으며 스페이스로 타이밍을 찍어
     .lrc 파일을 만들 수 있어요.

※ 파일 이름이 '_'로 시작하는 파일은 목록에 나오지 않습니다.
※ 저작권이 있는 음원은 개인적으로만 사용하세요.
"""

const EXAMPLE_NAME := "예시_도레미(가사).txt"
const EXAMPLE_TEXT := """// 발성 연습용 도레미 — 메모장으로 고쳐 보세요
// 음표 = 음이름/박자/가사.  악보 한 줄이 노래방 가사 한 줄이 되고, '_'는 띄어쓰기예요.
title=도레미 연습
bpm=90
도4/1/도 레4/1/레 미4/1/미 파4/1/파 솔4/1/솔 라4/1/라 시4/1/시 도5/2/도
도5/1/도 시4/1/시 라4/1/라 솔4/1/솔 파4/1/파 미4/1/미 레4/1/레 도4/2/도
R/2
도4/2/아_ 미4/2/아_ 솔4/2/아_ 도5/2/아
솔4/2/아_ 미4/2/아_ 도4/4/아
"""


static func ensure_songs_dir() -> void:
	if not DirAccess.dir_exists_absolute(SONGS_DIR):
		DirAccess.make_dir_recursive_absolute(SONGS_DIR)
	var guide := SONGS_DIR.path_join("_내 노래 추가하는 법.txt")
	if not FileAccess.file_exists(guide):
		var f := FileAccess.open(guide, FileAccess.WRITE)
		if f:
			f.store_string(GUIDE_TEXT)
	# 예시 악보는 한 번만 만든다 (지워도 다시 생기지 않게 표시 파일을 남김)
	var example := SONGS_DIR.path_join(EXAMPLE_NAME)
	var mark_path := SONGS_DIR.path_join(".example2_written")
	if not FileAccess.file_exists(example) and not FileAccess.file_exists(mark_path):
		var f2 := FileAccess.open(example, FileAccess.WRITE)
		if f2:
			f2.store_string(EXAMPLE_TEXT)
		var mark := FileAccess.open(mark_path, FileAccess.WRITE)
		if mark:
			mark.store_string("1")


static func load_all() -> Array[SongData]:
	var list: Array[SongData] = []
	for b in BUILTIN:
		var s := parse_text(b.text, b.id, "", "")
		s.source = "내장곡"
		s.lrc_path = SONGS_DIR.path_join("_" + b.id + ".lrc")
		attach_lrc(s)
		list.append(s)
	if DirAccess.dir_exists_absolute(SONGS_DIR):
		var files := Array(DirAccess.get_files_at(SONGS_DIR))
		files.sort_custom(func(a: String, b: String): return a.naturalnocasecmp_to(b) < 0)
		for f: String in files:
			if f.begins_with("_") or f.begins_with("."):
				continue
			var path := SONGS_DIR.path_join(f)
			match f.get_extension().to_lower():
				"txt":
					list.append(load_text_file(path))
				"mid", "midi":
					list.append(load_midi_file(path))
	return list


static func load_text_file(path: String) -> SongData:
	var text := FileAccess.get_file_as_string(path)
	var s := parse_text(text, "user:" + path.get_file(), path.get_base_dir(), find_audio(path.get_basename()))
	s.source = "내 노래 · 악보"
	if s.title == s.id:
		s.title = path.get_file().get_basename()
	s.lrc_path = path.get_basename() + ".lrc"
	attach_lrc(s)
	return s


static func load_midi_file(path: String) -> SongData:
	var s := SongData.new()
	s.id = "user:" + path.get_file()
	s.title = path.get_file().get_basename()
	s.source = "내 노래 · MIDI"
	s.audio_path = find_audio(path.get_basename())
	s.lrc_path = path.get_basename() + ".lrc"
	var res := MidiParser.parse(FileAccess.get_file_as_bytes(path))
	if not res.ok:
		s.error = res.error
		return s
	var shift := 0.0
	if s.audio_path.is_empty():
		# 반주가 없으면 앞쪽 공백을 없애고 카운트인 4박(0.6초 간격)을 넣는다
		var beat := 0.6
		shift = beat * DEFAULT_COUNT_IN - float(res.notes[0].start)
		for i in DEFAULT_COUNT_IN:
			s.click_times.append(i * beat)
	for n: Dictionary in res.notes:
		s.add_note(n.start + shift, n.end - n.start, n.midi)
	s.time_shift = shift
	attach_lrc(s)
	return s


static func parse_text(text: String, id: String, base_dir: String, auto_audio: String) -> SongData:
	var s := SongData.new()
	s.id = id
	s.title = id
	var events: Array = []  # ["set", key, value] 또는 ["note", token]
	var settings := {}
	var line_no := 0
	for raw_line in text.split("\n"):
		line_no += 1
		var line := raw_line
		var c := line.find("//")
		if c >= 0:
			line = line.substr(0, c)
		line = line.strip_edges()
		if line.is_empty():
			continue
		if line.contains("="):
			var key := line.get_slice("=", 0).strip_edges().to_lower()
			var value := line.substr(line.find("=") + 1).strip_edges()
			settings[key] = value
			events.append(["set", key, value])
			continue
		for tok in line.replace("|", " ").replace("\t", " ").split(" ", false):
			events.append(["note", tok, line_no])

	if settings.has("title"):
		s.title = settings.title
	if settings.has("audio") and not base_dir.is_empty():
		var p := base_dir.path_join(settings.audio)
		if FileAccess.file_exists(p):
			s.audio_path = p
		else:
			s.error = "반주 파일을 찾을 수 없어요: %s" % settings.audio
			return s
	elif not auto_audio.is_empty():
		s.audio_path = auto_audio

	var has_audio := not s.audio_path.is_empty()
	var transpose := int(settings.get("transpose", "0"))
	var bpm := maxf(20.0, float(settings.get("bpm", "100")) if settings.has("bpm") else 100.0)
	# 처음 bpm은 '첫 번째로 나온 bpm=' 값
	for e in events:
		if e[0] == "set" and e[1] == "bpm":
			bpm = maxf(20.0, float(e[2]))
			break
	var count_in := int(settings.get("countin", "0" if has_audio else str(DEFAULT_COUNT_IN)))
	var cursor := float(settings.get("offset", "0")) if has_audio else count_in * 60.0 / bpm
	for i in count_in:
		s.click_times.append(i * 60.0 / bpm)

	var seen_first_bpm := false
	for e in events:
		if e[0] == "set":
			if e[1] == "bpm":
				if seen_first_bpm:
					bpm = maxf(20.0, float(e[2]))
				seen_first_bpm = true
			continue
		var parts: PackedStringArray = String(e[1]).split("/")
		var name := parts[0]
		var beats := 1.0
		if parts.size() > 1 and not parts[1].is_empty():
			if not parts[1].is_valid_float():
				s.error = "박자 값이 이상해요: %s" % e[1]
				return s
			beats = float(parts[1])
		var lyric := parts[2] if parts.size() > 2 else ""
		var length := beats * 60.0 / bpm
		if name.to_upper() == "R" or name == "-" or name == "쉼":
			cursor += length
			continue
		var midi := NoteUtils.parse_name(name)
		if midi < 0:
			s.error = "알 수 없는 음 이름이에요: %s" % name
			return s
		s.add_note(cursor, length, clampi(midi + transpose, 0, 127), lyric, e[2])
		cursor += length
	if s.notes.is_empty() and s.error.is_empty():
		s.error = "악보에 음표가 없어요"
	s.build_lyrics_from_notes()
	return s


## 곡에 .lrc 가사 파일이 있으면 읽어서 붙인다 (악보 안 가사보다 우선).
static func attach_lrc(s: SongData) -> void:
	if s.lrc_path.is_empty() or not FileAccess.file_exists(s.lrc_path):
		return
	var lines := parse_lrc(FileAccess.get_file_as_string(s.lrc_path), s.time_shift)
	if not lines.is_empty():
		s.lyric_lines = lines


## LRC 가사 파싱.
##   [00:12.34]가사 한 줄          → 줄 단위
##   [00:12.34]<00:12.34>가<00:12.80>사  → 글자(단어) 단위 (Enhanced LRC)
##   [offset:+200]                 → 전체 시각 보정(ms, +면 가사가 빨라짐)
static func parse_lrc(text: String, shift: float = 0.0) -> Array[Dictionary]:
	var stamp := RegEx.create_from_string("\\[(\\d+):(\\d+(?:[.:]\\d+)?)\\]")
	var word := RegEx.create_from_string("<(\\d+):(\\d+(?:[.:]\\d+)?)>")
	var offset_re := RegEx.create_from_string("\\[offset:\\s*([+-]?\\d+)\\]")
	var entries: Array = []  # [time, text]
	var offset := 0.0
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var om := offset_re.search(line)
		if om:
			offset = -float(om.get_string(1)) / 1000.0
			continue
		var times: Array[float] = []
		var pos := 0
		while true:
			var m := stamp.search(line, pos)
			if m == null or m.get_start() != pos:
				break
			times.append(_lrc_time(m.get_string(1), m.get_string(2)))
			pos = m.get_end()
		if times.is_empty():
			continue
		var body := line.substr(pos)
		for t in times:
			entries.append([t, body])
	entries.sort_custom(func(a, b): return a[0] < b[0])

	var out: Array[Dictionary] = []
	for i in entries.size():
		var start: float = entries[i][0] + offset + shift
		var end: float = (entries[i + 1][0] + offset + shift) if i + 1 < entries.size() else start + 5.0
		var body: String = entries[i][1]
		var segs: Array = []
		var matches := word.search_all(body)
		if matches.is_empty():
			if body.strip_edges().is_empty():
				continue  # 빈 줄 = 간주(가사 없음)
			segs.append({"text": body, "start": start, "end": maxf(start + 0.1, end - 0.15)})
		else:
			var lead := body.substr(0, matches[0].get_start())
			if not lead.is_empty():
				segs.append({"text": lead, "start": start, "end": start})
			for k in matches.size():
				var m: RegExMatch = matches[k]
				var seg_start := _lrc_time(m.get_string(1), m.get_string(2)) + offset + shift
				var text_end := matches[k + 1].get_start() if k + 1 < matches.size() else body.length()
				var seg_text := body.substr(m.get_end(), text_end - m.get_end())
				var seg_end := end - 0.15
				if k + 1 < matches.size():
					seg_end = _lrc_time(matches[k + 1].get_string(1), matches[k + 1].get_string(2)) + offset + shift
				if not seg_text.is_empty():
					segs.append({"text": seg_text, "start": seg_start, "end": seg_end})
		if segs.is_empty():
			continue
		out.append({"start": start, "end": segs[-1].end, "segs": segs})
	return out


static func _lrc_time(mm: String, ss: String) -> float:
	return int(mm) * 60.0 + float(ss.replace(":", "."))


## 가사 줄 목록을 LRC 텍스트로 저장한다 (가사 싱크 도구용).
static func write_lrc(path: String, title: String, lines: Array) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_line("[ti:%s]" % title)
	f.store_line("[by:Rolling Voice 가사 싱크 도구]")
	for l in lines:
		var t: float = maxf(l.time, 0.0)
		f.store_line("[%02d:%05.2f]%s" % [int(t / 60.0), fmod(t, 60.0), l.text])
	return OK


static func find_audio(base_without_ext: String) -> String:
	for ext in AUDIO_EXTS:
		for candidate in [base_without_ext + "." + ext, base_without_ext + "." + ext.to_upper()]:
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


static func load_audio_stream(path: String) -> AudioStream:
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null
