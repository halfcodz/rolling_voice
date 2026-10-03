extends Node
## 메인 메뉴: 뒤편에 굴러가는 동전(3D), 앞쪽에 노래 선택 · 규칙 · 마이크 설정.

var _world: RollingWorld
var _ui: Control
var _songs: Array[SongData] = []
var _list: ItemList
var _info: Label
var _start: Button
var _misses_label: Label
var _key_label: Label
var _diff_desc: Label
var _diff_buttons: Array[Button] = []
var _octave: CheckButton
var _device: OptionButton
var _level: ProgressBar
var _level_fill_on: StyleBoxFlat
var _level_fill_off: StyleBoxFlat
var _detected: Label
var _detected_sub: Label
var _title: Label
var _help: Control
var _click: AudioStreamPlayer
var _drawer: Control
var _mic_button: Button
var _mic_dot: Panel
var _selected_label: Label


func _ready() -> void:
	_world = RollingWorld.new()
	_world.camera_mode = RollingWorld.CameraMode.MENU
	add_child(_world)
	_world.speed = 5.0
	_world.coin.instability = 0.12

	_click = AudioStreamPlayer.new()
	_click.stream = load("res://assets/audio/coin.ogg")
	_click.bus = "SFX"
	add_child(_click)

	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = GameSettings.theme
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_build()
	_refresh_songs()
	_animate_in()


# ── 화면 구성 ─────────────────────────────────────────────
func _build() -> void:
	# 왼쪽을 어둡게 깔아 글씨가 잘 보이게 하는 그라데이션
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.06, 0.07, 0.16, 0.9))
	grad.set_color(1, Color(0.06, 0.07, 0.16, 0.0))
	grad.add_point(0.6, Color(0.06, 0.07, 0.16, 0.65))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(1, 0)
	shade.texture = gtex
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.62
	shade.offset_right = 0
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)

	# ── 왼쪽: 제목 · 노래 · 규칙 ──
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(580, 0)
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	_title = Label.new()
	_title.text = "Rolling Voice"
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", 62)
	left.add_child(_title)
	var subtitle := Label.new()
	subtitle.text = "굴러가는 동전이 쓰러지기 전에, 끝까지 불러요!"
	subtitle.theme_type_variation = "MutedLabel"
	subtitle.add_theme_font_size_override("font_size", 22)
	left.add_child(subtitle)
	left.add_child(_build_song_card())
	left.add_child(_build_rule_card())

	# ── 오른쪽: 동전이 보이도록 비워 두고 위에는 마이크 버튼, 아래에는 시작 버튼 ──
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(right)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(top_row)
	_mic_button = Button.new()
	_mic_button.text = "마이크 · 소리"
	_mic_button.icon = UiTheme.icon("mic")
	_mic_button.custom_minimum_size = Vector2(0, 54)
	_mic_button.pressed.connect(func() -> void: _toggle_drawer(true))
	_mic_dot = Panel.new()
	_mic_dot.custom_minimum_size = Vector2(14, 14)
	_mic_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mic_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mic_dot.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.MUTED, 999, 0.0))
	_mic_dot.tooltip_text = "초록색이면 목소리가 잡히고 있어요"
	top_row.add_theme_constant_override("separation", 10)
	top_row.add_child(_mic_dot)
	top_row.add_child(_mic_button)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(gap)

	var start_card := PanelContainer.new()
	start_card.theme_type_variation = "GlassPanel"
	start_card.custom_minimum_size = Vector2(500, 0)
	start_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(start_card)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	start_card.add_child(sv)
	_selected_label = Label.new()
	_selected_label.theme_type_variation = "HeadingLabel"
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.clip_text = true
	sv.add_child(_selected_label)
	_start = Button.new()
	_start.theme_type_variation = "PrimaryButton"
	_start.text = "시작하기"
	_start.icon = UiTheme.icon("play_arrow")
	_start.custom_minimum_size = Vector2(0, 76)
	_start.pressed.connect(_on_start)
	sv.add_child(_start)

	_build_drawer()
	_build_help()


func _build_drawer() -> void:
	_drawer = Control.new()
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.visible = false
	_ui.add_child(_drawer)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.08, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_toggle_drawer(false))
	_drawer.add_child(dim)
	var card := _build_mic_card()
	card.name = "Card"
	card.custom_minimum_size = Vector2(500, 0)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = -530
	card.offset_right = -30
	card.offset_top = 30
	card.offset_bottom = 30
	card.grow_vertical = Control.GROW_DIRECTION_END
	_drawer.add_child(card)
	var close := Button.new()
	close.theme_type_variation = "PrimaryButton"
	close.add_theme_font_size_override("font_size", 24)
	close.text = "확인"
	close.icon = UiTheme.icon("check_circle")
	close.custom_minimum_size = Vector2(0, 58)
	close.pressed.connect(func() -> void: _toggle_drawer(false))
	card.get_child(0).add_child(close)


func _toggle_drawer(open: bool) -> void:
	var card: Control = _drawer.get_node("Card")
	var dim: Control = _drawer.get_node("Dim")
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if open:
		_drawer.visible = true
		card.offset_left = 30
		card.offset_right = 530
		dim.modulate.a = 0.0
		tw.tween_property(card, "offset_left", -530.0, 0.35)
		tw.tween_property(card, "offset_right", -30.0, 0.35)
		tw.tween_property(dim, "modulate:a", 1.0, 0.3)
	else:
		GameSettings.save_settings()
		tw.tween_property(card, "offset_left", 30.0, 0.3)
		tw.tween_property(card, "offset_right", 530.0, 0.3)
		tw.tween_property(dim, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(func() -> void: _drawer.visible = false)


func _card(title: String, icon_name: String) -> Array:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, 24, 18.0, 1, UiTheme.LINE, 18, Vector2(0, 8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = UiTheme.icon(icon_name)
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = UiTheme.GOLD
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var l := Label.new()
	l.text = title
	l.theme_type_variation = "HeadingLabel"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	return [card, v, head]


func _row(label_text: String, control: Control, parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(130, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	parent.add_child(row)
	return row


func _slider(value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(on_change)
	return s


func _build_mic_card() -> PanelContainer:
	var c := _card("마이크 · 소리", "mic")
	var v: VBoxContainer = c[1]

	_device = OptionButton.new()
	_device.fit_to_longest_item = false
	_device.clip_text = true
	var devices := AudioServer.get_input_device_list()
	for i in devices.size():
		_device.add_item("기본 마이크" if devices[i] == "Default" else devices[i])
		_device.set_item_metadata(i, devices[i])
		if devices[i] == GameSettings.input_device:
			_device.select(i)
	_device.item_selected.connect(func(i: int) -> void:
		GameSettings.input_device = _device.get_item_metadata(i)
		GameSettings.apply())
	_row("입력 장치", _device, v)

	# 실시간 음 감지 미리보기
	var meter := PanelContainer.new()
	meter.theme_type_variation = "SoftPanel"
	v.add_child(meter)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 14)
	meter.add_child(mh)
	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mh.add_child(mv)
	var cap := Label.new()
	cap.text = "아무 음이나 소리 내 보세요"
	cap.theme_type_variation = "MutedLabel"
	mv.add_child(cap)
	_level = ProgressBar.new()
	_level.theme_type_variation = "LevelBar"
	_level.custom_minimum_size = Vector2(0, 14)
	_level.show_percentage = false
	mv.add_child(_level)
	_level_fill_on = UiTheme.box(UiTheme.GOOD, 999, 0.0)
	_level_fill_off = UiTheme.box(Color(UiTheme.MUTED, 0.6), 999, 0.0)
	var dv := VBoxContainer.new()
	dv.custom_minimum_size = Vector2(110, 0)
	dv.add_theme_constant_override("separation", -4)
	mh.add_child(dv)
	_detected = Label.new()
	_detected.theme_type_variation = "BigLabel"
	_detected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detected.text = "—"
	dv.add_child(_detected)
	_detected_sub = Label.new()
	_detected_sub.theme_type_variation = "MutedLabel"
	_detected_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detected_sub.text = " "
	dv.add_child(_detected_sub)

	var sens := _slider(inverse_lerp(0.08, 0.004, GameSettings.mic_threshold), func(x: float) -> void:
		GameSettings.mic_threshold = lerpf(0.08, 0.004, x)
		GameSettings.apply())
	sens.tooltip_text = "오른쪽으로 갈수록 작은 소리도 잡아요. 주변 소음이 잡히면 왼쪽으로."
	_row("마이크 감도", sens, v)
	_row("가이드 멜로디", _slider(GameSettings.guide_volume, func(x: float) -> void:
		GameSettings.guide_volume = x
		GameSettings.apply()), v)
	_row("반주 · 효과음", _slider(GameSettings.backing_volume, func(x: float) -> void:
		GameSettings.backing_volume = x
		GameSettings.sfx_volume = x
		GameSettings.apply()), v)

	var tip := HBoxContainer.new()
	tip.add_theme_constant_override("separation", 8)
	var hi := TextureRect.new()
	hi.texture = UiTheme.icon("headphones")
	hi.custom_minimum_size = Vector2(22, 22)
	hi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hi.modulate = UiTheme.MUTED
	tip.add_child(hi)
	var tl := Label.new()
	tl.text = "이어폰을 끼면 노래 소리가 마이크에 섞이지 않아 판정이 정확해요"
	tl.theme_type_variation = "MutedLabel"
	tl.add_theme_font_size_override("font_size", 16)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_child(tl)
	v.add_child(tip)
	return c[0]


func _build_song_card() -> PanelContainer:
	var c := _card("노래 고르기", "library_music")
	var v: VBoxContainer = c[1]
	var head: HBoxContainer = c[2]
	c[0].size_flags_vertical = Control.SIZE_EXPAND_FILL

	var help := Button.new()
	help.text = "내 노래 추가"
	help.icon = UiTheme.icon("folder_open")
	help.add_theme_font_size_override("font_size", 18)
	help.pressed.connect(func() -> void: _help.visible = true)
	head.add_child(help)
	var refresh := Button.new()
	refresh.theme_type_variation = "IconButton"
	refresh.icon = UiTheme.icon("refresh")
	refresh.tooltip_text = "노래 목록 새로고침"
	refresh.pressed.connect(_refresh_songs)
	head.add_child(refresh)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 100)
	_list.fixed_icon_size = Vector2i(24, 24)
	_list.item_selected.connect(_on_song_selected)
	_list.item_activated.connect(func(_i: int) -> void: _on_start())
	v.add_child(_list)

	_info = Label.new()
	_info.theme_type_variation = "MutedLabel"
	_info.text = " "
	_info.clip_text = true
	v.add_child(_info)
	return c[0]


func _build_rule_card() -> PanelContainer:
	var c := _card("규칙", "tune")
	var v: VBoxContainer = c[1]

	# 최대 실수 횟수 · 키 조절 (− 값 +) 을 한 줄에
	var steppers := HBoxContainer.new()
	steppers.add_theme_constant_override("separation", 10)
	var ms := _stepper(func() -> void: _change_misses(-1), func() -> void: _change_misses(1))
	_misses_label = ms[1]
	ms[0].tooltip_text = "이 횟수만큼 틀리면 동전이 쓰러져요"
	steppers.add_child(ms[0])
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steppers.add_child(gap)
	var key_caption := Label.new()
	key_caption.text = "키"
	key_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steppers.add_child(key_caption)
	var ks := _stepper(func() -> void: _change_key(-1), func() -> void: _change_key(1))
	_key_label = ks[1]
	ks[0].tooltip_text = "반음 단위로 노래 전체를 올리거나 내려요 (정답 음·가이드·반주 모두)"
	steppers.add_child(ks[0])
	_row("최대 실수", steppers, v)
	_change_misses(0)

	# 난이도 (세그먼트 버튼)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in GameSettings.DIFFICULTIES.size():
		var b := Button.new()
		b.theme_type_variation = "SegmentButton"
		b.text = GameSettings.DIFFICULTIES[i].name
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = i == GameSettings.difficulty
		b.pressed.connect(func() -> void:
			GameSettings.difficulty = i
			_update_diff_desc())
		seg.add_child(b)
		_diff_buttons.append(b)
	_row("난이도", seg, v)
	_diff_desc = Label.new()
	_diff_desc.theme_type_variation = "MutedLabel"
	_diff_desc.add_theme_font_size_override("font_size", 16)
	var desc_row := HBoxContainer.new()
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(142, 0)
	desc_row.add_child(pad)
	desc_row.add_child(_diff_desc)
	v.add_child(desc_row)
	_update_diff_desc()

	_octave = CheckButton.new()
	_octave.text = "한 옥타브 높거나 낮게 불러도 정답"
	_octave.button_pressed = GameSettings.ignore_octave
	_octave.toggled.connect(func(on: bool) -> void: GameSettings.ignore_octave = on)
	_row("옥타브 무시", _octave, v)
	return c[0]


func _build_help() -> void:
	_help = Control.new()
	_help.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help.visible = false
	_ui.add_child(_help)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_help.visible = false)
	_help.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var t := Label.new()
	t.text = "내 노래 추가하는 법"
	t.theme_type_variation = "HeadingLabel"
	t.add_theme_font_size_override("font_size", 34)
	v.add_child(t)
	var steps := [
		["MIDI 파일 (.mid)", "멜로디가 들어 있는 MIDI를 넣으면 노래 트랙을 자동으로 찾아요.\n같은 이름의 mp3·ogg·wav가 있으면 반주로 함께 재생해요. (예: 내노래.mid + 내노래.mp3)"],
		["텍스트 악보 (.txt)", "메모장으로 '음이름/박자/가사'를 적으면 돼요.  예) C4  D4/2  솔4/0.5/라  R(쉼표)\n머리말: title=제목  bpm=빠르기  transpose=조옮김  audio=반주파일  offset=첫 음까지 초"],
		["넣은 뒤에는", "목록 오른쪽 위 새로고침 버튼을 누르세요. 폴더 안 '예시_도레미(가사).txt'를 참고하면 쉬워요."],
	]
	for s in steps:
		var box := PanelContainer.new()
		box.theme_type_variation = "SoftPanel"
		var bv := VBoxContainer.new()
		box.add_child(bv)
		var h := Label.new()
		h.text = s[0]
		h.add_theme_color_override("font_color", UiTheme.GOLD)
		bv.add_child(h)
		var b := Label.new()
		b.text = s[1]
		b.theme_type_variation = "MutedLabel"
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bv.add_child(b)
		v.add_child(box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var close := Button.new()
	close.text = "닫기"
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.custom_minimum_size = Vector2(0, 56)
	close.pressed.connect(func() -> void: _help.visible = false)
	buttons.add_child(close)
	var open := Button.new()
	open.theme_type_variation = "PrimaryButton"
	open.add_theme_font_size_override("font_size", 24)
	open.text = "노래 폴더 열기"
	open.icon = UiTheme.icon("folder_open")
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.custom_minimum_size = Vector2(0, 56)
	open.pressed.connect(func() -> void:
		SongLibrary.ensure_songs_dir()
		OS.shell_open(ProjectSettings.globalize_path(SongLibrary.SONGS_DIR)))
	buttons.add_child(open)


# ── 동작 ──────────────────────────────────────────────────
func _refresh_songs() -> void:
	_songs = SongLibrary.load_all()
	_list.clear()
	var select := 0
	for i in _songs.size():
		var s := _songs[i]
		var icon_name := "music_note" if s.id.begins_with("builtin") else "library_music"
		var idx := _list.add_item(s.title, UiTheme.icon(icon_name))
		_list.set_item_tooltip(idx, "%s\n%s" % [s.source, s.summary()])
		if not s.is_playable():
			_list.set_item_custom_fg_color(idx, Color(UiTheme.BAD, 0.85))
		if s.id == GameSettings.last_song_id:
			select = i
	if not _songs.is_empty():
		_list.select(select)
		_list.ensure_current_is_visible()
		_on_song_selected(select)


func _on_song_selected(i: int) -> void:
	var s := _songs[i]
	_info.text = "%s  ·  %s" % [s.source, s.summary()]
	_selected_label.text = s.title
	_update_key_label(s)
	_info.add_theme_color_override("font_color", UiTheme.MUTED if s.is_playable() else UiTheme.BAD)
	_start.disabled = not s.is_playable()


func _stepper(on_minus: Callable, on_plus: Callable) -> Array:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var minus := Button.new()
	minus.text = "-"
	minus.add_theme_font_size_override("font_size", 30)
	minus.custom_minimum_size = Vector2(44, 40)
	minus.pressed.connect(on_minus)
	box.add_child(minus)
	var value := Label.new()
	value.theme_type_variation = "BigLabel"
	value.add_theme_font_size_override("font_size", 32)
	value.custom_minimum_size = Vector2(62, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 30)
	plus.custom_minimum_size = Vector2(44, 40)
	plus.pressed.connect(on_plus)
	box.add_child(plus)
	return [box, value]


func _pop(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.25, 1.25)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _selected_song() -> SongData:
	var sel := _list.get_selected_items()
	return _songs[sel[0]] if not sel.is_empty() else null


func _change_key(d: int) -> void:
	var s := _selected_song()
	if s == null:
		return
	GameSettings.set_key(s.id, GameSettings.get_key(s.id) + d)
	_update_key_label(s)
	if d != 0:
		_pop(_key_label)


func _update_key_label(s: SongData) -> void:
	var k := GameSettings.get_key(s.id)
	_key_label.text = "%+d" % k if k != 0 else "0"
	_key_label.add_theme_color_override("font_color", UiTheme.TEXT if k == 0 else UiTheme.GOLD)
	var r := s.midi_range()
	_key_label.tooltip_text = "음역 %s~%s" % [NoteUtils.midi_name(r.x + k), NoteUtils.midi_name(r.y + k)]


func _change_misses(d: int) -> void:
	GameSettings.max_misses = clampi(GameSettings.max_misses + d, 1, GameSettings.MAX_MISSES_LIMIT)
	_misses_label.text = str(GameSettings.max_misses)
	if d != 0:
		_pop(_misses_label)
	_world.coin.instability = clampf(0.6 / GameSettings.max_misses, 0.05, 0.5)


func _update_diff_desc() -> void:
	var d: Dictionary = GameSettings.DIFFICULTIES[GameSettings.difficulty]
	_diff_desc.text = "%s (허용 ±%d센트)" % [d.desc, int(d.cents)]


func _on_start() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty() or not _songs[sel[0]].is_playable():
		return
	GameSettings.selected_song = _songs[sel[0]]
	GameSettings.last_song_id = GameSettings.selected_song.id
	GameSettings.save_settings()
	_click.play()
	var fade := ColorRect.new()
	fade.color = Color(0.06, 0.07, 0.16, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _help.visible:
			_help.visible = false
		elif _drawer.visible:
			_toggle_drawer(false)
		get_viewport().set_input_as_handled()


func _animate_in() -> void:
	var items: Array[Control] = []
	var margin := _ui.get_child(1)
	var cols := margin.get_child(0)
	for column in cols.get_children():
		for child in column.get_children():
			if child is Control:
				items.append(child)
	for i in items.size():
		var c := items[i]
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	# 제목이 동전처럼 살짝 흔들흔들
	_title.rotation = sin(Time.get_ticks_msec() / 700.0) * 0.015
	_title.pivot_offset = _title.size * Vector2(0.3, 0.5)
	# 마이크 미리보기
	_level.value = clampf(sqrt(PitchDetector.level / 0.25), 0.0, 1.0) * 100.0
	_level.add_theme_stylebox_override("fill", _level_fill_on if PitchDetector.voiced else _level_fill_off)
	_mic_dot.add_theme_stylebox_override("panel", _level_fill_on if PitchDetector.voiced else _level_fill_off)
	if PitchDetector.voiced:
		var m := roundi(PitchDetector.midi)
		_detected.text = NoteUtils.solfege(m)
		_detected_sub.text = "%s · %dHz" % [NoteUtils.midi_name(m), roundi(PitchDetector.hz)]
		_detected.add_theme_color_override("font_color", UiTheme.GOOD)
	else:
		_detected.add_theme_color_override("font_color", UiTheme.MUTED)
