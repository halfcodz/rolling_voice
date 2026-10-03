class_name PitchLane
extends Control
## 노래방식 음정 레인.
## 가로축 = 시간(현재 시각 선이 왼쪽 22% 지점), 세로축 = 음높이.
## 목표 음표는 둥근 막대, 내가 부른 음은 점선 궤적으로 그린다.

const PAST_SEC := 1.6
const FUTURE_SEC := 4.2
const NOW_RATIO := 0.22

var song: SongData
var time := 0.0
var tolerance_cents := 60.0
var ignore_octave := true
var results: PackedInt32Array   ## 음표별 판정: 0 대기/생략, 1 통과, 2 실수
var current_index := -1         ## 지금 판정 중인 음표

var _trail: Array[Vector3] = [] ## (시각, 표시용 MIDI, 맞음=1/틀림=0)
var _lo := 55.0
var _hi := 79.0
var _font: Font


func _ready() -> void:
	_font = UiTheme.font()
	clip_contents = true


func set_song(s: SongData) -> void:
	song = s
	results = PackedInt32Array()
	results.resize(s.notes.size())
	_trail.clear()
	var r := s.midi_range()
	var center := (r.x + r.y) * 0.5
	var span := maxf(14.0, r.y - r.x + 5.0)
	_lo = center - span * 0.5
	_hi = center + span * 0.5


## 매 프레임 호출: 지금 부른 음을 궤적에 추가
func push_voice(t: float, sung_midi: float, voiced: bool, target_midi: float, in_tune: bool) -> void:
	time = t
	if voiced:
		var shown := sung_midi
		if ignore_octave and target_midi > 0.0:
			shown = NoteUtils.fold_near(sung_midi, target_midi)
		elif ignore_octave:
			shown = NoteUtils.fold_near(sung_midi, (_lo + _hi) * 0.5)
		_trail.append(Vector3(t, shown, 1.0 if in_tune else 0.0))
	while not _trail.is_empty() and _trail[0].x < t - PAST_SEC - 0.2:
		_trail.pop_front()
	queue_redraw()


func _x(t: float) -> float:
	var now_x := size.x * NOW_RATIO
	var px_per_sec := (size.x - now_x) / FUTURE_SEC
	return now_x + (t - time) * px_per_sec


func _y(midi: float) -> float:
	var pad := 26.0
	return pad + (1.0 - (midi - _lo) / (_hi - _lo)) * (size.y - pad * 2.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var row_h := (h - 52.0) / (_hi - _lo)

	# 반음 가이드 줄 + 도(C) 표시
	for m in range(ceili(_lo), floori(_hi) + 1):
		var y := _y(m)
		var is_c := posmod(m, 12) == 0
		draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.09 if is_c else 0.035), 1.0)
		if is_c:
			draw_string(_font, Vector2(10, y - 4), NoteUtils.midi_name(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UiTheme.MUTED, 0.7))

	if song == null:
		return

	# 음표 막대
	var bar_h := clampf(row_h * 0.85, 10.0, 22.0)
	var tol_h := row_h * (tolerance_cents / 100.0)
	for i in song.notes.size():
		var n: Dictionary = song.notes[i]
		if n.end < time - PAST_SEC or n.start > time + FUTURE_SEC:
			continue
		var x0 := _x(n.start)
		var x1 := maxf(_x(n.end) - 3.0, x0 + 6.0)
		var y := _y(n.midi)
		var col := UiTheme.SKY
		var state := results[i] if i < results.size() else 0
		if state == 1:
			col = UiTheme.GOOD
		elif state == 2:
			col = UiTheme.BAD
		elif i == current_index:
			col = UiTheme.GOLD
		# 허용 범위(옅은 띠)
		if i == current_index:
			var band := Rect2(x0, y - tol_h, x1 - x0, tol_h * 2.0)
			draw_rect(band, Color(UiTheme.GOLD, 0.10))
		var rect := Rect2(x0, y - bar_h * 0.5, x1 - x0, bar_h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col, 0.92 if n.end > time or state != 0 else 0.45)
		sb.set_corner_radius_all(int(bar_h * 0.5))
		sb.shadow_color = Color(col, 0.35)
		sb.shadow_size = 6 if i == current_index else 0
		draw_style_box(sb, rect)
		var label: String = n.lyric if not String(n.lyric).is_empty() else NoteUtils.solfege(n.midi)
		if x1 - x0 > 14.0:
			draw_string(_font, Vector2(x0 + 2, y - bar_h * 0.5 - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				Color(UiTheme.TEXT, 0.95 if n.end > time else 0.5))

	# 내 음 궤적
	var prev := Vector3(-1, 0, 0)
	for p in _trail:
		var pos := Vector2(_x(p.x), _y(p.y))
		var c := UiTheme.GOOD if p.z > 0.5 else Color("ff9f43")
		if prev.x >= 0.0 and p.x - prev.x < 0.12 and absf(p.y - prev.y) < 3.0:
			draw_line(Vector2(_x(prev.x), _y(prev.y)), pos, c, 4.0, true)
		prev = p
	if not _trail.is_empty() and time - _trail[-1].x < 0.1:
		var last := _trail[-1]
		var lp := Vector2(_x(last.x), _y(last.y))
		var lc := UiTheme.GOOD if last.z > 0.5 else Color("ff9f43")
		draw_circle(lp, 10.0, Color(lc, 0.25))
		draw_circle(lp, 6.0, lc)

	# 현재 시각 선
	var nx := w * NOW_RATIO
	draw_line(Vector2(nx, 8), Vector2(nx, h - 8), Color(UiTheme.GOLD, 0.85), 3.0)
	draw_circle(Vector2(nx, 8), 5.0, UiTheme.GOLD)
	draw_circle(Vector2(nx, h - 8), 5.0, UiTheme.GOLD)
