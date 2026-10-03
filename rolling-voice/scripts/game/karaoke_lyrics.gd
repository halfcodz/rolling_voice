class_name KaraokeLyrics
extends VBoxContainer
## 노래방식 가사 표시.
## 지금 줄은 크게, 부른 만큼 왼쪽부터 금색으로 차오른다(와이프). 아래에 다음 줄을 작게 미리 보여 준다.
## 원리: 흰 글자 라벨 위에 같은 위치의 금색 라벨을 겹치고, 금색 라벨을 감싼 Control의
##       너비(clip_contents)를 진행도만큼만 열어 준다.

const MAIN_SIZE := 34
const NEXT_SIZE := 20

var song: SongData

var _holder: Control
var _base: Label
var _clip: Control
var _fill: Label
var _next: Label
var _font: Font
var _line := -2
var _seg_offsets: PackedFloat32Array = []   ## 각 조각이 시작되는 x 위치
var _seg_widths: PackedFloat32Array = []


func _ready() -> void:
	_font = UiTheme.font()
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_holder)
	_base = _make_label(MAIN_SIZE, UiTheme.TEXT)
	_holder.add_child(_base)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_clip)
	_fill = _make_label(MAIN_SIZE, UiTheme.GOLD)
	_clip.add_child(_fill)

	_next = _make_label(NEXT_SIZE, Color(UiTheme.MUTED, 0.9))
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_next)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 8 if font_size >= MAIN_SIZE else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func set_song(s: SongData) -> void:
	song = s
	_line = -2
	visible = s != null and s.has_lyrics()
	update_time(-999.0)


func update_time(t: float) -> void:
	if song == null or not song.has_lyrics():
		return
	var idx := song.lyric_line_at(t)
	if idx != _line:
		_set_line(idx)
	if idx < 0:
		_clip.size.x = 0.0
		return
	var line: Dictionary = song.lyric_lines[idx]
	var fill := 0.0
	for i in line.segs.size():
		var seg: Dictionary = line.segs[i]
		if t >= seg.end:
			fill = _seg_offsets[i] + _seg_widths[i]
		elif t >= seg.start:
			var frac: float = (t - float(seg.start)) / maxf(float(seg.end) - float(seg.start), 0.01)
			fill = _seg_offsets[i] + _seg_widths[i] * frac
			break
		else:
			break
	_clip.size.x = fill


func _set_line(idx: int) -> void:
	_line = idx
	var text := ""
	_seg_offsets.clear()
	_seg_widths.clear()
	if idx >= 0:
		var x := 0.0
		for seg: Dictionary in song.lyric_lines[idx].segs:
			var w: float = _font.get_string_size(seg.text, HORIZONTAL_ALIGNMENT_LEFT, -1, MAIN_SIZE).x
			_seg_offsets.append(x)
			_seg_widths.append(w)
			x += w
			text += seg.text
	_base.text = text
	_fill.text = text
	var sz := _base.get_combined_minimum_size()
	_holder.custom_minimum_size = sz
	_base.size = sz
	_fill.size = sz
	_clip.size = Vector2(0.0, sz.y)
	var next_idx := idx + 1
	_next.text = song.lyric_lines[next_idx].segs.map(func(g): return g.text).reduce(func(a, b): return a + b, "") \
		if next_idx < song.lyric_lines.size() else ""
	# 줄이 바뀔 때 살짝 페이드 인
	if idx >= 0:
		_holder.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_holder, "modulate:a", 1.0, 0.18)
