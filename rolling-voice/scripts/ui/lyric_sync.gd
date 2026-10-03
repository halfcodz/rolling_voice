extends Node
## 가사 싱크 도구.
## 1) 가사를 한 줄에 한 소절씩 붙여 넣는다.
## 2) 노래를 틀어 놓고 줄이 시작될 때마다 스페이스를 누른다. (Enter = 간주 시작, Backspace = 되돌리기)
## 3) 저장하면 곡 옆에 .lrc 파일이 생기고, 플레이 화면에 노래방 가사로 나온다.

var song: SongData

var _world: RollingWorld
var _ui: Control
var _text: TextEdit
var _current: Label
var _next: Label
var _status: Label
var _marks_list: ItemList
var _start_btn: Button
var _save_btn: Button
var _synth: MelodySynth
var _backing: AudioStreamPlayer
var _lines: PackedStringArray = []
var _marks: Array[Dictionary] = []   ## {time, text} — text가 빈 문자열이면 간주
var _next_line := 0
var _playing := false
var _start_usec := 0
var _sim := -1.0   ## 테스트용 시뮬레이션 시계 (명령줄 -- simclock)


func _ready() -> void:
	song = GameSettings.selected_song
	_world = RollingWorld.new()
	_world.camera_mode = RollingWorld.CameraMode.MENU
	add_child(_world)
	_world.speed = 3.0
	_synth = MelodySynth.new()
	add_child(_synth)
	_backing = AudioStreamPlayer.new()
	_backing.bus = "Music"
	add_child(_backing)

	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = GameSettings.theme
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_build()
	_prefill()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.14, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	_ui.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	var back := Button.new()
	back.theme_type_variation = "IconButton"
	back.icon = UiTheme.icon("home")
	back.tooltip_text = "노래 고르기로 돌아가기"
	back.custom_minimum_size = Vector2(56, 56)
	back.pressed.connect(_go_back)
	head.add_child(back)
	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 44)
	title.text = "가사 싱크"
	head.add_child(title)
	var song_chip := Label.new()
	song_chip.theme_type_variation = "ChipLabel"
	song_chip.add_theme_font_size_override("font_size", 20)
	song_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	song_chip.text = song.title if song else "-"
	head.add_child(song_chip)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cols)

	# ── 1. 가사 입력 ──
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)
	var lt := Label.new()
	lt.theme_type_variation = "HeadingLabel"
	lt.text = "1. 가사 붙여 넣기"
	lv.add_child(lt)
	var lh := Label.new()
	lh.theme_type_variation = "MutedLabel"
	lh.text = "한 줄에 한 소절씩 적어 주세요. 빈 줄은 건너뛰어요."
	lv.add_child(lh)
	_text = TextEdit.new()
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.placeholder_text = "첫 번째 소절\n두 번째 소절\n세 번째 소절\n…"
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_DEEP, 14, 14.0))
	_text.add_theme_stylebox_override("focus", UiTheme.box(UiTheme.PANEL_DEEP, 14, 14.0, 2, UiTheme.GOLD))
	_text.add_theme_color_override("font_color", UiTheme.TEXT)
	_text.add_theme_color_override("caret_color", UiTheme.GOLD)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	lv.add_child(_text)

	# ── 2. 타이밍 찍기 ──
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	var rt := Label.new()
	rt.theme_type_variation = "HeadingLabel"
	rt.text = "2. 노래에 맞춰 스페이스 누르기"
	rv.add_child(rt)
	var keys := Label.new()
	keys.theme_type_variation = "MutedLabel"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.text = "스페이스 = 다음 줄 시작   ·   Enter = 간주 시작(가사 지우기)   ·   Backspace = 되돌리기"
	rv.add_child(keys)

	var stage := PanelContainer.new()
	stage.theme_type_variation = "SoftPanel"
	stage.custom_minimum_size = Vector2(0, 130)
	rv.add_child(stage)
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(sv)
	var cap := Label.new()
	cap.theme_type_variation = "MutedLabel"
	cap.text = "스페이스를 누르면 시작할 줄"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(cap)
	_current = Label.new()
	_current.theme_type_variation = "BigLabel"
	_current.add_theme_font_size_override("font_size", 34)
	_current.add_theme_color_override("font_color", UiTheme.GOLD)
	_current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sv.add_child(_current)
	_next = Label.new()
	_next.theme_type_variation = "MutedLabel"
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sv.add_child(_next)

	_marks_list = ItemList.new()
	_marks_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_marks_list.focus_mode = Control.FOCUS_NONE
	_marks_list.add_theme_font_size_override("font_size", 18)
	rv.add_child(_marks_list)

	_status = Label.new()
	_status.theme_type_variation = "MutedLabel"
	_status.text = "가사를 넣고 '처음부터 시작'을 누르세요."
	rv.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	rv.add_child(buttons)
	_start_btn = Button.new()
	_start_btn.text = "처음부터 시작"
	_start_btn.icon = UiTheme.icon("play_arrow")
	_start_btn.custom_minimum_size = Vector2(0, 60)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.pressed.connect(_toggle_play)
	buttons.add_child(_start_btn)
	_save_btn = Button.new()
	_save_btn.theme_type_variation = "PrimaryButton"
	_save_btn.add_theme_font_size_override("font_size", 24)
	_save_btn.text = "저장"
	_save_btn.icon = UiTheme.icon("check_circle")
	_save_btn.custom_minimum_size = Vector2(0, 60)
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.focus_mode = Control.FOCUS_NONE
	_save_btn.disabled = true
	_save_btn.pressed.connect(_save)
	buttons.add_child(_save_btn)


## 이미 있는 가사(.lrc 또는 악보 가사)를 입력 칸에 채워 둔다.
func _prefill() -> void:
	if song == null:
		return
	var rows: PackedStringArray = []
	for line: Dictionary in song.lyric_lines:
		var t := ""
		for seg: Dictionary in line.segs:
			t += seg.text
		rows.append(t.strip_edges())
	_text.text = "\n".join(rows)
	_refresh_preview()


func _collect_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for row in _text.text.split("\n"):
		var r := row.strip_edges()
		if not r.is_empty():
			out.append(r)
	return out


func _toggle_play() -> void:
	if _playing:
		_stop("멈췄어요. 저장하거나 처음부터 다시 할 수 있어요.")
		return
	_lines = _collect_lines()
	if _lines.is_empty():
		_status.text = "먼저 왼쪽에 가사를 넣어 주세요."
		_status.add_theme_color_override("font_color", UiTheme.BAD)
		return
	_marks.clear()
	_marks_list.clear()
	_next_line = 0
	_text.editable = false
	_text.release_focus()
	_playing = true
	_start_btn.text = "멈춤"
	_save_btn.disabled = true
	_status.remove_theme_color_override("font_color")
	_status.text = "노래가 나오면 첫 줄이 시작될 때 스페이스!"
	# 원래 키로 재생 (가사 타이밍만 맞추면 되므로)
	GameSettings.set_backing_pitch(0)
	_synth.setup(song)
	_backing.stream = SongLibrary.load_audio_stream(song.audio_path) if not song.audio_path.is_empty() else null
	_start_usec = Time.get_ticks_usec()
	if "simclock" in OS.get_cmdline_user_args():
		_sim = 0.0
	_synth.start()
	if _backing.stream:
		_backing.play()
	_refresh_preview()


func _stop(msg: String) -> void:
	_playing = false
	_synth.stop()
	_backing.stop()
	_text.editable = true
	_start_btn.text = "처음부터 시작"
	_save_btn.disabled = _marks.is_empty()
	_status.text = msg


func _now() -> float:
	if _sim >= 0.0:
		return _sim
	if _backing.playing:
		return _backing.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return (Time.get_ticks_usec() - _start_usec) / 1000000.0 - AudioServer.get_output_latency()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if _playing:
			_stop("멈췄어요.")
		else:
			_go_back()
		get_viewport().set_input_as_handled()
		return
	if not _playing:
		return
	match event.keycode:
		KEY_SPACE:
			_mark_line()
		KEY_ENTER, KEY_KP_ENTER:
			_mark_gap()
		KEY_BACKSPACE:
			_undo()
		_:
			return
	get_viewport().set_input_as_handled()


func _mark_line() -> void:
	if _next_line >= _lines.size():
		return
	_add_mark(_now(), _lines[_next_line])
	_next_line += 1
	_refresh_preview()
	if _next_line >= _lines.size():
		_status.text = "마지막 줄까지 찍었어요! 간주가 끝나는 곳에서 Enter를 누르거나 '멈춤' 후 저장하세요."


func _mark_gap() -> void:
	if _marks.is_empty() or _marks[-1].text.is_empty():
		return
	_add_mark(_now(), "")


func _add_mark(t: float, text: String) -> void:
	_marks.append({"time": t - song.time_shift, "text": text})
	_marks_list.add_item("%02d:%05.2f   %s" % [int(t / 60.0), fmod(t, 60.0), text if not text.is_empty() else "(간주)"])
	_marks_list.ensure_current_is_visible()
	_marks_list.select(_marks_list.item_count - 1)
	_world.coin.hit()


func _undo() -> void:
	if _marks.is_empty():
		return
	var last: Dictionary = _marks.pop_back()
	_marks_list.remove_item(_marks_list.item_count - 1)
	if not String(last.text).is_empty():
		_next_line = maxi(_next_line - 1, 0)
	_refresh_preview()


func _refresh_preview() -> void:
	var lines := _lines if not _lines.is_empty() else _collect_lines()
	_current.text = lines[_next_line] if _next_line < lines.size() else "— 끝 —"
	_next.text = lines[_next_line + 1] if _next_line + 1 < lines.size() else " "


func _process(delta: float) -> void:
	if _sim >= 0.0 and _playing:
		_sim += minf(delta, 1.0 / 30.0)
	if _playing and _now() > song.duration() + 2.0:
		_stop("노래가 끝났어요. 저장을 누르세요.")


func _save() -> void:
	if _marks.is_empty() or song.lrc_path.is_empty():
		return
	SongLibrary.ensure_songs_dir()
	var err := SongLibrary.write_lrc(song.lrc_path, song.title, _marks)
	if err == OK:
		_status.add_theme_color_override("font_color", UiTheme.GOOD)
		_status.text = "저장했어요: %s" % song.lrc_path.get_file()
		SongLibrary.attach_lrc(song)
	else:
		_status.add_theme_color_override("font_color", UiTheme.BAD)
		_status.text = "저장하지 못했어요 (오류 %d)" % err


func _go_back() -> void:
	_synth.stop()
	_backing.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
