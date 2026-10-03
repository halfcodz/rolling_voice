class_name SongData
extends RefCounted
## 한 곡의 정보: 멜로디 음표 목록(초 단위), 반주 음원 경로, 가사 등.

var id := ""
var title := ""
var source := "내장곡"        ## 목록에 보여 줄 출처 표시
var notes: Array[Dictionary] = []   ## {start, end, midi, lyric, line}
var click_times := PackedFloat32Array()  ## 카운트인 메트로놈 시각
var audio_path := ""          ## 반주 음원(없으면 가이드 멜로디만)
var lrc_path := ""            ## 이 곡의 가사(.lrc) 파일 위치 (없어도 경로는 정해 둠)
var time_shift := 0.0         ## 원본 시각 → 게임 시각 보정값(MIDI 카운트인 등). LRC에도 적용
var error := ""               ## 불러오기 실패 사유(있으면 플레이 불가)

## 노래방 가사: [{start, end, segs: [{text, start, end}]}]
var lyric_lines: Array[Dictionary] = []


func add_note(start: float, length: float, midi: int, lyric: String = "", line: int = 0) -> void:
	notes.append({"start": start, "end": start + length, "midi": midi, "lyric": lyric, "line": line})


func is_playable() -> bool:
	return error.is_empty() and not notes.is_empty()


func has_lyrics() -> bool:
	return not lyric_lines.is_empty()


func first_note_time() -> float:
	return notes[0].start if not notes.is_empty() else 0.0


func duration() -> float:
	return notes[-1].end if not notes.is_empty() else 0.0


func midi_range() -> Vector2i:
	if notes.is_empty():
		return Vector2i(60, 72)
	var lo := 127
	var hi := 0
	for n in notes:
		lo = mini(lo, n.midi)
		hi = maxi(hi, n.midi)
	return Vector2i(lo, hi)


## 반음 단위로 조옮김한 복사본 (가사·반주 정보는 그대로)
func transposed(semitones: int) -> SongData:
	var s := SongData.new()
	s.id = id
	s.title = title
	s.source = source
	s.click_times = click_times.duplicate()
	s.audio_path = audio_path
	s.lrc_path = lrc_path
	s.time_shift = time_shift
	s.error = error
	s.lyric_lines = lyric_lines.duplicate(true)
	for n in notes:
		var c: Dictionary = n.duplicate()
		c.midi = clampi(int(n.midi) + semitones, 0, 127)
		s.notes.append(c)
	return s


## 악보 안의 음표별 가사를 줄 단위로 묶는다. (악보 한 줄 = 가사 한 줄, "_"는 띄어쓰기)
func build_lyrics_from_notes() -> void:
	lyric_lines.clear()
	var current: Dictionary = {}
	var current_line := -1
	for n in notes:
		var text := String(n.get("lyric", ""))
		if text.is_empty():
			continue
		var line_no := int(n.get("line", 0))
		if line_no != current_line or current.is_empty():
			if not current.is_empty():
				lyric_lines.append(current)
			current = {"start": n.start, "end": n.end, "segs": []}
			current_line = line_no
		current.segs.append({"text": text.replace("_", " "), "start": n.start, "end": n.end})
		current.end = n.end
	if not current.is_empty():
		lyric_lines.append(current)


## 지금 시각에 보여 줄 가사 줄 번호 (다음 줄이 곧 시작하면 미리 넘어가지 않음)
func lyric_line_at(t: float) -> int:
	var idx := -1
	for i in lyric_lines.size():
		if lyric_lines[i].start - 0.6 <= t:
			idx = i
		else:
			break
	return idx


func summary() -> String:
	if not error.is_empty():
		return error
	var r := midi_range()
	var secs := int(duration())
	var extras := ""
	if not audio_path.is_empty():
		extras += " · 반주"
	if has_lyrics():
		extras += " · 가사"
	return "%d:%02d · 음표 %d개 · 음역 %s~%s%s" % [
		secs / 60, secs % 60, notes.size(),
		NoteUtils.midi_name(r.x), NoteUtils.midi_name(r.y), extras]
