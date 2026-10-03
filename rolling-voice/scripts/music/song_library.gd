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
   - 메모장으로 직접 쓸 수 있습니다. '예시_도레미.txt'를 열어 보세요.
   - 음표는 '음이름/박자/가사' 형식입니다. 박자와 가사는 생략할 수 있어요.
       C4  D4/2  E4/0.5/라  R(쉼표)  솔4  파#4  Bb3
   - 머리말 설정
       title=제목      bpm=빠르기      transpose=조옮김(반음)
       audio=반주파일   offset=반주에서 첫 음까지의 초

※ 파일 이름이 '_'로 시작하는 파일은 목록에 나오지 않습니다.
※ 저작권이 있는 음원은 개인적으로만 사용하세요.
"""

const EXAMPLE_TEXT := """// 발성 연습용 도레미 (메모장으로 고쳐 보세요)
title=도레미 연습
bpm=90
도4 레4 미4 파4 솔4 라4 시4 도5/2
도5 시4 라4 솔4 파4 미4 레4 도4/2
R/2
도4/2 미4/2 솔4/2 도5/2
솔4/2 미4/2 도4/4
"""


static func ensure_songs_dir() -> void:
	if not DirAccess.dir_exists_absolute(SONGS_DIR):
		DirAccess.make_dir_recursive_absolute(SONGS_DIR)
	var guide := SONGS_DIR.path_join("_내 노래 추가하는 법.txt")
	if not FileAccess.file_exists(guide):
		var f := FileAccess.open(guide, FileAccess.WRITE)
		if f:
			f.store_string(GUIDE_TEXT)
	var example := SONGS_DIR.path_join("예시_도레미.txt")
	if not FileAccess.file_exists(example) and not FileAccess.file_exists(SONGS_DIR.path_join(".example_written")):
		var f2 := FileAccess.open(example, FileAccess.WRITE)
		if f2:
			f2.store_string(EXAMPLE_TEXT)
		var mark := FileAccess.open(SONGS_DIR.path_join(".example_written"), FileAccess.WRITE)
		if mark:
			mark.store_string("1")


static func load_all() -> Array[SongData]:
	var list: Array[SongData] = []
	for b in BUILTIN:
		var s := parse_text(b.text, b.id, "", "")
		s.source = "내장곡"
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
	return s


static func load_midi_file(path: String) -> SongData:
	var s := SongData.new()
	s.id = "user:" + path.get_file()
	s.title = path.get_file().get_basename()
	s.source = "내 노래 · MIDI"
	s.audio_path = find_audio(path.get_basename())
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
	return s


static func parse_text(text: String, id: String, base_dir: String, auto_audio: String) -> SongData:
	var s := SongData.new()
	s.id = id
	s.title = id
	var events: Array = []  # ["set", key, value] 또는 ["note", token]
	var settings := {}
	for raw_line in text.split("\n"):
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
			events.append(["note", tok])

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
		s.add_note(cursor, length, clampi(midi + transpose, 0, 127), lyric)
		cursor += length
	if s.notes.is_empty() and s.error.is_empty():
		s.error = "악보에 음표가 없어요"
	return s


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
