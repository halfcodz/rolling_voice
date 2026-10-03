extends Node
## 플레이 화면.
## 흐름: 카운트인 → 노래(가이드 멜로디 + 반주) → 음표마다 판정 → 완주 또는 동전 쓰러짐 → 결과.
##
## 판정 규칙
##  - 음표 하나가 끝날 때, 그 음표 동안 '허용 범위 안의 음정으로 부른 시간 비율'을 본다.
##  - 비율이 난이도별 기준(쉬움 30% / 보통 45% / 어려움 60%)보다 낮으면 실수 1회.
##    (아예 안 부른 것도 실수)
##  - 아주 짧은 음표(0.25초 미만)는 판정하지 않는다.
##  - 실수가 설정한 '최대 실수 횟수'에 닿으면 동전이 쓰러진다.

enum State { COUNTDOWN, PLAYING, FALLEN, CLEARED }

const MIC_LATENCY := 0.09     ## 마이크 입력 지연 보정(초)
const MIN_JUDGE_LEN := 0.25
const END_PADDING := 1.2

var song: SongData
var state := State.COUNTDOWN
var misses := 0

var _world: RollingWorld
var _hud: GameHud
var _synth: MelodySynth
var _backing: AudioStreamPlayer
var _sfx: Dictionary = {}
var _start_usec := 0
var _cur := 0
var _good := 0
var _samples := 0
var _total_good := 0
var _total_samples := 0
var _passed := 0
var _judged := 0
var _silent_time := 0.0
var _autoplay := ""   ## 테스트용: "good" / "bad" (명령줄 -- autoplay=good)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("autoplay="):
			_autoplay = arg.get_slice("=", 1)
	song = GameSettings.selected_song
	if song == null:
		song = SongLibrary.load_all()[0]

	_world = RollingWorld.new()
	_world.camera_mode = RollingWorld.CameraMode.GAME
	add_child(_world)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = GameHud.new()
	layer.add_child(_hud)
	_hud.retry_pressed.connect(_on_retry)
	_hud.menu_pressed.connect(_on_menu)

	_synth = MelodySynth.new()
	add_child(_synth)
	_backing = AudioStreamPlayer.new()
	_backing.bus = "Music"
	add_child(_backing)
	for key in ["coin", "fall", "land", "break", "jump"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.ogg" % key)
		p.bus = "SFX"
		add_child(p)
		_sfx[key] = p

	_start()


func _start() -> void:
	misses = 0
	_cur = 0
	_good = 0
	_samples = 0
	_total_good = 0
	_total_samples = 0
	_passed = 0
	_judged = 0
	_silent_time = 0.0
	state = State.COUNTDOWN
	_world.reset()
	_hud.setup(song, GameSettings.max_misses)
	_hud.lane.tolerance_cents = GameSettings.tolerance_cents()
	_hud.lane.ignore_octave = GameSettings.ignore_octave

	_synth.setup(song)
	_backing.stream = null
	if not song.audio_path.is_empty():
		_backing.stream = SongLibrary.load_audio_stream(song.audio_path)
		if _backing.stream == null:
			_hud.set_hint("반주 파일을 열 수 없어서 가이드 멜로디만 재생해요")
	_backing.volume_db = 0.0
	_start_usec = Time.get_ticks_usec()
	_synth.start()
	if _backing.stream:
		_backing.play()
	_world.show_finish_after(song.duration() + 0.6)


func song_time() -> float:
	if _backing.playing:
		return _backing.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return (Time.get_ticks_usec() - _start_usec) / 1000000.0 - AudioServer.get_output_latency()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu()


func _process(delta: float) -> void:
	if state == State.FALLEN or state == State.CLEARED:
		return
	var t := song_time()
	var te := t - MIC_LATENCY

	# 카운트다운 표시
	var first := song.first_note_time()
	var remain := first - t
	if remain > 0.0 and remain <= 3.0:
		_hud.set_countdown(str(ceili(remain)))
	elif remain <= 0.0 and remain > -0.8:
		_hud.set_countdown("시작!")
		state = State.PLAYING

	# 지금 부르는 음
	var target_midi := -1
	var active := false
	if _cur < song.notes.size():
		var n: Dictionary = song.notes[_cur]
		if te >= n.start and te <= n.end:
			target_midi = n.midi
			active = true
	var voice := _read_voice(target_midi, t)
	var sung: float = voice[0]
	var voiced: bool = voice[1]
	var in_tune := voiced and target_midi >= 0 and \
		NoteUtils.cents_diff(sung, target_midi, GameSettings.ignore_octave) <= GameSettings.tolerance_cents()

	# 판정 진행
	while _cur < song.notes.size() and te > song.notes[_cur].end:
		_finish_note(_cur)
		_cur += 1
		_good = 0
		_samples = 0
		if state == State.FALLEN:
			return
	if _cur < song.notes.size():
		var n2: Dictionary = song.notes[_cur]
		var grace := minf(0.12, (n2.end - n2.start) * 0.25)
		if te >= n2.start + grace and te <= n2.end:
			_samples += 1
			if in_tune:
				_good += 1

	# 실시간 흔들림: 음이 틀리면 1, 소리가 없으면 0.4
	var live := 0.0
	if active:
		live = 0.0 if in_tune else (1.0 if voiced else 0.4)
	_world.coin.live_off = live
	_world.coin.instability = float(misses) / GameSettings.max_misses

	# 마이크가 조용하면 안내
	if active and not voiced:
		_silent_time += delta
	elif voiced:
		_silent_time = 0.0
	_hud.set_hint("마이크에 소리가 들어오지 않아요 — 메뉴에서 마이크·감도를 확인해 주세요" if _silent_time > 4.0 and _autoplay.is_empty() else "")

	# UI
	_hud.lane.current_index = _cur if _cur < song.notes.size() else -1
	_hud.lane.push_voice(te, sung, voiced, float(target_midi) if target_midi >= 0 else -1.0, in_tune)
	_hud.set_progress(t)
	var upcoming := target_midi
	if upcoming < 0 and _cur < song.notes.size():
		upcoming = song.notes[_cur].midi
	_hud.set_target(upcoming)
	_hud.set_voice(sung, voiced, in_tune, active)

	if _cur >= song.notes.size() and te > song.duration() + 0.2:
		_clear()


func _read_voice(target_midi: int, t: float) -> Array:
	if _autoplay.is_empty():
		return [PitchDetector.midi, PitchDetector.voiced]
	if target_midi < 0:
		return [0.0, false]
	if _autoplay == "bad":
		return [target_midi + 2.5 + sin(t * 3.0), true]
	return [target_midi + sin(t * 9.0) * 0.15 - 12.0, true]  # 한 옥타브 아래로 정확히


func _finish_note(i: int) -> void:
	var n: Dictionary = song.notes[i]
	if n.end - n.start < MIN_JUDGE_LEN or _samples == 0:
		return
	_judged += 1
	_total_good += _good
	_total_samples += _samples
	var ratio := float(_good) / _samples
	if ratio >= GameSettings.pass_ratio():
		_passed += 1
		_hud.lane.results[i] = 1
		if ratio > 0.85 and randf() < 0.35:
			_hud.toast("좋아요!", UiTheme.GOOD)
	else:
		_hud.lane.results[i] = 2
		misses += 1
		_hud.set_lives(misses)
		_world.coin.hit()
		_world.shake(0.6)
		_sfx["land"].play()
		if misses >= GameSettings.max_misses:
			_fall()
		else:
			_hud.toast("삐끗!", UiTheme.BAD, true)


func _fall() -> void:
	state = State.FALLEN
	_hud.set_countdown("")
	_world.coin.fall()
	_world.stop_rolling(1.2)
	_world.shake(1.0)
	_sfx["fall"].play()
	_synth.fade_out(0.8)
	if _backing.playing:
		create_tween().tween_property(_backing, "volume_db", -60.0, 0.8)
	_world.coin.landed.connect(func() -> void: _sfx["break"].play(), CONNECT_ONE_SHOT)
	await get_tree().create_timer(1.8).timeout
	_show_result(false)


func _clear() -> void:
	state = State.CLEARED
	_world.celebrate()
	_world.stop_rolling(2.5)
	_sfx["coin"].play()
	_hud.toast("완주!", UiTheme.GOLD, true)
	if _backing.playing:
		create_tween().tween_property(_backing, "volume_db", -60.0, 2.0)
	await get_tree().create_timer(1.6).timeout
	_show_result(true)


func _show_result(cleared: bool) -> void:
	var t := song_time()
	_synth.stop()
	_hud.show_result(cleared, {
		"song": song.title,
		"misses": misses,
		"max_misses": GameSettings.max_misses,
		"accuracy": float(_total_good) / maxi(_total_samples, 1),
		"passed": _passed,
		"judged": _judged,
		"progress": 1.0 if cleared else clampf(t / maxf(song.duration(), 0.01), 0.0, 1.0),
	})


func _on_retry() -> void:
	_backing.stop()
	_synth.stop()
	_start()


func _on_menu() -> void:
	_synth.stop()
	_backing.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
