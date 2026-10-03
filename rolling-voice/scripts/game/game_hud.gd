class_name GameHud
extends Control
## 플레이 화면 UI: 곡 정보, 남은 기회(동전 아이콘), 음정 레인, 목표/내 음, 진행 막대,
## 카운트다운, 판정 토스트, 결과 창.

signal retry_pressed
signal menu_pressed

const COIN_TEX := preload("res://assets/sprites/coin.png")
const ICON_LIMIT := 10

var lane: PitchLane

var _title: Label
var _source: Label
var _lives_box: HBoxContainer
var _lives_label: Label
var _lives_bar: ProgressBar
var _life_icons: Array[TextureRect] = []
var _max_misses := 5
var _target_label: Label
var _target_sub: Label
var _voice_label: Label
var _voice_sub: Label
var _voice_card: PanelContainer
var _progress: ProgressBar
var _time_label: Label
var _countdown: Label
var _hint: Label
var _overlay: Control
var _duration := 1.0
var _last_count := ""


func _ready() -> void:
	theme = GameSettings.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# ── 상단: 곡 정보 / 남은 기회 ─────────────────────────
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)

	var song_card := PanelContainer.new()
	song_card.theme_type_variation = "GlassPanel"
	top.add_child(song_card)
	var song_row := HBoxContainer.new()
	song_row.add_theme_constant_override("separation", 12)
	song_card.add_child(song_row)
	var note_icon := TextureRect.new()
	note_icon.texture = UiTheme.icon("music_note")
	note_icon.custom_minimum_size = Vector2(30, 30)
	note_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	note_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	note_icon.modulate = UiTheme.GOLD
	song_row.add_child(note_icon)
	_title = Label.new()
	_title.theme_type_variation = "HeadingLabel"
	song_row.add_child(_title)
	_source = Label.new()
	_source.theme_type_variation = "ChipLabel"
	_source.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	song_row.add_child(_source)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	var lives_card := PanelContainer.new()
	lives_card.theme_type_variation = "GlassPanel"
	top.add_child(lives_card)
	var lives_row := HBoxContainer.new()
	lives_row.add_theme_constant_override("separation", 12)
	lives_card.add_child(lives_row)
	_lives_label = Label.new()
	_lives_label.theme_type_variation = "HeadingLabel"
	lives_row.add_child(_lives_label)
	_lives_box = HBoxContainer.new()
	_lives_box.add_theme_constant_override("separation", 4)
	lives_row.add_child(_lives_box)
	_lives_bar = ProgressBar.new()
	_lives_bar.custom_minimum_size = Vector2(180, 16)
	_lives_bar.show_percentage = false
	_lives_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lives_bar.visible = false
	lives_row.add_child(_lives_bar)

	var quit := Button.new()
	quit.theme_type_variation = "IconButton"
	quit.icon = UiTheme.icon("home")
	quit.tooltip_text = "노래 고르기로 돌아가기 (Esc)"
	quit.custom_minimum_size = Vector2(56, 56)
	quit.focus_mode = Control.FOCUS_NONE
	quit.pressed.connect(menu_pressed.emit)
	top.add_child(quit)

	# ── 음정 레인 ─────────────────────────────────────────
	var lane_card := PanelContainer.new()
	lane_card.theme_type_variation = "GlassPanel"
	lane_card.custom_minimum_size = Vector2(0, 230)
	col.add_child(lane_card)
	lane = PitchLane.new()
	lane.custom_minimum_size = Vector2(0, 200)
	lane_card.add_child(lane)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)

	# ── 하단: 목표 음 / 내 음 / 진행 ─────────────────────
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 14)
	col.add_child(bottom)

	var target_card := _note_card("목표 음", UiTheme.SKY)
	bottom.add_child(target_card[0])
	_target_label = target_card[1]
	_target_sub = target_card[2]
	var voice_card := _note_card("내 음", UiTheme.GOOD)
	bottom.add_child(voice_card[0])
	_voice_card = voice_card[0]
	_voice_label = voice_card[1]
	_voice_sub = voice_card[2]

	var prog_card := PanelContainer.new()
	prog_card.theme_type_variation = "GlassPanel"
	prog_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_card.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(prog_card)
	var prog_col := VBoxContainer.new()
	prog_col.add_theme_constant_override("separation", 6)
	prog_card.add_child(prog_col)
	var prog_head := HBoxContainer.new()
	prog_col.add_child(prog_head)
	var pl := Label.new()
	pl.text = "진행"
	pl.theme_type_variation = "MutedLabel"
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_head.add_child(pl)
	_time_label = Label.new()
	_time_label.theme_type_variation = "MutedLabel"
	prog_head.add_child(_time_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 14)
	_progress.show_percentage = false
	prog_col.add_child(_progress)

	# ── 화면 가운데: 카운트다운 · 안내 ───────────────────
	_countdown = Label.new()
	_countdown.theme_type_variation = "TitleLabel"
	_countdown.add_theme_font_size_override("font_size", 120)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown.offset_top = 120
	_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_countdown)

	_hint = Label.new()
	_hint.theme_type_variation = "ChipLabel"
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.BAD, 0.92), 999, 10.0))
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -190
	_hint.offset_bottom = -150
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.visible = false
	add_child(_hint)


func _note_card(caption: String, color: Color) -> Array:
	var card := PanelContainer.new()
	card.theme_type_variation = "GlassPanel"
	card.custom_minimum_size = Vector2(170, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var cap := Label.new()
	cap.text = caption
	cap.theme_type_variation = "MutedLabel"
	v.add_child(cap)
	var big := Label.new()
	big.theme_type_variation = "BigLabel"
	big.add_theme_color_override("font_color", color)
	big.text = "—"
	v.add_child(big)
	var sub := Label.new()
	sub.theme_type_variation = "MutedLabel"
	sub.text = " "
	v.add_child(sub)
	return [card, big, sub]


# ── 상태 갱신 ─────────────────────────────────────────────
func setup(song: SongData, max_misses: int) -> void:
	_title.text = song.title
	_source.text = song.source
	_duration = maxf(song.duration(), 1.0)
	_max_misses = max_misses
	for c in _lives_box.get_children():
		c.queue_free()
	_life_icons.clear()
	var use_icons := max_misses <= ICON_LIMIT
	_lives_box.visible = use_icons
	_lives_bar.visible = not use_icons
	if use_icons:
		for i in max_misses:
			var tr := TextureRect.new()
			tr.texture = COIN_TEX
			tr.custom_minimum_size = Vector2(34, 34)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.pivot_offset = Vector2(17, 17)
			_lives_box.add_child(tr)
			_life_icons.append(tr)
	_lives_bar.max_value = max_misses
	set_lives(0)
	lane.set_song(song)
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func set_lives(misses: int) -> void:
	var left := maxi(_max_misses - misses, 0)
	_lives_label.text = "남은 기회 %d" % left
	_lives_bar.value = left
	for i in _life_icons.size():
		var icon := _life_icons[i]
		var alive := i < left
		var target_mod := Color.WHITE if alive else Color(0.3, 0.3, 0.45, 0.45)
		if icon.modulate != target_mod:
			if not alive:
				var tw := icon.create_tween()
				tw.tween_property(icon, "scale", Vector2(1.6, 1.6), 0.12)
				tw.tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
				tw.parallel().tween_property(icon, "modulate", target_mod, 0.3)
			else:
				icon.modulate = target_mod


func set_progress(t: float) -> void:
	_progress.value = clampf(t / _duration, 0.0, 1.0) * 100.0
	var cur := int(clampf(t, 0.0, _duration))
	var tot := int(_duration)
	_time_label.text = "%d:%02d / %d:%02d" % [cur / 60, cur % 60, tot / 60, tot % 60]


func set_target(midi: int) -> void:
	if midi < 0:
		_target_label.text = "쉼"
		_target_sub.text = " "
	else:
		_target_label.text = NoteUtils.solfege(midi)
		_target_sub.text = NoteUtils.midi_name(midi)


func set_voice(midi: float, voiced: bool, in_tune: bool, has_target: bool) -> void:
	if not voiced:
		_voice_label.text = "—"
		_voice_sub.text = "소리를 내 주세요" if has_target else " "
		_voice_label.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var m := roundi(midi)
	_voice_label.text = NoteUtils.solfege(m)
	_voice_sub.text = "%s · %dHz" % [NoteUtils.midi_name(m), roundi(NoteUtils.midi_to_hz(midi))]
	var c := UiTheme.GOOD if in_tune or not has_target else Color("ff9f43")
	_voice_label.add_theme_color_override("font_color", c)


func set_countdown(text: String) -> void:
	if text == _last_count:
		return
	_last_count = text
	_countdown.text = text
	if text.is_empty():
		return
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2(1.6, 1.6)
	_countdown.modulate = Color(1, 1, 1, 0)
	var tw := _countdown.create_tween().set_parallel()
	tw.tween_property(_countdown, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_countdown, "modulate", Color.WHITE, 0.2)
	if text == "시작!":
		tw.chain().tween_interval(0.35)
		tw.chain().tween_property(_countdown, "modulate", Color(1, 1, 1, 0), 0.3)


func set_hint(text: String) -> void:
	_hint.visible = not text.is_empty()
	_hint.text = text


## 판정 토스트 ("삐끗!", "좋아요!")가 동전 위에서 떠올랐다 사라진다.
func toast(text: String, color: Color, big := false) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "BigLabel"
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 56 if big else 34)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.size = l.get_combined_minimum_size()
	var vp := size
	l.position = Vector2(vp.x * 0.5 - l.size.x * 0.5 + randf_range(-60, 60), vp.y * 0.56)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


# ── 결과 창 ───────────────────────────────────────────────
func show_result(cleared: bool, stats: Dictionary) -> void:
	set_countdown("")
	set_hint("")
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)

	var title := Label.new()
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 64)
	title.text = "완주 성공!" if cleared else "동전이 쓰러졌어요"
	if not cleared:
		title.add_theme_color_override("font_color", UiTheme.BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sub := Label.new()
	sub.theme_type_variation = "MutedLabel"
	sub.add_theme_font_size_override("font_size", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.text = stats.get("song", "")
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var rows := [
		["실수", "%d / %d" % [stats.misses, stats.max_misses]],
		["음정 정확도", "%d%%" % roundi(stats.accuracy * 100.0)],
		["통과한 음표", "%d / %d" % [stats.passed, stats.judged]],
		["진행률", "%d%%" % roundi(stats.progress * 100.0)],
	]
	for r in rows:
		var cell := PanelContainer.new()
		cell.theme_type_variation = "SoftPanel"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cell.add_child(cv)
		var k := Label.new()
		k.text = r[0]
		k.theme_type_variation = "MutedLabel"
		cv.add_child(k)
		var val := Label.new()
		val.text = r[1]
		val.theme_type_variation = "BigLabel"
		val.add_theme_font_size_override("font_size", 38)
		cv.add_child(val)
		grid.add_child(cell)

	# 완주했을 때만 별 1~3개 (정확도 60%, 80% 기준)
	if cleared:
		var count := 1 + int(stats.accuracy >= 0.6) + int(stats.accuracy >= 0.8)
		var star_row := HBoxContainer.new()
		star_row.alignment = BoxContainer.ALIGNMENT_CENTER
		star_row.add_theme_constant_override("separation", 10)
		v.add_child(star_row)
		v.move_child(star_row, 2)
		for i in 3:
			var st := Label.new()
			st.text = "★"
			st.theme_type_variation = "TitleLabel"
			st.add_theme_font_size_override("font_size", 58)
			st.pivot_offset = Vector2(29, 40)
			if i >= count:
				st.add_theme_color_override("font_color", Color(1, 1, 1, 0.15))
			st.scale = Vector2.ZERO
			star_row.add_child(st)
			var tw := st.create_tween()
			tw.tween_interval(0.35 + i * 0.18)
			tw.tween_property(st, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var menu := Button.new()
	menu.text = "노래 고르기"
	menu.icon = UiTheme.icon("library_music")
	menu.custom_minimum_size = Vector2(0, 64)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(menu_pressed.emit)
	buttons.add_child(menu)
	var retry := Button.new()
	retry.theme_type_variation = "PrimaryButton"
	retry.text = "다시 하기"
	retry.icon = UiTheme.icon("replay")
	retry.custom_minimum_size = Vector2(0, 64)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(retry_pressed.emit)
	buttons.add_child(retry)

	# 등장 애니메이션
	card.modulate.a = 0.0
	card.scale = Vector2(0.85, 0.85)
	await get_tree().process_frame
	card.pivot_offset = card.size * 0.5
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(dim, "modulate:a", 1.0, 0.4)
	tw2.tween_property(card, "modulate:a", 1.0, 0.3)
	tw2.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	retry.grab_focus()
