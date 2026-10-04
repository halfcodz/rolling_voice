# Rolling Voice

굴러가는 동전이 쓰러지기 전에, 노래를 끝까지 부르는 Godot 4 노래 게임입니다.

노래가 흘러나오면 마이크로 따라 부릅니다. 음정이 맞지 않으면 동전이 조금씩 휘청이고, 정해 둔 횟수만큼 틀리면 동전이 쓰러집니다.

## 실행 방법

1. [Godot 4.7](https://godotengine.org/download)(Standard, 무료)을 설치합니다.
2. Godot 프로젝트 매니저에서 `rolling-voice/project.godot`를 가져와(Import) 엽니다.
3. <kbd>F5</kbd>로 실행합니다. 처음 실행하면 운영체제가 마이크 권한을 물어볼 수 있습니다.

> 이어폰을 끼고 플레이하세요. 스피커로 나온 가이드 멜로디가 마이크에 다시 들어가면 판정이 틀어집니다.

## 게임 규칙

| 설정 | 설명 |
| --- | --- |
| 최대 실수 | 1~30회. 이 횟수만큼 틀리면 동전이 쓰러집니다. |
| 난이도 | 쉬움 ±100센트 / 보통 ±60센트 / 어려움 ±35센트 (100센트 = 반음) |
| 옥타브 무시 | 한 옥타브 높거나 낮게 불러도 정답으로 칩니다. 남녀 키 차이용입니다. |
| 키 | 반음 단위로 −12 ~ +12. 정답 음, 가이드 멜로디, 반주(피치 시프트)가 함께 바뀌고 곡마다 기억합니다. |

- 음표 하나가 끝날 때마다 그 음표 동안 허용 범위 안에서 부른 시간 비율을 계산합니다. 비율이 기준(쉬움 30% / 보통 45% / 어려움 60%)보다 낮으면 실수 1회입니다.
- 0.25초보다 짧은 음표는 판정하지 않습니다.
- 실수가 쌓일수록 동전이 크게 흔들리고, 지금 음이 틀리고 있으면 잔떨림이 더해집니다.
- 완주하면 음정 정확도에 따라 별 1~3개를 받습니다.

## 내 노래 추가하기

메뉴의 **내 노래 추가 → 노래 폴더 열기**를 누르면 사용자 노래 폴더(`user://songs`)가 열립니다.

- **MIDI (`.mid`)**: 멜로디 트랙을 자동으로 고릅니다. 트랙 이름에 `melody`/`vocal`/`멜로디`/`보컬`이 들어 있으면 그 트랙을 우선 씁니다. 같은 이름의 `.ogg`/`.mp3`/`.wav`가 있으면 반주로 함께 재생합니다.
- **텍스트 악보 (`.txt`)**: 메모장으로 쓸 수 있습니다.

```text
// 주석
title=도레미 연습
bpm=90
도4 레4 미4/2 R 솔4/0.5/가사 C5/2
```

음표는 `음이름[/박자[/가사]]` 형식입니다. 악보 한 줄이 노래방 가사 한 줄이 되고, 가사 안의 `_`는 띄어쓰기입니다. 음이름은 `C4`, `F#3`, `Bb4`처럼 쓰거나 `도4`, `솔#4`처럼 계이름으로 써도 됩니다. `R`은 쉼표입니다. 머리말로 `bpm`(중간에 다시 쓰면 빠르기 변경), `transpose`(반음 단위 조옮김), `audio`(반주 파일), `offset`(반주에서 첫 음까지의 초)을 지정할 수 있습니다.

### 악보 이미지·종이 악보가 있을 때 — MusicXML

`.musicxml` / `.xml` / 압축 `.mxl` 파일을 노래 폴더에 넣으면, 멜로디는 정답 음이 되고 악보 속 가사는 노래방 가사가 됩니다.

1. 무료 악보 인식 프로그램 [Audiveris](https://audiveris.github.io)에 악보 이미지나 PDF를 넣고 MusicXML로 내보냅니다.
2. 인식이 틀린 음은 무료 프로그램 [MuseScore](https://musescore.org)로 열어 고친 뒤 다시 MusicXML로 저장합니다.
3. 노래 폴더에 넣고 목록을 새로고침합니다. 같은 이름의 음원이 있으면 반주로 재생됩니다.

읽는 정보는 음높이(조표·임시표), 박자, 템포(`<sound tempo>`/메트로놈 표기), 붙임줄, 화음(가장 높은 음), 첫 성부, 가사 음절, 시스템 줄바꿈입니다. 꾸밈음은 건너뜁니다. 도돌이표는 펼치지 않으니, 반복이 있으면 MuseScore에서 반복을 펼친 뒤 내보내세요.

### 음원만 있을 때 — 멜로디 자동 추출

메뉴의 **노래 추가 · 가사 → 음원으로 악보 만들기**에서 mp3/ogg/wav를 고르면 멜로디를 뽑아 텍스트 악보 초안을 만듭니다. 음원은 노래 폴더로 복사되고, 같은 곡의 반주로 함께 재생됩니다.

- 음원을 음소거된 분석용 버스에서 4배속으로 재생하며 캡처합니다. 하이패스·로우패스 필터로 보컬 대역을 강조하고, YIN으로 20ms마다 음높이를 잽니다. 짧은 흔들림과 자음 끊김, 옥타브 튐을 정리해서 음표로 묶습니다.
- 보컬이나 멜로디가 또렷한 음원일수록 정확합니다. 반주만 있는 음원은 멜로디를 찾기 어렵습니다.
- 결과는 초안이므로 틀린 음은 메모장으로 고치면 됩니다. 음원은 직접 가지고 있는 파일을 쓰세요.

### 노래방 가사

- **악보 가사**: `C4/1/가사` 형식
- **LRC 파일**: 노래 파일과 같은 이름의 `.lrc`(예: `내노래.mid` + `내노래.lrc`). 줄 단위 `[00:12.30]가사`와 글자 단위 Enhanced LRC `<00:12.30>`를 모두 지원하고, `[offset:]`도 읽습니다.
- **가사 싱크 도구**: **노래 추가 · 가사 → 선택한 노래에 가사 붙이기**에서 가사를 붙여 넣고 노래를 재생한 뒤, 줄이 시작될 때마다 <kbd>Space</kbd>를 누릅니다. <kbd>Enter</kbd>는 간주, <kbd>Backspace</kbd>는 되돌리기입니다. 저장하면 `.lrc`가 생깁니다.

플레이 화면에서는 부른 부분이 왼쪽부터 금색으로 차오르고, 다음 줄이 아래에 미리 보입니다.

## 구조

```
rolling-voice/
├─ scenes/            main_menu.tscn, game.tscn, lyric_sync.tscn
├─ scripts/
│  ├─ audio/          pitch_detector.gd (마이크 → YIN 음정 추정), melody_synth.gd (가이드 멜로디 합성),
│  │                  melody_extractor.gd (음원 → 멜로디 악보)
│  ├─ music/          note_utils.gd, song_data.gd, song_library.gd (텍스트 악보), midi_parser.gd,
│  │                  musicxml_parser.gd (MusicXML/.mxl)
│  ├─ game/           game.gd (판정), rolling_coin.gd, rolling_world.gd, pitch_lane.gd, game_hud.gd,
│  │                  karaoke_lyrics.gd (노래방 가사)
│  ├─ ui/             main_menu.gd, lyric_sync.gd (가사 싱크 도구), ui_theme.gd (코드로 만든 Theme)
│  └─ global/         game_settings.gd (설정 저장, 오디오 버스)
├─ assets/            폰트·모델·효과음·아이콘 (출처: assets/CREDITS.md)
└─ tests/run_tests.gd 단위 테스트
```

사용한 Godot 기능은 다음과 같습니다.

- 오디오: `AudioStreamMicrophone`, `AudioEffectCapture`, `AudioStreamGenerator`, 버스 이펙트(PitchShift, HighPass/LowPass, Reverb, HardLimiter), 런타임 음원 로딩(`load_from_file`)
- 3D 화면: `GPUParticles3D`(먼지·불꽃·꽃가루), `ProceduralSkyMaterial`, SSAO, Glow, 깊이 안개
- UI: 코드로 만든 `Theme`/`StyleBoxFlat`, `Tween` 애니메이션, `FastNoiseLite` 카메라 흔들림, 네이티브 `FileDialog`, `clip_contents`를 이용한 가사 와이프

## 테스트

```bash
godot --headless --path rolling-voice -s res://tests/run_tests.gd
```

## 에셋 라이선스

- 3D 모델·효과음·스프라이트: [Kenney](https://kenney.nl) Starter Kits (CC0)
- 폰트: [Jua](https://fonts.google.com/specimen/Jua) (SIL OFL 1.1)
- 아이콘: [Material Symbols](https://github.com/google/material-design-icons) (Apache 2.0)

자세한 내용은 `rolling-voice/assets/CREDITS.md`를 참고하세요. 내장곡 4곡은 저작권이 만료된 멜로디만 담고 있습니다.
