class_name SongData
extends RefCounted
## 한 곡의 정보: 멜로디 음표 목록(초 단위), 반주 음원 경로 등.

var id := ""
var title := ""
var source := "내장곡"        ## 목록에 보여 줄 출처 표시
var notes: Array[Dictionary] = []   ## {start, end, midi, lyric}
var click_times := PackedFloat32Array()  ## 카운트인 메트로놈 시각
var audio_path := ""          ## 반주 음원(없으면 가이드 멜로디만)
var error := ""               ## 불러오기 실패 사유(있으면 플레이 불가)


func add_note(start: float, length: float, midi: int, lyric: String = "") -> void:
	notes.append({"start": start, "end": start + length, "midi": midi, "lyric": lyric})


func is_playable() -> bool:
	return error.is_empty() and not notes.is_empty()


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


func summary() -> String:
	if not error.is_empty():
		return error
	var r := midi_range()
	var secs := int(duration())
	return "%d:%02d · 음표 %d개 · 음역 %s~%s%s" % [
		secs / 60, secs % 60, notes.size(),
		NoteUtils.midi_name(r.x), NoteUtils.midi_name(r.y),
		" · 반주 있음" if not audio_path.is_empty() else ""]
