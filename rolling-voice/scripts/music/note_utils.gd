class_name NoteUtils
extends RefCounted
## 음 이름 ↔ MIDI 번호 ↔ 주파수 변환과 음정 비교 함수 모음.

const NAMES: PackedStringArray = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const SOLFEGE: PackedStringArray = ["도", "도#", "레", "레#", "미", "파", "파#", "솔", "솔#", "라", "라#", "시"]
const LETTER_TO_PC := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const SOLFEGE_TO_PC := {"도": 0, "레": 2, "미": 4, "파": 5, "솔": 7, "라": 9, "시": 11}


static func hz_to_midi(hz: float) -> float:
	return 69.0 + 12.0 * log(hz / 440.0) / log(2.0)


static func midi_to_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## "C4", "F#3", "Bb4", "솔4", "도#5" 같은 음 이름을 MIDI 번호로 바꾼다. 실패하면 -1.
static func parse_name(text: String) -> int:
	var s := text.strip_edges()
	if s.is_empty():
		return -1
	var pc := -1
	var rest := ""
	var first := s.substr(0, 1)
	if LETTER_TO_PC.has(first.to_upper()):
		pc = LETTER_TO_PC[first.to_upper()]
		rest = s.substr(1)
	else:
		for key: String in SOLFEGE_TO_PC:
			if s.begins_with(key):
				pc = SOLFEGE_TO_PC[key]
				rest = s.substr(key.length())
				break
	if pc < 0:
		return -1
	while rest.length() > 0 and (rest[0] == "#" or rest[0] == "b"):
		pc += 1 if rest[0] == "#" else -1
		rest = rest.substr(1)
	if not rest.is_valid_int():
		return -1
	var octave := rest.to_int()
	var midi := (octave + 1) * 12 + pc
	return midi if midi >= 0 and midi <= 127 else -1


static func midi_name(midi: int) -> String:
	return "%s%d" % [NAMES[posmod(midi, 12)], floori(midi / 12.0) - 1]


static func solfege(midi: int) -> String:
	return SOLFEGE[posmod(midi, 12)]


## 부른 음(sung, 실수 MIDI)과 목표 음(target)의 차이를 센트(1/100 반음) 절댓값으로 돌려준다.
## ignore_octave면 옥타브 차이는 무시한다(남녀 키 차이 허용).
static func cents_diff(sung: float, target: float, ignore_octave: bool) -> float:
	var cents := (sung - target) * 100.0
	if ignore_octave:
		cents = fposmod(cents + 600.0, 1200.0) - 600.0
	return absf(cents)


## 화면 표시용: 옥타브 무시 모드에서 부른 음을 목표 음과 가장 가까운 옥타브로 옮긴다.
static func fold_near(sung: float, target: float) -> float:
	var diff := fposmod(sung - target + 6.0, 12.0) - 6.0
	return target + diff
